#!/usr/bin/env bash
# =============================================================================
# check_role_wallets.sh — Gate H-11 / C0: ninguna wallet de rol puede ser una
# cuenta conocida de Anvil/Hardhat (claves privadas públicas).
# =============================================================================
# Uso: bash sc/script/ci/check_role_wallets.sh [config.json]
#   config.json por defecto: sc/config/v3_roles.json
# Falla (exit 1) si:
#   - una wallet de rol del config coincide con una cuenta conocida de Anvil;
#   - el `admin` del artefacto de despliegue coincide con una cuenta conocida;
#   - el config no contiene token ni wallets de rol.
# Autosuficiente: solo bash + grep/sort (la imagen de CI no trae jq/python).
# =============================================================================
set -euo pipefail

SC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="${1:-${SC_DIR}/config/v3_roles.json}"

# Cuentas conocidas del mnemónico por defecto de Anvil/Hardhat (minúsculas).
KNOWN_ANVIL="
0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
0x70997970c51812dc3a010c7d01b50e0d17dc79c8
0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc
0x90f79bf6eb2c4f870365e785982e1f101e93b906
0x15d34aaf54267db7d7c367839aaf71a00a2c6a65
0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc
0x976ea74026e726554db657fa54763abd0c3a0aa9
0x14dc79964da2c08b23698b3d3cc7ca32193d9955
0x23618e81e3f5cdf7f54c3d65f7beb7d73c26c1f4
0xa0ee7a142d267c1f36714e4a8f75612f20a79720
"

if [ ! -f "$CONFIG" ]; then
  echo "FAIL: no existe $CONFIG" >&2
  exit 1
fi

lower() { tr 'A-F' 'a-f'; }
fail=0

addresses="$(grep -oE '0x[0-9a-fA-F]{40}' "$CONFIG" | lower | sort -u)"
if [ -z "$addresses" ]; then
  echo "FAIL: $CONFIG no contiene direcciones de rol" >&2
  exit 1
fi

for addr in $addresses; do
  for known in $KNOWN_ANVIL; do
    if [ "$addr" = "$known" ]; then
      echo "FAIL: wallet de rol $addr coincide con una cuenta conocida de Anvil (H-11)" >&2
      fail=1
    fi
  done
done

# Admin declarado en los artefactos de despliegue de BRLT
for artifact in "${SC_DIR}"/deployments/*-barlo.json; do
  [ -e "$artifact" ] || continue
  admin="$(grep -oE '"admin"[[:space:]]*:[[:space:]]*"0x[0-9a-fA-F]{40}"' "$artifact" \
            | grep -oE '0x[0-9a-fA-F]{40}' | lower)"
  [ -n "$admin" ] || continue
  for known in $KNOWN_ANVIL; do
    if [ "$admin" = "$known" ]; then
      echo "FAIL: admin de $(basename "$artifact") ($admin) es una cuenta conocida de Anvil (H-11)" >&2
      fail=1
    fi
  done
done

if [ "$fail" -ne 0 ]; then
  echo "GATE H-11: FALLA — rota las claves de rol (Secret Manager) y redespliega." >&2
  exit 1
fi

echo "OK: ninguna wallet de rol coincide con cuentas conocidas de Anvil ($(echo "$addresses" | wc -l | tr -d ' ') wallets revisadas)."
