#!/usr/bin/env bash
# =============================================================================
# test_adopt_governance.sh — Drill end-to-end de H-06 (R-7 / D-021) en Anvil efímero
# =============================================================================
# Verifica, sobre una red limpia y sin tocar el despliegue canónico:
#   1. Despliegue completo del stack (DeployFullStack) con la EOA admin.
#   2. Despliegue del GovernanceMultisig (2-de-3, timelock corto para el drill).
#   3. Adopción: propiedad de los contratos + roles del token al multisig; la EOA renuncia.
#   4. Postcondiciones: owner()/hasRole() coherentes; la EOA ya NO puede administrar.
#   5. Operatividad de la gobernanza: propuesta -> 2 aprobaciones -> timelock -> execute
#      (grantRole(AGENT_ROLE, operador) ejecutado por el multisig).
#
# Uso:  ./script/ci/test_adopt_governance.sh
# Requisitos: forge/anvil/cast, jq, python3+eth_keyfile (creación de keystore).
# No modifica el repo: usa un artefacto temporal en /tmp.
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { printf '%b\n' "${BLUE}▶ $*${NC}"; }
ok()   { printf '%b\n' "${GREEN}✓ $*${NC}"; }
warn() { printf '%b\n' "${YELLOW}⚠ $*${NC}"; }
fail() { printf '%b\n' "${RED}✗ $*${NC}" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SC_DIR" || fail "no se pudo entrar en $SC_DIR"

export PATH="$HOME/.foundry/bin:$PATH"
command -v forge >/dev/null || fail "falta forge"
command -v anvil >/dev/null || fail "falta anvil"
command -v cast  >/dev/null || fail "falta cast"
command -v jq    >/dev/null || fail "falta jq"

PORT="${DRILL_PORT:-8555}"
RPC="http://127.0.0.1:${PORT}"
TMP="$(mktemp -d /tmp/rwa-h06-XXXXXX)"
ANVIL_PID=""
cleanup() {
    [ -n "$ANVIL_PID" ] && kill "$ANVIL_PID" 2>/dev/null || true
    fuser -k "${PORT}/tcp" 2>/dev/null || true
    rm -rf "$TMP"
    [ -n "${DEPLOYMENT_JSON:-}" ] && rm -f "$SC_DIR/$DEPLOYMENT_JSON"
}
trap cleanup EXIT INT TERM

# Claves de test de Anvil (públicas por diseño; solo red local efímera).
K0=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
K1=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
K2=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
K3=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
A0=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
A1=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
A2=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
A3=0x90F79bf6EB2c4f870365E785982E1f101E93b906

norm() { printf '%s' "$1" | sed -E 's/[[:space:]]*\[[^]]*\][[:space:]]*$//' | tr -d '[:space:]'; }

log "1/6 · Anvil efímero en ${RPC}"
anvil --host 127.0.0.1 --port "$PORT" --chain-id 31337 >"$TMP/anvil.log" 2>&1 &
ANVIL_PID=$!
for _ in $(seq 1 30); do cast chain-id --rpc-url "$RPC" >/dev/null 2>&1 && break; sleep 1; done
[ "$(cast chain-id --rpc-url "$RPC" 2>/dev/null)" = "31337" ] || fail "Anvil no arrancó en $RPC"
ok "Anvil listo (chain 31337)"

log "2/6 · Despliegue completo del stack (EOA admin)"
DEPLOYMENT_JSON="deployments/drill-$$-$(date -u +%Y%m%dT%H%M%SZ).json"
export DEPLOYMENT_JSON
forge script script/DeployFullStack.s.sol:DeployFullStack \
    --rpc-url "$RPC" --private-key "$K0" --broadcast -vv >"$TMP/deploy.log" 2>&1 \
    || { tail -30 "$TMP/deploy.log" >&2; fail "DeployFullStack falló"; }
[ -f "$DEPLOYMENT_JSON" ] || fail "no se generó el artefacto de despliegue"
TOKEN="$(jq -r '.token.address' "$DEPLOYMENT_JSON")"
IR="$(jq -r '.contracts.IdentityRegistry' "$DEPLOYMENT_JSON")"
ok "Stack desplegado · token=$TOKEN · identityRegistry=$IR"

log "3/6 · Despliegue del GovernanceMultisig (2-de-3, delay 10 s para el drill)"
GOVERNANCE_OWNER_1="$A0" GOVERNANCE_OWNER_2="$A1" GOVERNANCE_OWNER_3="$A2" \
GOVERNANCE_THRESHOLD=2 GOVERNANCE_DELAY=10 \
forge script script/DeployGovernance.s.sol:DeployGovernance \
    --rpc-url "$RPC" --private-key "$K0" --broadcast -vv >"$TMP/governance.log" 2>&1 \
    || { tail -20 "$TMP/governance.log" >&2; fail "DeployGovernance falló"; }
MULTISIG="$(grep -oE 'GovernanceMultisig: 0x[0-9a-fA-F]{40}' "$TMP/governance.log" | tail -1 | awk '{print $2}')"
[ -n "$MULTISIG" ] || fail "no se pudo extraer la dirección del multisig"
[ "$(cast call "$MULTISIG" 'threshold()(uint256)' --rpc-url "$RPC" | awk '{print $1}')" = "2" ] || fail "threshold != 2"
ok "Multisig desplegado: $MULTISIG (2-de-3, delay 10 s)"

log "4/6 · Adopción: propiedad y roles al multisig; la EOA renuncia"
RPC_URL="$RPC" CHAIN_ID=31337 ADMIN_PRIVATE_KEY="$K0" \
GOVERNANCE_MULTISIG="$MULTISIG" DEPLOYMENT_JSON="$DEPLOYMENT_JSON" \
ALLOW_SHORT_DELAY=1 ADOPT_SKIP_IDENTITY_REGISTRY=0 \
bash script/adopt_governance.sh >"$TMP/adopt.log" 2>&1 \
    || { tail -40 "$TMP/adopt.log" >&2; fail "adopt_governance.sh falló"; }
grep -q "ADOPCIÓN COMPLETA" "$TMP/adopt.log" || fail "la adopción no declaró éxito"
ok "Adopción completada y verificada (script + cast)"

log "5/6 · La EOA ya NO puede administrar directamente"
if cast send "$TOKEN" 'grantRole(bytes32,address)' "$(cast keccak 'AGENT_ROLE')" "$A3" \
    --private-key "$K0" --rpc-url "$RPC" >"$TMP/eoa-admin.log" 2>&1; then
    fail "la EOA pudo grantRole tras la adopción (¡fallo de gobernanza!)"
fi
ok "La EOA no puede administrar el token (revert esperado)"

log "6/6 · Operatividad de la gobernanza: propuesta -> aprobaciones -> timelock -> execute"
AGENT_ROLE="$(cast keccak 'AGENT_ROLE')"
CALLDATA="$(cast calldata 'grantRole(bytes32,address)' "$AGENT_ROLE" "$A3")"
cast send "$MULTISIG" 'propose(address,uint256,bytes)' "$TOKEN" 0 "$CALLDATA" \
    --private-key "$K0" --rpc-url "$RPC" >"$TMP/propose.log" 2>&1 \
    || { tail -20 "$TMP/propose.log" >&2; fail "propose falló"; }
cast send "$MULTISIG" 'approve(uint256)' 1 --private-key "$K0" --rpc-url "$RPC" >/dev/null 2>&1 || fail "approve K0 falló"
cast send "$MULTISIG" 'approve(uint256)' 1 --private-key "$K1" --rpc-url "$RPC" >/dev/null 2>&1 || fail "approve K1 falló"
cast rpc evm_increaseTime 15 --rpc-url "$RPC" >/dev/null
cast rpc evm_mine --rpc-url "$RPC" >/dev/null
cast send "$MULTISIG" 'execute(uint256)' 1 --private-key "$K1" --rpc-url "$RPC" >"$TMP/execute.log" 2>&1 \
    || { tail -20 "$TMP/execute.log" >&2; fail "execute falló"; }
GRANTED="$(norm "$(cast call "$TOKEN" 'hasRole(bytes32,address)(bool)' "$AGENT_ROLE" "$A3" --rpc-url "$RPC")")"
[ "$GRANTED" = "true" ] || fail "el multisig no pudo conceder AGENT_ROLE (hasRole=$GRANTED)"
ok "Gobierno operativo: AGENT_ROLE concedido por el multisig tras timelock"

ok "DRILL H-06 EN VERDE: adopción completa + gobernanza operativa"
printf '\nResumen:\n  multisig: %s\n  token:    %s\n  identityRegistry: %s\n  propuesta ejecutada: #1 (grantRole AGENT_ROLE → %s)\n' \
    "$MULTISIG" "$TOKEN" "$IR" "$A3"
