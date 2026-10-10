#!/usr/bin/env bash
#
# RF-006 (Ciclo 10) — control de deriva de ABIs. Concreta el check de CU-12
# `ci_check_RF006_abi_diff_automatico`.
#
# Compara la ABI actual de cada contrato de `src/` (`forge inspect <C> abi --json`)
# contra la línea base versionada en `sc/abis/<C>.json`. Si hay diferencias:
#   - exige que el contrato esté declarado en `CHANGELOG_ABIS.md`;
#   - y que cada firma cambiada (o su selector) esté declarada también.
#
# SIN DEPENDENCIAS EXTERNAS: solo `forge`, `diff`, `comm`, `grep`, `sort` y `sed`.
# (La imagen oficial de Foundry es `ubuntu:22.04` + `git`: NO trae `jq` ni `python3`;
#  por eso la línea base se guarda como la salida cruda de `forge inspect`, que es
#  determinista con el compilador y la versión de forge fijados — v1.8.3 / solc 0.8.20.)
#
# Uso:
#   script/ci/abi_diff.sh            # verifica (exit 0 = sin deriva no declarada)
#   script/ci/abi_diff.sh --update   # regenera la línea base
#
# Procedimiento para actualizar la línea base:
#   1. Cambiar el contrato en `src/`.
#   2. Añadir la sección en `CHANGELOG_ABIS.md` (contrato + firma anterior/nueva + selector + impacto).
#   3. `script/ci/abi_diff.sh --update` y commitear `sc/abis/` junto a la entrada del changelog.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"
cd "${PROJECT_ROOT}"

ABI_DIR="${PROJECT_ROOT}/abis"
CHANGELOG="${REPO_ROOT}/CHANGELOG_ABIS.md"
MODE="${1:-check}"

if ! command -v forge >/dev/null 2>&1; then
    export PATH="${HOME}/.foundry/bin:${PATH}"
fi
if ! command -v forge >/dev/null 2>&1; then
    echo "FAIL: 'forge' no está disponible en el PATH" >&2
    exit 2
fi

# Lista canónica de contratos: todo `.sol` de `src/` (nombre de archivo = contrato).
mapfile -t CONTRACTS < <(find src -name '*.sol' -printf '%f\n' | sed 's/\.sol$//' | sort)

if [ "${#CONTRACTS[@]}" -eq 0 ]; then
    echo "FAIL: no se ha encontrado ningún contrato en src/" >&2
    exit 2
fi

# ABI cruda y determinista del contrato.
abi_raw() {
    forge inspect "$1" abi --json
}

# Firmas de función (una por línea, ordenadas). Se obtienen de la tabla de
# `forge inspect <C> methods`, que es texto plano y no requiere JSON parser.
fn_signatures() {
    forge inspect "$1" methods 2>/dev/null \
        | awk -F'|' 'NF >= 3 { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' \
        | grep -E '^[A-Za-z_][A-Za-z0-9_]*\(' \
        | sort -u
}

if [ "${MODE}" = "--update" ]; then
    mkdir -p "${ABI_DIR}"
    for c in "${CONTRACTS[@]}"; do
        abi_raw "${c}" > "${ABI_DIR}/${c}.json"
        fn_signatures "${c}" > "${ABI_DIR}/${c}.methods"
    done
    echo "OK: línea base de ABIs regenerada en sc/abis/ (${#CONTRACTS[@]} contratos: .json + .methods)."
    echo "RECUERDA: añade la entrada correspondiente en CHANGELOG_ABIS.md y commitea ambos."
    exit 0
fi

if [ ! -d "${ABI_DIR}" ]; then
    echo "FAIL: falta el directorio de línea base 'sc/abis/'" >&2
    exit 1
fi
if [ ! -f "${CHANGELOG}" ]; then
    echo "FAIL: falta CHANGELOG_ABIS.md" >&2
    exit 1
fi

drift=0
declare -a failures=()

# Base git para exigir que el changelog se actualice EN EL MISMO CAMBIO que la ABI.
# En CI: SHA base del MR o el commit anterior del push. En local: HEAD~1 si existe.
git_base=""
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    if [ -n "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" ] && git rev-parse -q --verify "${CI_MERGE_REQUEST_DIFF_BASE_SHA}" >/dev/null 2>&1; then
        git_base="${CI_MERGE_REQUEST_DIFF_BASE_SHA}"
    elif [ -n "${CI_COMMIT_BEFORE_SHA:-}" ] && [ "${CI_COMMIT_BEFORE_SHA}" != "0000000000000000000000000000000000000000" ] \
        && git rev-parse -q --verify "${CI_COMMIT_BEFORE_SHA}" >/dev/null 2>&1; then
        git_base="${CI_COMMIT_BEFORE_SHA}"
    elif git rev-parse -q --verify HEAD~1 >/dev/null 2>&1; then
        git_base="HEAD~1"
    fi
fi

for c in "${CONTRACTS[@]}"; do
    baseline="${ABI_DIR}/${c}.json"
    if [ ! -f "${baseline}" ]; then
        echo "FAIL: no existe la línea base sc/abis/${c}.json" >&2
        failures+=("${c}: falta la línea base")
        drift=1
        continue
    fi

    current="$(mktemp)"
    abi_raw "${c}" > "${current}"

    if diff -q "${baseline}" "${current}" >/dev/null; then
        rm -f "${current}"
        continue
    fi

    drift=1
    echo "DERIVA: la ABI de '${c}' difiere de sc/abis/${c}.json"
    diff -u "${baseline}" "${current}" | sed 's/^/    /' | head -40 || true

    # Declaración en el changelog: el contrato debe aparecer y, si hay base git,
    # CHANGELOG_ABIS.md debe venir actualizado en este mismo cambio (evita que una
    # deriva pase "de prestado" por una mención histórica del contrato).
    if ! grep -qF "${c}" "${CHANGELOG}"; then
        failures+=("${c}: el contrato no aparece en CHANGELOG_ABIS.md")
        rm -f "${current}"
        continue
    fi

    if [ -n "${git_base}" ]; then
        # Cambios del conjunto (commits desde la base + árbol de trabajo, para que el gate
        # también sirva antes de commitear en local).
        changed_files="$( { git diff --name-only "${git_base}" HEAD 2>/dev/null || true; \
                            git status --porcelain 2>/dev/null | awk '{print $2}' || true; } | sort -u )"
        if ! printf '%s\n' "${changed_files}" | grep -q 'CHANGELOG_ABIS.md'; then
            failures+=("${c}: hay deriva de ABI pero CHANGELOG_ABIS.md no se actualiza en este cambio")
        fi
    fi

    # Comparación a nivel de firma (solo si existe la línea base .methods).
    if [ -f "${ABI_DIR}/${c}.methods" ]; then
        current_methods="$(mktemp)"
        fn_signatures "${c}" > "${current_methods}"
        changed_sigs="$(comm -3 "${ABI_DIR}/${c}.methods" "${current_methods}" | tr -d '\t' | sed '/^$/d' || true)"

        if [ -z "${changed_sigs}" ]; then
            echo "    (solo cambian salidas/eventos; contrato declarado en CHANGELOG_ABIS.md)"
        else
            while IFS= read -r sig; do
                [ -z "${sig}" ] && continue
                selector="$(cast sig "${sig}")"
                if ! grep -qF "${selector}" "${CHANGELOG}" && ! grep -qF "${sig}" "${CHANGELOG}"; then
                    failures+=("${c}: firma '${sig}' (${selector}) no declarada en CHANGELOG_ABIS.md")
                fi
            done <<< "${changed_sigs}"
        fi
        rm -f "${current_methods}"
    fi
    rm -f "${current}"
done

if [ "${#failures[@]}" -gt 0 ]; then
    echo ""
    echo "FAIL: deriva de ABIs no declarada:" >&2
    for f in "${failures[@]}"; do
        echo "  - ${f}" >&2
    done
    echo "Actualiza sc/abis/ con 'script/ci/abi_diff.sh --update' y añade la entrada en CHANGELOG_ABIS.md." >&2
    exit 1
fi

if [ "${drift}" -eq 1 ]; then
    echo "OK: deriva detectada y declarada en CHANGELOG_ABIS.md (revisa que la línea base esté actualizada)."
else
    echo "OK: ${#CONTRACTS[@]} ABIs sin deriva respecto a sc/abis/."
fi
