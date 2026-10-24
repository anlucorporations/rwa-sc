#!/usr/bin/env bash
# =============================================================================
# backup_state.sh — Backup del estado on-chain + artefacto de despliegue (H-30)
# =============================================================================
# Genera un backup verificable en BACKUP_DIR:
#   anvil-state.hex   volcado completo del estado (anvil_dumpState, RPC admin)
#   deployment.json   copia del artefacto de despliegue usado (opcional)
#   metadata.json     chainId, bloque, timestamp, versión de anvil
#   MANIFEST.sha256   hashes de todos los ficheros del backup
#
# Uso:
#   RPC_URL=https://... ./script/backup_state.sh
#   DEPLOYMENT_JSON=deployments/<...>.json ./script/backup_state.sh
#   BACKUP_DIR=/ruta/de/backups ./script/backup_state.sh
#
# Requisitos: cast/anvil (Foundry), jq, sha256sum. El nodo debe exponer los
# métodos admin de Anvil (`anvil_dumpState`); si no, la recuperación se hace por
# redeploy limpio con el artefacto (RUNBOOK_MIGRACION.md §6).
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

RPC_URL="${RPC_URL:-}"
[ -n "$RPC_URL" ] || fail "RPC_URL no definida"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_DIR:-$SC_DIR/backups/$STAMP}"

CHAIN_ID="$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null)" || fail "no se pudo consultar chain-id en RPC_URL"
BLOCK="$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null)" || fail "no se pudo consultar el bloque actual"
ANVIL_VERSION="$(cast rpc web3_clientVersion --rpc-url "$RPC_URL" 2>/dev/null | tr -d '"' || true)"

mkdir -p "$BACKUP_DIR" || fail "no se pudo crear BACKUP_DIR: $BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

log "1/3 · Volcado de estado (anvil_dumpState) · chain $CHAIN_ID · bloque $BLOCK"
STATE_RAW="$(cast rpc anvil_dumpState --rpc-url "$RPC_URL" 2>/dev/null)" || true
if [ -z "$STATE_RAW" ] || [ "$STATE_RAW" = "null" ]; then
    fail "el nodo no expone 'anvil_dumpState' (¿no es Anvil o admin RPC deshabilitado?). Use redeploy limpio + artefacto como plan de recuperación."
fi
# cast rpc devuelve la cadena JSON-encoded; se desnormaliza a hex puro.
printf '%s' "$STATE_RAW" | jq -r . > "$BACKUP_DIR/anvil-state.hex" 2>/dev/null || printf '%s' "$STATE_RAW" > "$BACKUP_DIR/anvil-state.hex"
STATE_BYTES="$(wc -c < "$BACKUP_DIR/anvil-state.hex")"
[ "$STATE_BYTES" -gt 100 ] || fail "el volcado de estado es sospechosamente pequeño ($STATE_BYTES bytes)"
ok "Estado volcado: $STATE_BYTES bytes"

log "2/3 · Artefacto de despliegue"
if [ -n "${DEPLOYMENT_JSON:-}" ]; then
    [ -f "$DEPLOYMENT_JSON" ] || fail "DEPLOYMENT_JSON no existe: $DEPLOYMENT_JSON"
    cp "$DEPLOYMENT_JSON" "$BACKUP_DIR/deployment.json"
    jq -e . "$BACKUP_DIR/deployment.json" >/dev/null 2>&1 || fail "el artefacto copiado no es JSON válido"
    ok "Artefacto copiado: $(basename "$DEPLOYMENT_JSON")"
else
    warn "DEPLOYMENT_JSON no definido: backup solo con estado on-chain"
fi

log "3/3 · Metadatos y manifiesto"
jq -n \
    --arg ts "$STAMP" \
    --argjson chainId "$CHAIN_ID" \
    --argjson block "$BLOCK" \
    --arg anvil "$ANVIL_VERSION" \
    --argjson stateBytes "$STATE_BYTES" \
    '{timestampUtc:$ts, chainId:$chainId, block:$block, client:$anvil, stateBytes:$stateBytes, rpoNote:"RPO = bloque del backup; recuperable por anvil_loadState o redeploy desde el artefacto"}' \
    > "$BACKUP_DIR/metadata.json"
( cd "$BACKUP_DIR" && sha256sum anvil-state.hex metadata.json $( [ -f deployment.json ] && echo deployment.json ) > MANIFEST.sha256 ) \
    || fail "no se pudo generar el manifiesto"

cat "$BACKUP_DIR/MANIFEST.sha256" | sed 's/^/  /'
ok "BACKUP COMPLETO: $BACKUP_DIR"
