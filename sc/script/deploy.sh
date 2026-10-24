#!/usr/bin/env bash
#
# RWA - Despliegue canonico y verificable (Ciclo 9 / RF-010)
# ---------------------------------------------------------
# Despliega la pila completa (registries + factories + aggregator + token de ejemplo + modulo
# de compliance) con `script/DeployFullStack.s.sol`, verifica el resultado on-chain con `cast`
# y persiste un artefacto JSON trazable en `deployments/`.
#
# Principios (RF-010 / H-28 / H-31 / H-24):
#   * La clave privada se lee SIEMPRE de variables de entorno (o Secret Manager GCP con
#     USE_SECRET_MANAGER=1). Nunca de un archivo de claves en disco ni en claro.
#   * Nada de `set -e`: cada paso comprueba su propio resultado y aborta con un mensaje claro.
#   * La red se valida ANTES del broadcast (`cast chain-id` == CHAIN_ID); si no coincide, aborta.
#   * La clave no viaja por `argv` (no aparece en `ps`): se materializa en un keystore cifrado
#     temporal (modo 600) creado desde Python (`eth_keyfile`) leyendo la clave de una variable
#     de entorno del proceso hijo, y se borra al terminar.
#   * El exito NO se decide con `grep` de logs: se decide por codigo de salida de `forge` y por
#     verificacion on-chain (`cast code` sobre cada direccion y `cast call` de estado).
#   * AF-07 (Fase 4): ademas de verificar el despliegue, se ejecuta un **smoke test de
#     operatividad** (`cast call` de `maxBurnPerTx`, `maxForcedPerTx`, `authorizedDestinations` e
#     `identityRegistry`), de modo que "verde" implica token OPERABLE, no solo desplegado.
#
# Uso:
#   source /home/dsh/workspace/gcp-env.sh      # exporta RPC_URL, CHAIN_ID, ADMIN_PRIVATE_KEY...
#   sc/script/deploy.sh                        # despliegue real y verificado
#
# Variables:
#   RPC_URL              (obligatoria) endpoint JSON-RPC de la red destino
#   CHAIN_ID             (opcional)  si se define, DEBE coincidir con `cast chain-id`; si no, aborta
#   DEPLOYER_KEY_VAR     (opcional)  nombre de la variable de entorno que contiene la clave
#   DS_DEPLOYER_PRIVATE_KEY / DEPLOYER_PRIVATE_KEY / DS_PRIVATE_KEY / DS_ADMIN_PRIVATE_KEY /
#   ADMIN_PRIVATE_KEY / PRIVATE_KEY  (en este orden) fuentes de la clave
#   USE_SECRET_MANAGER=1 (opcional)  obtiene la clave de GCP Secret Manager (gcloud) en vez del entorno
#   DS_DEPLOYER_SECRET   (opcional)  nombre del secreto (por defecto DS_PRIVATE_KEY)
#   BROADCAST=0          (opcional)  solo simula (sin --broadcast)
#   FORGE_BIN / CAST_BIN (opcional)  rutas a forge/cast
#
# Besu (alternativa documentada): mismo script con
#   RPC_URL=https://besu1.proyectos.codecrypto.academy CHAIN_ID=<chainId de Besu> sc/script/deploy.sh
# El wrapper `deploy-besu.sh` de la raiz mantiene compatibilidad.

set +u  # gcp-env.sh activa `set -u`; el script comprueba variables explicitamente

# --------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { printf '%b\n' "${BLUE}$*${NC}"; }
ok()   { printf '%b\n' "${GREEN}$*${NC}"; }
warn() { printf '%b\n' "${YELLOW}$*${NC}"; }
# Aborta SIN imprimir nunca el valor de la clave.
fail() { printf '%b\n' "${RED}ERROR: $*${NC}" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOYMENTS_DIR="$SC_DIR/deployments"

# Todos los comandos de Foundry se ejecutan con el proyecto Foundry como cwd.
cd "$SC_DIR" || fail "no se pudo entrar en el proyecto Foundry: $SC_DIR"

FORGE="${FORGE_BIN:-forge}"
CAST="${CAST_BIN:-cast}"

TMP_KS_DIR=""
cleanup() {
    if [ -n "$TMP_KS_DIR" ] && [ -d "$TMP_KS_DIR" ]; then
        rm -rf "$TMP_KS_DIR"
    fi
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------------------
# 0. Herramientas
# --------------------------------------------------------------------------------------
command -v "$FORGE" >/dev/null 2>&1 || fail "no se encuentra 'forge' (export PATH=\"\$HOME/.foundry/bin:\$PATH\")"
command -v "$CAST"  >/dev/null 2>&1 || fail "no se encuentra 'cast'"
command -v jq       >/dev/null 2>&1 || fail "no se encuentra 'jq'"
command -v python3  >/dev/null 2>&1 || fail "no se encuentra 'python3'"

# --------------------------------------------------------------------------------------
# 1. Configuracion y fuentes de la clave
# --------------------------------------------------------------------------------------
RPC_URL="${RPC_URL:-}"
[ -n "$RPC_URL" ] || fail "RPC_URL no esta definida. Exportala (p.ej. 'source /home/dsh/workspace/gcp-env.sh') o pasala en el entorno."

CHAIN_ID="${CHAIN_ID:-}"

SENDER_KEY=""
if [ "${USE_SECRET_MANAGER:-0}" = "1" ]; then
    command -v gcloud >/dev/null 2>&1 || fail "USE_SECRET_MANAGER=1 pero 'gcloud' no esta instalado"
    SECRET_NAME="${DS_DEPLOYER_SECRET:-DS_PRIVATE_KEY}"
    log "Obteniendo la clave de GCP Secret Manager (secreto: $SECRET_NAME)..."
    SENDER_KEY="$(gcloud secrets versions access latest --secret="$SECRET_NAME" 2>/dev/null)"
    [ -n "$SENDER_KEY" ] || fail "no se pudo leer el secreto '$SECRET_NAME' de Secret Manager"
else
    if [ -n "${DEPLOYER_KEY_VAR:-}" ]; then
        eval "SENDER_KEY=\${$DEPLOYER_KEY_VAR:-}"
        [ -n "$SENDER_KEY" ] || fail "la variable DEPLOYER_KEY_VAR='$DEPLOYER_KEY_VAR' no esta definida o esta vacia"
    else
        for var in DS_DEPLOYER_PRIVATE_KEY DEPLOYER_PRIVATE_KEY DS_PRIVATE_KEY DS_ADMIN_PRIVATE_KEY ADMIN_PRIVATE_KEY PRIVATE_KEY; do
            eval "candidate=\${$var:-}"
            if [ -n "$candidate" ]; then SENDER_KEY="$candidate"; KEY_SOURCE="$var"; break; fi
        done
        [ -n "$SENDER_KEY" ] || fail "no hay clave en el entorno. Define DS_DEPLOYER_PRIVATE_KEY / ADMIN_PRIVATE_KEY / PRIVATE_KEY (o usa DEPLOYER_KEY_VAR/USE_SECRET_MANAGER=1). No se leen archivos de claves en disco."
        log "Clave de despliegue tomada de la variable de entorno: $KEY_SOURCE"
    fi
fi

# Formato 0x + 64 hex, sin imprimir el valor jamas.
case "$SENDER_KEY" in
    0x[0-9a-fA-F][0-9a-fA-F]*) : ;;
    *) fail "la clave privada no tiene el formato esperado 0x + 64 hex (valor no mostrado)" ;;
esac
[ "${#SENDER_KEY}" -eq 66 ] || fail "la clave privada debe tener 66 caracteres (0x + 64 hex); valor no mostrado"

# --------------------------------------------------------------------------------------
# 2. Validacion de red ANTES de cualquier broadcast (D-040 / H-26)
# --------------------------------------------------------------------------------------
log "Validando la red destino con 'cast chain-id'..."
ACTUAL_CHAIN_ID="$("$CAST" chain-id --rpc-url "$RPC_URL" 2>/dev/null)"
[ -n "$ACTUAL_CHAIN_ID" ] || fail "no se pudo consultar 'cast chain-id' en RPC_URL (red inaccesible o URL invalida)"

if [ -n "$CHAIN_ID" ]; then
    if [ "$ACTUAL_CHAIN_ID" != "$CHAIN_ID" ]; then
        fail "CHAIN_ID declarado ($CHAIN_ID) != chain-id real de la red ($ACTUAL_CHAIN_ID). Abortando SIN desplegar."
    fi
    ok "Red validada: chain-id $ACTUAL_CHAIN_ID coincide con CHAIN_ID."
else
    CHAIN_ID="$ACTUAL_CHAIN_ID"
    warn "CHAIN_ID no declarado; se adopta el real de la red: $CHAIN_ID"
fi

# --------------------------------------------------------------------------------------
# 3. Keystore efimero (minima exposicion de la clave)
# --------------------------------------------------------------------------------------
TMP_KS_DIR="$(mktemp -d)" || fail "no se pudo crear el directorio temporal"
chmod 700 "$TMP_KS_DIR"
KS_FILE="$TMP_KS_DIR/deployer.json"
PW_FILE="$TMP_KS_DIR/password"

# Password aleatoria del keystore temporal (no se imprime).
python3 -c 'import secrets;print(secrets.token_hex(24),end="")' > "$PW_FILE" || fail "no se pudo generar la password del keystore"
chmod 600 "$PW_FILE"

# La clave se pasa al proceso Python por variable de ENTORNO (nunca por argv), y Python
# construye el keystore cifrado estandar v3. Ni la clave ni la password tocan `argv`.
RWA_KEY="$SENDER_KEY" RWA_PW_FILE="$PW_FILE" RWA_KS_OUT="$KS_FILE" python3 - <<'PY'
import json, os, sys
try:
    from eth_keyfile import create_keyfile_json
except Exception as exc:  # pragma: no cover
    sys.stderr.write("no se pudo importar 'eth_keyfile': %s\n" % exc)
    sys.exit(2)
key = os.environ.get("RWA_KEY", "")
if not (key.startswith("0x") and len(key) == 66):
    sys.stderr.write("clave con formato invalido\n")
    sys.exit(3)
with open(os.environ["RWA_PW_FILE"], "rb") as fh:
    password = fh.read().strip()
keystore = create_keyfile_json(bytes.fromhex(key[2:]), password)
out = os.environ["RWA_KS_OUT"]
with open(out, "w") as fh:
    json.dump(keystore, fh)
os.chmod(out, 0o600)
PY
[ $? -eq 0 ] || fail "no se pudo construir el keystore cifrado temporal"
[ -f "$KS_FILE" ] || fail "el keystore temporal no se creo"

chmod 600 "$KS_FILE"

SENDER="$("$CAST" wallet address --keystore "$KS_FILE" --password-file "$PW_FILE" 2>/dev/null)"
[ -n "$SENDER" ] || fail "no se pudo derivar la direccion del firmante desde el keystore temporal"

BALANCE_WEI="$("$CAST" balance "$SENDER" --rpc-url "$RPC_URL" 2>/dev/null)"
[ -n "$BALANCE_WEI" ] || fail "no se pudo consultar el saldo del firmante $SENDER"
if [ "$BALANCE_WEI" = "0" ]; then
    fail "el firmante $SENDER tiene saldo 0 en la red $CHAIN_ID; no se puede desplegar"
fi
ok "Firmante: $SENDER (saldo: $BALANCE_WEI wei) en chain-id $CHAIN_ID"

# --------------------------------------------------------------------------------------
# 4. Compilacion
# --------------------------------------------------------------------------------------
log "Compilando contratos (forge build)..."
"$FORGE" build --silent
[ $? -eq 0 ] || fail "forge build fallo"

# --------------------------------------------------------------------------------------
# 5. Despliegue (forge script) + artefacto JSON
# --------------------------------------------------------------------------------------
mkdir -p "$DEPLOYMENTS_DIR" || fail "no se pudo crear $DEPLOYMENTS_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEPLOYMENT_JSON="$DEPLOYMENTS_DIR/${CHAIN_ID}-${STAMP}.json"
export DEPLOYMENT_JSON

BROADCAST="${BROADCAST:-1}"
BROADCAST_FLAG=""
if [ "$BROADCAST" = "1" ]; then
    BROADCAST_FLAG="--broadcast"
    log "Desplegando en la red $CHAIN_ID con --broadcast..."
else
    warn "BROADCAST=0: simulacion sin envio de transacciones"
fi

"$FORGE" script script/DeployFullStack.s.sol:DeployFullStack \
    --rpc-url "$RPC_URL" \
    --keystore "$KS_FILE" \
    --password-file "$PW_FILE" \
    $BROADCAST_FLAG \
    -vv
FORGE_RC=$?
[ $FORGE_RC -eq 0 ] || fail "forge script termino con codigo $FORGE_RC; despliegue NO verificado"
[ -f "$DEPLOYMENT_JSON" ] || fail "forge script termino bien pero no se genero el artefacto $DEPLOYMENT_JSON"
jq -e . "$DEPLOYMENT_JSON" >/dev/null 2>&1 || fail "el artefacto $DEPLOYMENT_JSON no es JSON valido"
ok "Artefacto base generado: $DEPLOYMENT_JSON"

if [ "$BROADCAST" != "1" ]; then
    warn "BROADCAST=0: modo simulacion; se omite la verificacion on-chain (las direcciones no existen en la red)."
    exit 0
fi

# --------------------------------------------------------------------------------------
# 6. Verificacion on-chain (cast code + cast call), no grep de logs
# --------------------------------------------------------------------------------------
log "Verificando bytecode con 'cast code' en todas las direcciones..."
CONTRACT_KEYS="$(jq -r '.contracts | keys[]' "$DEPLOYMENT_JSON")"
[ -n "$CONTRACT_KEYS" ] || fail "el artefacto no contiene direcciones de contratos"
VERIFIED_COUNT=0
for key in $CONTRACT_KEYS; do
    addr="$(jq -r --arg k "$key" '.contracts[$k]' "$DEPLOYMENT_JSON")"
    [ -n "$addr" ] && [ "$addr" != "0x0000000000000000000000000000000000000000" ] || fail "direccion invalida para $key: $addr"
    code="$("$CAST" code "$addr" --rpc-url "$RPC_URL" 2>/dev/null)"
    [ -n "$code" ] || fail "cast code fallo para $key ($addr)"
    case "$code" in
        0x) fail "$key ($addr) NO tiene bytecode on-chain (cast code = 0x)" ;;
        0x*) : ;;
        *) fail "cast code devolvio un valor inesperado para $key ($addr)" ;;
    esac
    printf '  %-38s %s  code_len=%s\n' "$key" "$addr" "$(( (${#code} - 2) / 2 ))"
    VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
done

# Modulos de compliance (viven en .compliance, no en .contracts).
# H-29 (M-14): el despliegue puede activar 1..3 modulos. Se verifica cada modulo que el artefacto
# declare con direccion no cero; el conteo esperado del aggregator se deriva de esa lista (no se
# escribe a mano), de modo que la generalizacion no rompe el smoke test.
MODULE_KEYS=(MaxBalanceCompliance MaxHoldersCompliance TransferLockCompliance)
MODULE_ADDRS=()
for mkey in "${MODULE_KEYS[@]}"; do
    maddr="$(jq -r --arg k "$mkey" '.compliance[$k] // empty' "$DEPLOYMENT_JSON")"
    [ -n "$maddr" ] && [ "$maddr" != "null" ] || continue
    [ "$maddr" != "0x0000000000000000000000000000000000000000" ] || continue
    mcode="$("$CAST" code "$maddr" --rpc-url "$RPC_URL" 2>/dev/null)"
    case "$mcode" in
        0x) fail "$mkey ($maddr) NO tiene bytecode on-chain" ;;
        0x*) : ;;
        *) fail "cast code inesperado para $mkey" ;;
    esac
    printf '  %-38s %s  code_len=%s\n' "$mkey" "$maddr" "$(( (${#mcode} - 2) / 2 ))"
    VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
    MODULE_ADDRS+=("$maddr")
done
EXPECTED_MODULE_COUNT="${#MODULE_ADDRS[@]}"
[ "$EXPECTED_MODULE_COUNT" -ge 1 ] || fail "el artefacto no declara ningun modulo de compliance (AF-05)"
MODULE_ADDR="$(jq -r '.compliance.MaxBalanceCompliance' "$DEPLOYMENT_JSON")"
ok "cast code OK en $VERIFIED_COUNT contratos"

lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

TOKEN="$(jq -r '.contracts.Token' "$DEPLOYMENT_JSON")"
IR="$(jq -r '.contracts.IdentityRegistry' "$DEPLOYMENT_JSON")"
TIR="$(jq -r '.contracts.TrustedIssuersRegistry' "$DEPLOYMENT_JSON")"
CTR="$(jq -r '.contracts.ClaimTopicsRegistry' "$DEPLOYMENT_JSON")"
AGG="$(jq -r '.contracts.ComplianceAggregator' "$DEPLOYMENT_JSON")"

log "Verificando estado on-chain con 'cast call'..."
# `cast call` devuelve los `string` entre comillas ("RWA Demo Token"); se normalizan.
strip_quotes() { v="$1"; v="${v#\"}"; v="${v%\"}"; printf '%s' "$v"; }

# `cast call` (Foundry >= 1.8) anexa la notacion cientifica entre corchetes a los enteros
# grandes, p. ej. "1000000000000000000000000 [1e24]"; se elimina el sufijo y los espacios
# para comparar con el valor canonico del artefacto (H-11).
norm_num() { printf '%s' "$1" | sed -E 's/[[:space:]]*\[[^]]*\][[:space:]]*$//' | tr -d '[:space:]'; }

NAME="$(strip_quotes "$("$CAST" call "$TOKEN" 'name()(string)' --rpc-url "$RPC_URL" 2>/dev/null)")"
[ "$NAME" = "RWA Demo Token" ] || fail "token.name() inesperado: '$NAME'"
printf '  token.name()                    = %s\n' "$NAME"

SYMBOL="$(strip_quotes "$("$CAST" call "$TOKEN" 'symbol()(string)' --rpc-url "$RPC_URL" 2>/dev/null)")"
[ "$SYMBOL" = "RWAD" ] || fail "token.symbol() inesperado: '$SYMBOL'"
printf '  token.symbol()                  = %s\n' "$SYMBOL"

TOKEN_IR="$("$CAST" call "$TOKEN" 'identityRegistry()(address)' --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$(lower "$TOKEN_IR")" = "$(lower "$IR")" ] || fail "token.identityRegistry() ($TOKEN_IR) != IdentityRegistry ($IR)"
printf '  token.identityRegistry()        = %s\n' "$TOKEN_IR"

TOKEN_TIR="$("$CAST" call "$TOKEN" 'trustedIssuersRegistry()(address)' --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$(lower "$TOKEN_TIR")" = "$(lower "$TIR")" ] || fail "token.trustedIssuersRegistry() ($TOKEN_TIR) != TrustedIssuersRegistry ($TIR)"
printf '  token.trustedIssuersRegistry()  = %s\n' "$TOKEN_TIR"

TOKEN_CTR="$("$CAST" call "$TOKEN" 'claimTopicsRegistry()(address)' --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$(lower "$TOKEN_CTR")" = "$(lower "$CTR")" ] || fail "token.claimTopicsRegistry() ($TOKEN_CTR) != ClaimTopicsRegistry ($CTR)"
printf '  token.claimTopicsRegistry()     = %s\n' "$TOKEN_CTR"

MODULE_COUNT="$(norm_num "$("$CAST" call "$AGG" 'getModuleCount(address)(uint256)' "$TOKEN" --rpc-url "$RPC_URL" 2>/dev/null)")"
[ "$MODULE_COUNT" = "$EXPECTED_MODULE_COUNT" ] || fail "aggregator.getModuleCount(token) = '$MODULE_COUNT' (esperado $EXPECTED_MODULE_COUNT)"
printf '  aggregator.getModuleCount()     = %s\n' "$MODULE_COUNT"

# H-29: cada modulo declarado debe estar activo para el token y vinculado a el (AF-01/H-19).
for maddr in "${MODULE_ADDRS[@]}"; do
    MODULE_ACTIVE="$("$CAST" call "$AGG" 'isModuleActiveForToken(address,address)(bool)' "$TOKEN" "$maddr" --rpc-url "$RPC_URL" 2>/dev/null)"
    [ "$MODULE_ACTIVE" = "true" ] || fail "el modulo $maddr no esta activo en el aggregator para el token"
    MODULE_TOKEN="$("$CAST" call "$maddr" 'tokenContract()(address)' --rpc-url "$RPC_URL" 2>/dev/null)"
    [ "$(lower "$MODULE_TOKEN")" = "$(lower "$TOKEN")" ] || fail "module.tokenContract() ($MODULE_TOKEN) != token ($TOKEN)"
done
printf '  aggregator.isModuleActiveForToken() = true (%s modulos)\n' "${#MODULE_ADDRS[@]}"
printf '  module.tokenContract()          = %s (todos)\n' "$TOKEN"

# AF-05: el token es fail-closed sin modulos; el despliegue debe dejar al menos uno registrado o el
# token queda inoperable para transferencias. Se verifica el indice 0 del array publico del token y
# que sea exactamente el aggregator configurado.
TOKEN_MODULE0="$("$CAST" call "$TOKEN" 'complianceModules(uint256)(address)' 0 --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$(lower "$TOKEN_MODULE0")" = "$(lower "$AGG")" ] || fail "token.complianceModules(0) ($TOKEN_MODULE0) != aggregator ($AGG): token fail-closed (AF-05)"
printf '  token.complianceModules(0)      = %s\n' "$TOKEN_MODULE0"

# --------------------------------------------------------------------------------------
# 6b. Smoke test (AF-07): "verde" debe implicar OPERATIVO, no solo desplegado.
#     Se comprueban los controles de operacion configurados por DeployFullStack y una
#     lectura coherente del registro de identidad, cotejando artefacto vs on-chain.
# --------------------------------------------------------------------------------------
DEPLOYER_ADDR="$(jq -r '.deployer' "$DEPLOYMENT_JSON")"
[ -n "$DEPLOYER_ADDR" ] && [ "$DEPLOYER_ADDR" != "null" ] || fail "el artefacto no contiene '.deployer'"
EXPECTED_BURN="$(jq -r '.token.maxBurnPerTx' "$DEPLOYMENT_JSON")"
EXPECTED_FORCED="$(jq -r '.token.maxForcedPerTx' "$DEPLOYMENT_JSON")"
[ -n "$EXPECTED_BURN" ] && [ "$EXPECTED_BURN" != "null" ] || fail "el artefacto no contiene '.token.maxBurnPerTx'"
[ -n "$EXPECTED_FORCED" ] && [ "$EXPECTED_FORCED" != "null" ] || fail "el artefacto no contiene '.token.maxForcedPerTx'"

log "Smoke test de operatividad (AF-07)..."

ONCHAIN_BURN="$(norm_num "$("$CAST" call "$TOKEN" 'maxBurnPerTx()(uint256)' --rpc-url "$RPC_URL" 2>/dev/null)")"
[ "$ONCHAIN_BURN" = "$EXPECTED_BURN" ] || fail "token.maxBurnPerTx() ($ONCHAIN_BURN) != artefacto ($EXPECTED_BURN)"
[ "$ONCHAIN_BURN" != "0" ] || fail "maxBurnPerTx es 0: la quema esta DESACTIVADA (token inoperable)"
printf '  token.maxBurnPerTx()            = %s\n' "$ONCHAIN_BURN"

ONCHAIN_FORCED="$(norm_num "$("$CAST" call "$TOKEN" 'maxForcedPerTx()(uint256)' --rpc-url "$RPC_URL" 2>/dev/null)")"
[ "$ONCHAIN_FORCED" = "$EXPECTED_FORCED" ] || fail "token.maxForcedPerTx() ($ONCHAIN_FORCED) != artefacto ($EXPECTED_FORCED)"
[ "$ONCHAIN_FORCED" != "0" ] || fail "maxForcedPerTx es 0: la recuperacion forzada esta DESACTIVADA"
printf '  token.maxForcedPerTx()          = %s\n' "$ONCHAIN_FORCED"

AUTH_DEST="$("$CAST" call "$TOKEN" 'authorizedDestinations(address)(bool)' "$DEPLOYER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$AUTH_DEST" = "true" ] || fail "el deployer no esta autorizado como destino de forcedTransfer (valor: $AUTH_DEST)"
printf '  token.authorizedDestinations(deployer) = %s\n' "$AUTH_DEST"

IS_REGISTERED="$("$CAST" call "$IR" 'isRegistered(address)(bool)' "$DEPLOYER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$IS_REGISTERED" = "true" ] || fail "el deployer no tiene identidad registrada en IdentityRegistry (valor: $IS_REGISTERED)"
printf '  identityRegistry.isRegistered(deployer) = %s\n' "$IS_REGISTERED"

IDENTITY_ADDR="$("$CAST" call "$IR" 'getIdentity(address)(address)' "$DEPLOYER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)"
IDENTITY_ARTIFACT="$(jq -r '.contracts.Identity' "$DEPLOYMENT_JSON")"
[ "$(lower "$IDENTITY_ADDR")" = "$(lower "$IDENTITY_ARTIFACT")" ] || fail "getIdentity(deployer) ($IDENTITY_ADDR) != Identity del artefacto ($IDENTITY_ARTIFACT)"
printf '  identityRegistry.getIdentity(deployer) = %s\n' "$IDENTITY_ADDR"

ok "Smoke test de operatividad correcto (topes, whitelist y registro coherentes)"
ok "Verificacion on-chain correcta (estado del token y de su compliance)"

# --------------------------------------------------------------------------------------
# 7. Enriquecimiento con ABIs relevantes + comprobacion anti-secretos
# --------------------------------------------------------------------------------------
log "Anexando ABIs relevantes al artefacto..."
ABI_CONTRACTS="IdentityRegistry TrustedIssuersRegistry TokenCloneFactory IdentityCloneFactory ClaimTopicsRegistryCloneFactory ComplianceAggregator ClaimTopicsRegistryCloneable TokenCloneable IdentityCloneable MaxBalanceCompliance MaxHoldersCompliance TransferLockCompliance"
ABIS="{}"
for c in $ABI_CONTRACTS; do
    abi_json="$("$FORGE" inspect "$c" abi --json 2>/dev/null)"
    [ -n "$abi_json" ] || fail "forge inspect $c abi no devolvio nada"
    printf '%s' "$abi_json" | jq -e 'type == "array"' >/dev/null 2>&1 || fail "el ABI de $c no es un array JSON"
    ABIS="$(jq -n --argjson acc "$ABIS" --argjson abi "$abi_json" --arg name "$c" '$acc + {($name): $abi}')" || fail "no se pudo anexar el ABI de $c"
done

TMP_JSON="$DEPLOYMENT_JSON.tmp"
jq --argjson abis "$ABIS" \
   --argjson verified "$VERIFIED_COUNT" \
   '. + {abis: $abis, verifiedContracts: $verified}' "$DEPLOYMENT_JSON" > "$TMP_JSON" || fail "no se pudo enriquecer el artefacto"
mv "$TMP_JSON" "$DEPLOYMENT_JSON" || fail "no se pudo reemplazar el artefacto enriquecido"

# El artefacto es trazable (versionado) pero no debe contener secretos.
if grep -Eq '0x[0-9a-fA-F]{64}' "$DEPLOYMENT_JSON"; then
    fail "el artefacto $DEPLOYMENT_JSON contiene una cadena de 64 hex (posible secreto); revisalo"
fi
if grep -Eiq 'private[_-]?key|mnemonic|password' "$DEPLOYMENT_JSON"; then
    fail "el artefacto $DEPLOYMENT_JSON menciona material sensible; revisalo"
fi
ok "Artefacto sin secretos: $DEPLOYMENT_JSON"

# --------------------------------------------------------------------------------------
# 8. Resumen
# --------------------------------------------------------------------------------------
echo ""
log "================ RESUMEN DEL DESPLIEGUE ================"
jq -r '.contracts | to_entries[] | "  \(.key): \(.value)"' "$DEPLOYMENT_JSON"
jq -r '.compliance | to_entries[] | select(.value | type == "string") | select(.value != "0x0000000000000000000000000000000000000000") | "  \(.key): \(.value)"' "$DEPLOYMENT_JSON"
echo "  chainId: $CHAIN_ID   bloque: $(jq -r '.block' "$DEPLOYMENT_JSON")   deployer: $SENDER"
echo "  artefacto: $DEPLOYMENT_JSON"
ok "Despliegue verificado correctamente."
exit 0
