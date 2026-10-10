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

# Modulo de compliance (vive en .compliance, no en .contracts)
MODULE_ADDR="$(jq -r '.compliance.MaxBalanceCompliance' "$DEPLOYMENT_JSON")"
[ -n "$MODULE_ADDR" ] && [ "$MODULE_ADDR" != "0x0000000000000000000000000000000000000000" ] || fail "direccion de modulo invalida"
MODULE_CODE="$("$CAST" code "$MODULE_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)"
case "$MODULE_CODE" in
    0x) fail "MaxBalanceCompliance ($MODULE_ADDR) NO tiene bytecode on-chain" ;;
    0x*) : ;;
    *) fail "cast code inesperado para MaxBalanceCompliance" ;;
esac
printf '  %-38s %s  code_len=%s\n' "MaxBalanceCompliance" "$MODULE_ADDR" "$(( (${#MODULE_CODE} - 2) / 2 ))"
VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
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

MODULE_COUNT="$("$CAST" call "$AGG" 'getModuleCount(address)(uint256)' "$TOKEN" --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$MODULE_COUNT" = "1" ] || fail "aggregator.getModuleCount(token) = '$MODULE_COUNT' (esperado 1)"
printf '  aggregator.getModuleCount()     = %s\n' "$MODULE_COUNT"

MODULE_ACTIVE="$("$CAST" call "$AGG" 'isModuleActiveForToken(address,address)(bool)' "$TOKEN" "$MODULE_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$MODULE_ACTIVE" = "true" ] || fail "el modulo no esta activo en el aggregator para el token"
printf '  aggregator.isModuleActiveForToken() = %s\n' "$MODULE_ACTIVE"

MODULE_TOKEN="$("$CAST" call "$MODULE_ADDR" 'tokenContract()(address)' --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$(lower "$MODULE_TOKEN")" = "$(lower "$TOKEN")" ] || fail "module.tokenContract() ($MODULE_TOKEN) != token ($TOKEN)"
printf '  module.tokenContract()          = %s\n' "$MODULE_TOKEN"
ok "Verificacion on-chain correcta (estado del token y de su compliance)"

# --------------------------------------------------------------------------------------
# 7. Enriquecimiento con ABIs relevantes + comprobacion anti-secretos
# --------------------------------------------------------------------------------------
log "Anexando ABIs relevantes al artefacto..."
ABI_CONTRACTS="IdentityRegistry TrustedIssuersRegistry TokenCloneFactory IdentityCloneFactory ClaimTopicsRegistryCloneFactory ComplianceAggregator ClaimTopicsRegistryCloneable TokenCloneable IdentityCloneable MaxBalanceCompliance"
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
jq -r '"  MaxBalanceCompliance: \(.compliance.MaxBalanceCompliance)"' "$DEPLOYMENT_JSON"
echo "  chainId: $CHAIN_ID   bloque: $(jq -r '.block' "$DEPLOYMENT_JSON")   deployer: $SENDER"
echo "  artefacto: $DEPLOYMENT_JSON"
ok "Despliegue verificado correctamente."
exit 0
