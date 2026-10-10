#!/usr/bin/env bash
#
# RF-009 (Ciclo 11) — gate de cobertura RNF-002 / D-017 / D-042.
#
# Comprueba DOS condiciones sobre el reporte `forge coverage --report summary`:
#   (1) AGREGADO de `src/` (excluyendo las interfaces de D-017:
#       `src/ICompliance.sol` y `src/IClaimTopicsRegistry.sol`) >= COVERAGE_THRESHOLD.
#   (2) MÍNIMO POR CONTRATO >= COVERAGE_CONTRACT_THRESHOLD (D-042), sobre las
#       MISMAS líneas (% Lines), para que un promedio alto no oculte un contrato
#       concreto sin cubrir. Las ramas se reportan pero NO bloquean: hay contratos
#       por debajo del 80 % de ramas por diseño (p. ej. `MaxBalanceCompliance`
#       66,67 %), y D-017 fija el agregado sobre líneas.
#
# El umbral se lee de UNA única variable (CU-11 · EARS
# `ci_check_RF009_umbral_configurable_centralizado`):
#   COVERAGE_THRESHOLD=[0-100]           (por defecto 80)
#   COVERAGE_CONTRACT_THRESHOLD=[0-100]  (por defecto = COVERAGE_THRESHOLD)
#   COVERAGE_EXCLUDE="fichero1 fichero2" (por defecto las dos interfaces de D-017)
#
# Uso:
#   script/ci/check_coverage.sh [resumen.txt]
#
# Sin argumento ejecuta `forge coverage --report summary`; con argumento parsea el
# resumen ya volcado a fichero (lo que usa el job `coverage` del pipeline para no
# recompilar dos veces). El reporte `lcov.info` lo genera el job aparte.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

THRESHOLD="${COVERAGE_THRESHOLD:-80}"
CONTRACT_THRESHOLD="${COVERAGE_CONTRACT_THRESHOLD:-${THRESHOLD}}"
EXCLUDE="${COVERAGE_EXCLUDE:-src/ICompliance.sol src/IClaimTopicsRegistry.sol}"

SUMMARY_FILE="${1:-}"

if [ -z "${SUMMARY_FILE}" ]; then
    if ! command -v forge >/dev/null 2>&1; then
        export PATH="${HOME}/.foundry/bin:${PATH}"
    fi
    if ! command -v forge >/dev/null 2>&1; then
        echo "FAIL: 'forge' no está disponible en el PATH" >&2
        exit 2
    fi
    SUMMARY_FILE="$(mktemp)"
    trap 'rm -f "${SUMMARY_FILE}"' EXIT
    forge coverage --report summary > "${SUMMARY_FILE}" 2>&1
elif [ ! -f "${SUMMARY_FILE}" ]; then
    echo "FAIL: no existe el resumen de cobertura '${SUMMARY_FILE}'" >&2
    exit 2
fi

if ! grep -q '% Lines' "${SUMMARY_FILE}"; then
    echo "FAIL: '${SUMMARY_FILE}' no parece un resumen de 'forge coverage --report summary'" >&2
    exit 2
fi

trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

is_excluded() {
    local f="$1" ex
    for ex in ${EXCLUDE}; do
        [ "${f}" = "${ex}" ] && return 0
    done
    return 1
}

# Lista canónica de contratos de `src/` (excluyendo interfaces) que sí aparecen en
# el reporte con líneas medibles.
files=()
covs=()
tots=()
pcts=()

while IFS='|' read -r _ file lines _; do
    file="$(trim "${file}")"
    case "${file}" in
        src/*) ;;
        *) continue ;;
    esac
    is_excluded "${file}" && continue

    # `lines` tiene la forma " 91.53% (54/59) " (o "N/A (0/0)").
    if [[ "${lines}" =~ \(([0-9]+)/([0-9]+)\) ]]; then
        c="${BASH_REMATCH[1]}"
        t="${BASH_REMATCH[2]}"
    else
        continue
    fi
    [ "${t}" -eq 0 ] && continue   # contrato sin líneas medibles: no evaluable

    pct="$(awk -v c="${c}" -v t="${t}" 'BEGIN { printf "%.2f", (c * 100.0) / t }')"
    files+=("${file}")
    covs+=("${c}")
    tots+=("${t}")
    pcts+=("${pct}")
done < <(grep -E '^\|' "${SUMMARY_FILE}")

if [ "${#files[@]}" -eq 0 ]; then
    echo "FAIL: no se ha podido parsear ningún contrato de 'src/' en el resumen de cobertura" >&2
    exit 2
fi

# --- Agregado de src/ --------------------------------------------------------
sum_cov=0
sum_tot=0
for i in "${!files[@]}"; do
    sum_cov=$((sum_cov + covs[i]))
    sum_tot=$((sum_tot + tots[i]))
done
agg_pct="$(awk -v c="${sum_cov}" -v t="${sum_tot}" 'BEGIN { printf "%.2f", (c * 100.0) / t }')"

# --- Mínimo por contrato -----------------------------------------------------
min_idx=0
for i in "${!files[@]}"; do
    if awk -v a="${pcts[i]}" -v b="${pcts[min_idx]}" 'BEGIN { exit !(a < b) }'; then
        min_idx="${i}"
    fi
done

echo "Cobertura (líneas) sobre ${#files[@]} contratos de src/ (D-017: sin interfaces):"
printf '  agregado src/                     : %s%% (%s/%s)\n' "${agg_pct}" "${sum_cov}" "${sum_tot}"
printf '  mínimo por contrato               : %s%% (%s)\n' "${pcts[$min_idx]}" "${files[$min_idx]}"
printf '  umbral agregado / por contrato    : %s%% / %s%%\n' "${THRESHOLD}" "${CONTRACT_THRESHOLD}"

fail=0

if ! awk -v a="${agg_pct}" -v b="${THRESHOLD}" 'BEGIN { exit !(a >= b) }'; then
    echo "FAIL: cobertura agregada de src/ ${agg_pct}% < ${THRESHOLD}% (RNF-002 / D-017)" >&2
    fail=1
fi

low=0
for i in "${!files[@]}"; do
    if ! awk -v a="${pcts[i]}" -v b="${CONTRACT_THRESHOLD}" 'BEGIN { exit !(a >= b) }'; then
        echo "FAIL: contrato ${files[$i]} con cobertura de líneas ${pcts[$i]}% (${covs[$i]}/${tots[$i]}) < ${CONTRACT_THRESHOLD}% (D-042)" >&2
        low=1
    fi
done
[ "${low}" -eq 1 ] && fail=1

if [ "${fail}" -ne 0 ]; then
    echo "" >&2
    echo "FAIL: gate de cobertura RF-009 (RNF-002 / D-042)." >&2
    exit 1
fi

echo "OK: cobertura agregada de src/ ${agg_pct}% >= ${THRESHOLD}% y mínimo por contrato ${pcts[$min_idx]}% >= ${CONTRACT_THRESHOLD}% (${files[$min_idx]})."
