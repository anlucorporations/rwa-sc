#!/usr/bin/env bash
# =============================================================================
# adopt_governance.sh — Adopción del GovernanceMultisig (H-06 / R-7 / D-021)
# =============================================================================
# Entrega la propiedad (Ownable) de los contratos administrados y los roles
# AccessControl del token al GovernanceMultisig, y hace que la EOA renuncie a
# ellos. NO despliega contratos: opera sobre el artefacto de despliegue y un
# multisig ya desplegado (script/DeployGovernance.s.sol).
#
# Requisitos de entorno:
#   RPC_URL                          red destino (validada con `cast chain-id`)
#   GOVERNANCE_MULTISIG              dirección del multisig (con código)
#   DEPLOYMENT_JSON                  artefacto de despliegue (si falta = el más reciente)
#   clave de firma                   DS_DEPLOYER_PRIVATE_KEY / DEPLOYER_PRIVATE_KEY /
#                                    ADMIN_PRIVATE_KEY / PRIVATE_KEY (o DEPLOYER_KEY_VAR)
# Opcionales:
#   CHAIN_ID                         si se define, debe coincidir con la red real
#   ADOPT_SKIP_IDENTITY_REGISTRY=1   no transfiere IdentityRegistry (decisión de producto)
#   ALLOW_SHORT_DELAY=1              permite delay < 24h (solo drills locales)
#   BROADCAST=0                      simulación sin enviar transacciones
#
# Uso:
#   source /home/dsh/workspace/gcp-env.sh
#   GOVERNANCE_MULTISIG=0x... sc/script/adopt_governance.sh
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { printf '%b\n' "${BLUE}$*${NC}"; }
ok()   { printf '%b\n' "${GREEN}$*${NC}"; }
warn() { printf '%b\n' "${YELLOW}$*${NC}"; }
fail() { printf '%b\n' "${RED}ERROR: $*${NC}" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOYMENTS_DIR="$SC_DIR/deployments"
cd "$SC_DIR" || fail "no se pudo entrar en $SC_DIR"

FORGE="${FORGE_BIN:-forge}"
CAST="${CAST_BIN:-cast}"
export PATH="$HOME/.foundry/bin:$PATH"

command -v "$FORGE" >/dev/null 2>&1 || fail "no se encuentra 'forge'"
command -v "$CAST"  >/dev/null 2>&1 || fail "no se encuentra 'cast'"
command -v jq       >/dev/null 2>&1 || fail "no se encuentra 'jq'"
command -v python3  >/dev/null 2>&1 || fail "no se encuentra 'python3'"

# --- 1. Red ------------------------------------------------------------------
RPC_URL="${RPC_URL:-}"
[ -n "$RPC_URL" ] || fail "RPC_URL no definida (exporta el entorno de GCP o pásala en el entorno)"
ACTUAL_CHAIN_ID="$("$CAST" chain-id --rpc-url "$RPC_URL" 2>/dev/null)" || fail "no se pudo consultar chain-id en RPC_URL"
if [ -n "${CHAIN_ID:-}" ] && [ "$CHAIN_ID" != "$ACTUAL_CHAIN_ID" ]; then
    fail "CHAIN_ID ($CHAIN_ID) != chain-id real ($ACTUAL_CHAIN_ID)"
fi
CHAIN_ID="$ACTUAL_CHAIN_ID"
ok "Red validada: chain-id $CHAIN_ID"

# --- 2. Multisig -------------------------------------------------------------
GOVERNANCE_MULTISIG="${GOVERNANCE_MULTISIG:-}"
[ -n "$GOVERNANCE_MULTISIG" ] || fail "GOVERNANCE_MULTISIG no definida (dirección del multisig desplegado)"
case "$GOVERNANCE_MULTISIG" in
    0x[0-9a-fA-F]*) : ;;
    *) fail "GOVERNANCE_MULTISIG no es una dirección 0x…" ;;
esac
CODE="$("$CAST" code "$GOVERNANCE_MULTISIG" --rpc-url "$RPC_URL" 2>/dev/null)"
[ -n "$CODE" ] && [ "$CODE" != "0x" ] || fail "GOVERNANCE_MULTISIG ($GOVERNANCE_MULTISIG) no tiene código en la red"
THRESHOLD="$("$CAST" call "$GOVERNANCE_MULTISIG" 'threshold()(uint256)' --rpc-url "$RPC_URL" 2>/dev/null)"
DELAY="$("$CAST" call "$GOVERNANCE_MULTISIG" 'delay()(uint256)' --rpc-url "$RPC_URL" 2>/dev/null | sed -E 's/ \[[^]]*\]$//')"
OWNERS="$("$CAST" call "$GOVERNANCE_MULTISIG" 'ownerCount()(uint256)' --rpc-url "$RPC_URL" 2>/dev/null | sed -E 's/ \[[^]]*\]$//')"
[ -n "$THRESHOLD" ] && [ -n "$DELAY" ] && [ -n "$OWNERS" ] || fail "no se pudo leer la configuración del multisig"
NORM_THRESHOLD="${THRESHOLD%% *}"; NORM_THRESHOLD="${NORM_THRESHOLD//[[:space:]]/}"
[ "$NORM_THRESHOLD" -ge 2 ] 2>/dev/null || fail "threshold=$NORM_THRESHOLD < 2: la gobernanza no es M-de-N real (D-021)"
[ "$OWNERS" -ge 3 ] 2>/dev/null || fail "owners=$OWNERS < 3 (D-021)"
if [ "$DELAY" -lt 86400 ] 2>/dev/null && [ "${ALLOW_SHORT_DELAY:-0}" != "1" ]; then
    fail "delay=$DELAY s < 24 h; para producción se exige ≥86400 (ALLOW_SHORT_DELAY=1 solo en drills locales)"
fi
ok "Multisig válido: owners=$OWNERS threshold=$NORM_THRESHOLD delay=${DELAY}s"

# --- 3. Artefacto de despliegue ---------------------------------------------
if [ -n "${DEPLOYMENT_JSON:-}" ]; then
    [ -f "$DEPLOYMENT_JSON" ] || fail "DEPLOYMENT_JSON no existe: $DEPLOYMENT_JSON"
else
    DEPLOYMENT_JSON="$(ls -1 "$DEPLOYMENTS_DIR"/*.json 2>/dev/null | sort | tail -1 || true)"
    [ -n "$DEPLOYMENT_JSON" ] || fail "no hay artefactos en $DEPLOYMENTS_DIR; define DEPLOYMENT_JSON"
fi
jq -e . "$DEPLOYMENT_JSON" >/dev/null 2>&1 || fail "DEPLOYMENT_JSON no es JSON válido: $DEPLOYMENT_JSON"
ok "Artefacto: $DEPLOYMENT_JSON (block $(jq -r '.block' "$DEPLOYMENT_JSON"), chain $(jq -r '.chainId' "$DEPLOYMENT_JSON"))"

# --- 4. Clave y keystore efímero (no expone la clave por argv) ---------------
SENDER_KEY=""
for var in DS_DEPLOYER_PRIVATE_KEY DEPLOYER_PRIVATE_KEY DS_PRIVATE_KEY DS_ADMIN_PRIVATE_KEY ADMIN_PRIVATE_KEY PRIVATE_KEY; do
    eval "candidate=\${$var:-}"
    if [ -n "$candidate" ]; then SENDER_KEY="$candidate"; KEY_SOURCE="$var"; break; fi
done
[ -n "$SENDER_KEY" ] || fail "no hay clave en el entorno (define DS_DEPLOYER_PRIVATE_KEY / ADMIN_PRIVATE_KEY / PRIVATE_KEY)"
case "$SENDER_KEY" in
    0x[0-9a-fA-F][0-9a-fA-F]*) : ;;
    *) fail "la clave privada no tiene formato 0x + 64 hex (valor no mostrado)" ;;
esac
[ "${#SENDER_KEY}" -eq 66 ] || fail "la clave debe tener 66 caracteres (valor no mostrado)"

TMP_KS_DIR="$(mktemp -d)" || fail "no se pudo crear el directorio temporal"
chmod 700 "$TMP_KS_DIR"
KS_FILE="$TMP_KS_DIR/adopter.json"; PW_FILE="$TMP_KS_DIR/password"
cleanup() { rm -rf "$TMP_KS_DIR"; }
trap cleanup EXIT INT TERM
python3 -c 'import secrets;print(secrets.token_hex(24),end="")' > "$PW_FILE" || fail "no se pudo generar la password del keystore"
chmod 600 "$PW_FILE"
RWA_KEY="$SENDER_KEY" RWA_PW_FILE="$PW_FILE" RWA_KS_OUT="$KS_FILE" python3 - <<'PY'
import json, os, sys
try:
    from eth_keyfile import create_keyfile_json
except Exception as exc:
    sys.stderr.write("no se pudo importar 'eth_keyfile': %s\n" % exc)
    sys.exit(2)
key = os.environ.get("RWA_KEY", "")
if not (key.startswith("0x") and len(key) == 66):
    sys.stderr.write("clave con formato invalido\n")
    sys.exit(3)
with open(os.environ["RWA_PW_FILE"], "rb") as fh:
    password = fh.read().strip()
keystore = create_keyfile_json(bytes.fromhex(key[2:]), password)
with open(os.environ["RWA_KS_OUT"], "w") as fh:
    json.dump(keystore, fh)
os.chmod(os.environ["RWA_KS_OUT"], 0o600)
PY
[ $? -eq 0 ] || fail "no se pudo construir el keystore temporal"
SENDER="$("$CAST" wallet address --keystore "$KS_FILE" --password-file "$PW_FILE" 2>/dev/null)"
[ -n "$SENDER" ] || fail "no se pudo derivar la dirección del firmante"
[ "$(printf '%s' "$SENDER" | tr 'A-F' 'a-f')" != "$(printf '%s' "$GOVERNANCE_MULTISIG" | tr 'A-F' 'a-f')" ] || fail "el firmante es el propio multisig"
ok "Firmante (EOA a retirar): $SENDER (clave de $KEY_SOURCE)"

# --- 5. Preflight: la EOA debe ser la administradora actual ------------------
CURRENT_IR_OWNER="$("$CAST" call "$(jq -r '.contracts.IdentityRegistry' "$DEPLOYMENT_JSON")" 'owner()(address)' --rpc-url "$RPC_URL" 2>/dev/null)"
if [ "${ADOPT_SKIP_IDENTITY_REGISTRY:-0}" != "1" ]; then
    [ "$(printf '%s' "$CURRENT_IR_OWNER" | tr 'A-F' 'a-f')" = "$(printf '%s' "$SENDER" | tr 'A-F' 'a-f')" ] \
        || fail "IdentityRegistry.owner()=$CURRENT_IR_OWNER != firmante $SENDER (¿ya adoptado?)"
fi
ok "Preflight: el firmante es el owner actual de IdentityRegistry"

# --- 6. Adopción -------------------------------------------------------------
export DEPLOYMENT_JSON GOVERNANCE_MULTISIG
BROADCAST_FLAG="--broadcast"
if [ "${BROADCAST:-1}" = "0" ]; then BROADCAST_FLAG=""; warn "BROADCAST=0: simulación sin enviar transacciones"; fi
log "Ejecutando script/AdoptGovernance.s.sol…"
"$FORGE" script script/AdoptGovernance.s.sol:AdoptGovernance \
    --rpc-url "$RPC_URL" --keystore "$KS_FILE" --password-file "$PW_FILE" $BROADCAST_FLAG -vv
[ $? -eq 0 ] || fail "AdoptGovernance falló; la adopción NO se completó o no pasó la verificación"

# --- 7. Verificación independiente (cast) -----------------------------------
log "Verificación independiente con cast…"
TOKEN="$(jq -r '.token.address' "$DEPLOYMENT_JSON")"
verify_owner() {
    local name="$1" addr="$2"
    [ -n "$addr" ] && [ "$addr" != "null" ] && [ "$addr" != "0x0000000000000000000000000000000000000000" ] || return 0
    local owner
    owner="$("$CAST" call "$addr" 'owner()(address)' --rpc-url "$RPC_URL" 2>/dev/null)"
    [ "$(printf '%s' "$owner" | tr 'A-F' 'a-f')" = "$(printf '%s' "$GOVERNANCE_MULTISIG" | tr 'A-F' 'a-f')" ] \
        || fail "$name.owner()=$owner != multisig"
    ok "  $name → multisig"
}
if [ "${ADOPT_SKIP_IDENTITY_REGISTRY:-0}" != "1" ]; then
    verify_owner "IdentityRegistry" "$(jq -r '.contracts.IdentityRegistry' "$DEPLOYMENT_JSON")"
else
    warn "  IdentityRegistry omitida por ADOPT_SKIP_IDENTITY_REGISTRY=1"
fi
verify_owner "TrustedIssuersRegistry" "$(jq -r '.contracts.TrustedIssuersRegistry' "$DEPLOYMENT_JSON")"
verify_owner "TokenCloneFactory" "$(jq -r '.contracts.TokenCloneFactory' "$DEPLOYMENT_JSON")"
verify_owner "IdentityCloneFactory" "$(jq -r '.contracts.IdentityCloneFactory' "$DEPLOYMENT_JSON")"
verify_owner "ClaimTopicsRegistryCloneFactory" "$(jq -r '.contracts.ClaimTopicsRegistryCloneFactory' "$DEPLOYMENT_JSON")"
verify_owner "ComplianceAggregator" "$(jq -r '.contracts.ComplianceAggregator' "$DEPLOYMENT_JSON")"
verify_owner "ClaimTopicsRegistry" "$(jq -r '.contracts.ClaimTopicsRegistry' "$DEPLOYMENT_JSON")"
verify_owner "MaxBalanceCompliance" "$(jq -r '.compliance.MaxBalanceCompliance' "$DEPLOYMENT_JSON")"
verify_owner "MaxHoldersCompliance" "$(jq -r '.compliance.MaxHoldersCompliance' "$DEPLOYMENT_JSON")"
verify_owner "TransferLockCompliance" "$(jq -r '.compliance.TransferLockCompliance' "$DEPLOYMENT_JSON")"

DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"
AGENT_ROLE="$("$CAST" keccak "AGENT_ROLE")"
COMPLIANCE_ROLE="$("$CAST" keccak "COMPLIANCE_ROLE")"
verify_role() {
    local role="$1" label="$2" expected="$3"
    local got
    got="$("$CAST" call "$TOKEN" 'hasRole(bytes32,address)(bool)' "$role" "$GOVERNANCE_MULTISIG" --rpc-url "$RPC_URL" 2>/dev/null)"
    [ "$got" = "$expected" ] || fail "token hasRole($label, multisig)=$got (esperado $expected)"
}
verify_role "$DEFAULT_ADMIN_ROLE" "DEFAULT_ADMIN_ROLE" "true"
verify_role "$AGENT_ROLE" "AGENT_ROLE" "true"
verify_role "$COMPLIANCE_ROLE" "COMPLIANCE_ROLE" "true"
ok "  token: multisig tiene DEFAULT_ADMIN_ROLE, AGENT_ROLE y COMPLIANCE_ROLE"
for role_label in "DEFAULT_ADMIN_ROLE:$DEFAULT_ADMIN_ROLE" "AGENT_ROLE:$AGENT_ROLE" "COMPLIANCE_ROLE:$COMPLIANCE_ROLE"; do
    label="${role_label%%:*}"; role="${role_label#*:}"
    got="$("$CAST" call "$TOKEN" 'hasRole(bytes32,address)(bool)' "$role" "$SENDER" --rpc-url "$RPC_URL" 2>/dev/null)"
    [ "$got" = "false" ] || fail "token: la EOA conserva $label"
done
ok "  token: la EOA ya no tiene roles (renounceRole aplicado)"

ok "ADOPCIÓN COMPLETA: la gobernanza pasa al multisig; la EOA queda sin administración."
warn "Recuerda: operar ahora requiere propuesta + aprobaciones (umbral) + timelock (${DELAY}s)."
