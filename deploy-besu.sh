#!/usr/bin/env bash
#
# RWA - Wrapper de compatibilidad (Ciclo 9 / RF-010)
# -------------------------------------------------
# El despliegue canonico y verificable vive ahora en `sc/script/deploy.sh` y en el script
# Solidity `sc/script/DeployFullStack.s.sol`. Este archivo se conserva por compatibilidad:
# mantiene el nombre historico `deploy-besu.sh` y el destino por defecto **Besu CodeCrypto**,
# pero ya NO lee archivos de claves en disco ni decide el exito por `grep` de logs.
#
#   * Para el Anvil de GCP:
#       source /home/dsh/workspace/gcp-env.sh
#       sc/script/deploy.sh
#   * Para Besu (alternativa documentada), con la clave en el entorno:
#       RPC_URL=https://besu1.proyectos.codecrypto.academy \
#       CHAIN_ID=<chainId de Besu> ADMIN_PRIVATE_KEY=<clave> \
#       ./deploy-besu.sh
#
# La validacion de red (`cast chain-id` == CHAIN_ID) y la verificacion on-chain las hace
# `sc/script/deploy.sh`.

set +u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEFAULT_BESU_RPC="https://besu1.proyectos.codecrypto.academy"
if [ -z "${RPC_URL:-}" ]; then
    RPC_URL="$DEFAULT_BESU_RPC"
fi
export RPC_URL

# Si no se declara CHAIN_ID, se autodetecta para que la validacion previa siga siendo efectiva.
if [ -z "${CHAIN_ID:-}" ]; then
    export PATH="$HOME/.foundry/bin:$PATH"
    CHAIN_ID="$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null)"
    if [ -z "$CHAIN_ID" ]; then
        echo "ERROR: no se pudo autodetectar el chain-id de $RPC_URL; define CHAIN_ID explicitamente." >&2
        exit 1
    fi
    export CHAIN_ID
fi

echo "deploy-besu.sh -> delegando en sc/script/deploy.sh (red: $RPC_URL, chain-id: $CHAIN_ID)"
exec "$SCRIPT_DIR/sc/script/deploy.sh"
