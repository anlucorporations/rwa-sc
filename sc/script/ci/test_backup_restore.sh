#!/usr/bin/env bash
# =============================================================================
# test_backup_restore.sh — Drill de backup/DR on-chain (H-30 / RNF-501..503)
# =============================================================================
# Ensayo reproducible:
#   1. Anvil efímero + despliegue completo del stack.
#   2. backup_state.sh (estado + artefacto + manifiesto).
#   3. Pérdida simulada del nodo (kill).
#   4. Nodo nuevo + restore_state.sh con verificación de contratos/roles/datos.
#   5. RTO medido y comparado con RNF-502 (≤ 4 h).
#
# Uso: ./script/ci/test_backup_restore.sh
# Requisitos: forge/anvil/cast, jq, sha256sum.
# No modifica el repo: artefacto temporal en sc/deployments/ y backup en /tmp.
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
for t in forge anvil cast jq sha256sum; do command -v "$t" >/dev/null || fail "falta $t"; done

PORT="${DRILL_PORT:-8557}"
RPC="http://127.0.0.1:${PORT}"
TMP="$(mktemp -d /tmp/rwa-h30-XXXXXX)"
ANVIL_PID=""
DEPLOYMENT_JSON="deployments/drill-h30-$$-$(date -u +%Y%m%dT%H%M%SZ).json"
cleanup() {
    [ -n "$ANVIL_PID" ] && kill "$ANVIL_PID" 2>/dev/null || true
    fuser -k "${PORT}/tcp" 2>/dev/null || true
    rm -rf "$TMP"
    rm -f "$SC_DIR/$DEPLOYMENT_JSON"
}
trap cleanup EXIT INT TERM

K0=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
A0=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

start_anvil() {
    anvil --host 127.0.0.1 --port "$PORT" --chain-id 31337 >"$TMP/anvil-$1.log" 2>&1 &
    ANVIL_PID=$!
    for _ in $(seq 1 30); do cast chain-id --rpc-url "$RPC" >/dev/null 2>&1 && break; sleep 1; done
    [ "$(cast chain-id --rpc-url "$RPC" 2>/dev/null)" = "31337" ] || fail "Anvil no arrancó"
}

log "1/6 · Anvil efímero + despliegue completo"
start_anvil 1
DEPLOYMENT_JSON="$DEPLOYMENT_JSON" forge script script/DeployFullStack.s.sol:DeployFullStack \
    --rpc-url "$RPC" --private-key "$K0" --broadcast >"$TMP/deploy.log" 2>&1 \
    || { tail -20 "$TMP/deploy.log" >&2; fail "despliegue falló"; }
BLOCK="$(cast block-number --rpc-url "$RPC")"
TOKEN="$(jq -r '.token.address' "$DEPLOYMENT_JSON")"
IR="$(jq -r '.contracts.IdentityRegistry' "$DEPLOYMENT_JSON")"
ok "Stack desplegado en bloque $BLOCK · token=$TOKEN"

log "2/6 · Backup (estado + artefacto + manifiesto)"
if ! RPC_URL="$RPC" DEPLOYMENT_JSON="$DEPLOYMENT_JSON" BACKUP_DIR="$TMP/backup" \
    bash script/backup_state.sh >"$TMP/backup.log" 2>&1; then
    tail -20 "$TMP/backup.log" >&2; fail "backup_state.sh falló"
fi
[ -f "$TMP/backup/anvil-state.hex" ] || fail "no se generó el volcado de estado"
[ -f "$TMP/backup/MANIFEST.sha256" ] || fail "no se generó el manifiesto"
ok "Backup: $(du -h "$TMP/backup/anvil-state.hex" | cut -f1) de estado · bloque $BLOCK"

log "3/6 · Pérdida simulada del nodo"
kill "$ANVIL_PID" 2>/dev/null; wait "$ANVIL_PID" 2>/dev/null; ANVIL_PID=""
fuser -k "${PORT}/tcp" 2>/dev/null || true
ok "Nodo caído (estado perdido)"

log "4/6 · Nodo nuevo + restauración verificada"
start_anvil 2
RTO_START="$(date +%s%3N)"
RPC_URL="$RPC" BACKUP_DIR="$TMP/backup" VERIFY_DEPLOYMENT=1 \
    bash script/restore_state.sh >"$TMP/restore.log" 2>&1 \
    || { tail -30 "$TMP/restore.log" >&2; fail "restore_state.sh falló"; }
RTO_END="$(date +%s%3N)"
RTO_MS=$(( RTO_END - RTO_START ))
ok "Restauración verificada en ${RTO_MS} ms"

log "5/6 · Comprobaciones independientes del estado restaurado"
[ "$(cast block-number --rpc-url "$RPC")" = "$BLOCK" ] || fail "bloque restaurado != $BLOCK"
[ "$(cast call "$TOKEN" 'name()(string)' --rpc-url "$RPC" | tr -d '"')" = "RWA Demo Token" ] || fail "token.name() inesperado"
[ "$(cast call "$IR" 'isRegistered(address)(bool)' "$A0" --rpc-url "$RPC")" = "true" ] || fail "identidad del deployer no restaurada"
MAXBURN="$(cast call "$TOKEN" 'maxBurnPerTx()(uint256)' --rpc-url "$RPC" | sed -E 's/ \[[^]]*\]$//' | tr -d '[:space:]')"
[ "$MAXBURN" = "1000000000000000000000000" ] || fail "maxBurnPerTx restaurado inesperado: $MAXBURN"
ok "Datos on-chain restaurados: bloque, token, identidad y topes"

log "6/6 · RPO/RTO del ensayo"
jq -n --arg rpo "bloque del backup ($BLOCK)" --argjson block "$BLOCK" --argjson rtoMs "$RTO_MS" \
    '{rpo:$rpo, block:$block, rtoMs:$rtoMs, rtoTargetMs:(4*3600*1000), rtoOk:($rtoMs < 4*3600*1000)}'
[ "$RTO_MS" -lt $(( 4 * 3600 * 1000 )) ] || fail "RTO ${RTO_MS} ms > 4 h (RNF-502)"
ok "DRILL H-30 EN VERDE: backup, pérdida, restauración verificada y RTO dentro de objetivo"
