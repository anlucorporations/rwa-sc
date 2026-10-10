#!/usr/bin/env bash
#
# RF-006 (Ciclo 10) — control de deriva de ABIs. Concreta el check de CU-12
# `ci_check_RF006_abi_diff_automatico`.
#
# Compara la ABI actual de cada contrato de `src/` (obtenida con
# `forge inspect <Contrato> abi --json`) contra la línea base versionada en
# `sc/abis/<Contrato>.json`. Si detecta diferencias:
#   - exige que el contrato afectado esté declarado en `CHANGELOG_ABIS.md`
#     (a nivel de contrato y de cada selector nuevo/modificado/eliminado);
#   - si algo no está declarado, falla con exit 1 y lista los selectores del diff.
#
# Uso:
#   script/ci/abi_diff.sh            # verifica (exit 0 = sin deriva no declarada)
#   script/ci/abi_diff.sh --update   # regenera la línea base (requiere entrada en
#                                    # CHANGELOG_ABIS.md para el cambio)
#
# Procedimiento para actualizar la línea base:
#   1. Cambiar el contrato en `src/`.
#   2. Añadir la sección correspondiente en `CHANGELOG_ABIS.md` (contrato + firma
#      anterior/nueva + selector + impacto).
#   3. Ejecutar `script/ci/abi_diff.sh --update` y commitear `sc/abis/*.json`
#      junto con la entrada del changelog.
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
if ! command -v jq >/dev/null 2>&1; then
    echo "FAIL: 'jq' no está disponible en el PATH" >&2
    exit 2
fi

# Lista canónica de contratos: todo `.sol` de `src/` (nombre de archivo = contrato).
mapfile -t CONTRACTS < <(find src -name '*.sol' -printf '%f\n' | sed 's/\.sol$//' | sort)

if [ "${#CONTRACTS[@]}" -eq 0 ]; then
    echo "FAIL: no se ha encontrado ningún contrato en src/" >&2
    exit 2
fi

# Normaliza una ABI: claves ordenadas y entradas ordenadas de forma estable.
canon_abi() {
    jq -S 'sort_by([.type, (.name // ""), ((.inputs // []) | map(.type) | join(","))])' "$1"
}

# Firmas de función de una ABI (una por línea).
fn_signatures() {
    jq -r '.[] | select(.type == "function") | "\(.name)(\(.inputs | map(.type) | join(",")))"' "$1" | sort -u
}

abi_of() {
    mktemp
}

if [ "${MODE}" = "--update" ]; then
    mkdir -p "${ABI_DIR}"
    for c in "${CONTRACTS[@]}"; do
        forge inspect "${c}" abi --json | jq -S 'sort_by([.type, (.name // ""), ((.inputs // []) | map(.type) | join(","))])' > "${ABI_DIR}/${c}.json"
    done
    echo "OK: línea base de ABIs regenerada en sc/abis/ (${#CONTRACTS[@]} contratos)."
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

for c in "${CONTRACTS[@]}"; do
    baseline="${ABI_DIR}/${c}.json"
    if [ ! -f "${baseline}" ]; then
        echo "FAIL: no existe la línea base sc/abis/${c}.json" >&2
        failures+=("${c}: falta la línea base")
        drift=1
        continue
    fi

    tmp="$(abi_of)"
    forge inspect "${c}" abi --json | jq -S 'sort_by([.type, (.name // ""), ((.inputs // []) | map(.type) | join(","))])' > "${tmp}"

    if diff -q <(canon_abi "${baseline}") "${tmp}" >/dev/null; then
        rm -f "${tmp}"
        continue
    fi

    drift=1
    echo "DERIVA: la ABI de '${c}' difiere de sc/abis/${c}.json"
    diff -u <(canon_abi "${baseline}") "${tmp}" | sed 's/^/    /' || true

    # Declaración en el changelog: contrato + selectores nuevos/modificados/eliminados.
    if ! grep -qF "${c}" "${CHANGELOG}"; then
        failures+=("${c}: el contrato no aparece en CHANGELOG_ABIS.md")
        rm -f "${tmp}"
        continue
    fi

    old_sigs="$(fn_signatures "${baseline}")"
    new_sigs="$(fn_signatures "${tmp}")"
    changed_sigs="$(comm -3 <(printf '%s\n' "${old_sigs}") <(printf '%s\n' "${new_sigs}") | tr -d '\t' | sed '/^$/d' || true)"

    if [ -z "${changed_sigs}" ]; then
        echo "    (solo cambian salidas/eventos; contrato declarado en CHANGELOG_ABIS.md)"
    else
        while IFS= read -r sig; do
            [ -z "${sig}" ] && continue
            selector="$(cast sig "${sig}")"
            if ! grep -qF "${selector}" "${CHANGELOG}" && ! grep -qF "${sig}" "${CHANGELOG}"; then
                failures+=("${c}: selector/firma '${sig}' (${selector}) no declarado en CHANGELOG_ABIS.md")
            fi
        done <<< "${changed_sigs}"
    fi
    rm -f "${tmp}"
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
