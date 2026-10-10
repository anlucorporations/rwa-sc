#!/usr/bin/env bash
#
# RF-002 (Ciclo 3) — gate de CI `ci_check_RF002_no_bypassCompliance_storage`.
#
# Falla (exit != 0) si el storage layout de `TokenCloneable` vuelve a contener el
# flag mutable `bypassCompliance` que RF-002 retiró. El contrato se inspecciona con
# `forge inspect ... storage-layout --json`, de modo que la comprobación es sobre el
# layout real compilado y no sobre el código fuente.
#
# Uso: script/ci/check_no_bypass_flag.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# El toolchain de Foundry no siempre está en el PATH de los runners de CI.
if ! command -v forge >/dev/null 2>&1; then
    export PATH="${HOME}/.foundry/bin:${PATH}"
fi

if ! command -v forge >/dev/null 2>&1; then
    echo "FAIL: 'forge' no está disponible en el PATH" >&2
    exit 2
fi

layout="$(forge inspect TokenCloneable storage-layout --json)"

if printf '%s' "${layout}" | grep -q 'bypassCompliance'; then
    echo "FAIL: 'bypassCompliance' sigue presente en el storage layout de TokenCloneable" >&2
    printf '%s\n' "${layout}" | grep -n 'bypassCompliance' >&2 || true
    exit 1
fi

echo "OK: TokenCloneable no expone 'bypassCompliance' en su storage layout"
