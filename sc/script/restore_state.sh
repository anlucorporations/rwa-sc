#!/usr/bin/env bash
# =============================================================================
# restore_state.sh — Restauración verificada del estado on-chain (H-30)
# =============================================================================
# Restaura un backup generado por backup_state.sh en un nodo Anvil limpio
# (anvil_loadState) y verifica el resultado. Mide el RTO del ensayo.
#
# Uso:
#   BACKUP_DIR=backups/<ts> RPC_URL=http://127.0.0.1:8545 ./script/restore_state.sh
# Opcionales:
#   FORCE=1     permite cargar sobre un nodo con bloque > 0 (por defecto exige nodo limpio)
#   VERIFY_DEPLOYMENT=1  verifica contratos/roles del deployment.json del backup
#
# Requisitos: cast/anvil (Foundry), jq, sha256sum. El nodo destino debe exponer
# `anvil_loadState` (Anvil con admin RPC).
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { printf '%b\n' "${BLUE}$*${NC}"; }
ok()   { printf '%b\n' "${GREEN}$*${NC}"; }
warn() { printf '%b\n' "${YELLOW}$*${NC}"; }
fail() { printf '%b\n' "${RED}ERROR: $*${NC}" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SC_DIR" || fail "no se pudo entrar en $SC_DIR"
export PATH="$HOME/.foundry/bin:$PATH"
command -v cast >/dev/null || fail "falta cast"
command -v jq   >/dev/null || fail "falta jq"

RPC_URL="${RPC_URL:-}"; [ -n "$RPC_URL" ] || fail "RPC_URL no definida"
BACKUP_DIR="${BACKUP_DIR:-}"; [ -n "$BACKUP_DIR" ] || fail "BACKUP_DIR no definido"
[ -d "$BACKUP_DIR" ] || fail "BACKUP_DIR no existe: $BACKUP_DIR"
[ -f "$BACKUP_DIR/anvil-state.hex" ] || fail "falta $BACKUP_DIR/anvil-state.hex"
[ -f "$BACKUP_DIR/metadata.json" ]  || fail "falta $BACKUP_DIR/metadata.json"

log "1/5 · Verificación de integridad del backup (MANIFEST.sha256)"
if [ -f "$BACKUP_DIR/MANIFEST.sha256" ]; then
    ( cd "$BACKUP_DIR" && sha256sum -c MANIFEST.sha256 >/dev/null ) || fail "el backup no pasa la verificación sha256 (corrupto o alterado)"
    ok "Manifiesto OK"
else
    warn "sin MANIFEST.sha256: no se puede verificar integridad"
fi

EXPECTED_CHAIN="$(jq -r '.chainId' "$BACKUP_DIR/metadata.json")"
EXPECTED_BLOCK="$(jq -r '.block' "$BACKUP_DIR/metadata.json")"
TARGET_CHAIN="$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null)" || fail "no se pudo consultar chain-id del destino"
[ "$TARGET_CHAIN" = "$EXPECTED_CHAIN" ] || fail "chain-id destino ($TARGET_CHAIN) != backup ($EXPECTED_CHAIN)"
TARGET_BLOCK="$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)"
if [ "$TARGET_BLOCK" != "0" ] && [ "${FORCE:-0}" != "1" ]; then
    fail "el nodo destino no está limpio (bloque $TARGET_BLOCK); usa FORCE=1 para cargar sobre estado existente"
fi
ok "Destino válido: chain $TARGET_CHAIN (bloque actual $TARGET_BLOCK) · backup en bloque $EXPECTED_BLOCK"

START_MS="$(date +%s%3N)"
log "2/5 · Restaurando estado (anvil_loadState)"
# El volcado (cientos de KB) supera el límite de argv (MAX_ARG_STRLEN ≈128 KB): se envía la
# petición JSON-RPC por HTTP con Python, sin pasar el estado por argumentos.
RPC_URL="$RPC_URL" STATE_FILE="$BACKUP_DIR/anvil-state.hex" python3 - <<'PY'
import json, os, sys, urllib.request

rpc = os.environ["RPC_URL"]
state = open(os.environ["STATE_FILE"], "r").read().strip()
payload = json.dumps({
    "jsonrpc": "2.0", "id": 1, "method": "anvil_loadState", "params": [state],
}).encode()
req = urllib.request.Request(rpc, data=payload, headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=180) as resp:
        out = json.load(resp)
except Exception as exc:  # pragma: no cover
    sys.stderr.write("anvil_loadState: %s\n" % exc)
    sys.exit(1)
if "error" in out:
    sys.stderr.write("anvil_loadState error: %s\n" % out["error"])
    sys.exit(1)
print(out.get("result"))
PY
[ $? -eq 0 ] || fail "anvil_loadState falló"
ok "Estado cargado"

log "3/5 · Verificando estado restaurado"
RESTORED_BLOCK="$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)"
[ "$RESTORED_BLOCK" = "$EXPECTED_BLOCK" ] || fail "bloque restaurado ($RESTORED_BLOCK) != esperado ($EXPECTED_BLOCK)"
END_MS="$(date +%s%3N)"
RTO_MS=$(( END_MS - START_MS ))
ok "Bloque restaurado = $EXPECTED_BLOCK · RTO ensayado = ${RTO_MS} ms"

log "4/5 · Verificación del despliegue (si VERIFY_DEPLOYMENT=1 y hay artefacto)"
if [ "${VERIFY_DEPLOYMENT:-0}" = "1" ] && [ -f "$BACKUP_DIR/deployment.json" ]; then
    verify_code() {
        local name="$1" addr="$2"
        [ -n "$addr" ] && [ "$addr" != "null" ] && [ "$addr" != "0x0000000000000000000000000000000000000000" ] || return 0
        local code; code="$(cast code "$addr" --rpc-url "$RPC_URL" 2>/dev/null)"
        [ -n "$code" ] && [ "$code" != "0x" ] || fail "$name sin código tras restaurar ($addr)"
    }
    for key in IdentityRegistry TrustedIssuersRegistry TokenCloneFactory IdentityCloneFactory ClaimTopicsRegistryCloneFactory ComplianceAggregator ClaimTopicsRegistry; do
        verify_code "$key" "$(jq -r --arg k "$key" '.contracts[$k]' "$BACKUP_DIR/deployment.json")"
    done
    TOKEN="$(jq -r '.token.address' "$BACKUP_DIR/deployment.json")"
    verify_code "Token" "$TOKEN"
    NAME="$(cast call "$TOKEN" 'name()(string)' --rpc-url "$RPC_URL" 2>/dev/null | tr -d '"')"
    [ "$NAME" = "RWA Demo Token" ] || fail "token.name() tras restaurar inesperado: '$NAME'"
    IR="$(jq -r '.contracts.IdentityRegistry' "$BACKUP_DIR/deployment.json")"
    REGISTERED="$(cast call "$IR" 'isRegistered(address)(bool)' "$(jq -r '.deployer' "$BACKUP_DIR/deployment.json")" --rpc-url "$RPC_URL" 2>/dev/null)"
    [ "$REGISTERED" = "true" ] || fail "la identidad del deployer no está registrada tras restaurar"
    ok "Contratos, token y registro de identidad verificados"
else
    warn "VERIFY_DEPLOYMENT != 1: se omite la verificación de contratos"
fi

log "5/5 · Resumen"
jq -n --argjson block "$EXPECTED_BLOCK" --argjson rto "$RTO_MS" \
    '{restoredBlock:$block, rtoMs:$rto, rtoTargetHours:4, rtoOk:($rto < 4*3600*1000)}'
ok "RESTAURACIÓN COMPLETA (RTO ${RTO_MS} ms ≤ 4 h: RNF-502)"
