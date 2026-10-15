#!/usr/bin/env bash
#
# H-13 (M-8) — gate del catálogo canónico de claim topics.
# Concreta el check de CU-12 `ci_check_H13_catalogo_topics_unico`.
#
# El catálogo de claim topics era divergente entre documentos (H-13): cada `.md` publicaba
# una numeración distinta (2=AML, 9=Sanctions Check...). Este gate fija UNA fuente de verdad
# —el seed de `rwa.claim_topics` en `RepoTecnico/base_datos.sql`— y falla si:
#   1. La tabla §3.1 de `RepoTecnico/diccionario_datos.md` no declara cada topic activo del seed.
#   2. Los documentos raíz `ARQUITECTURA_FINAL.md` o `REFERENCIA_TECNICA.md` reintroducen un
#      catálogo antiguo divergente (2=AML, 9=Sanctions Check, ...).
#   3. Esos dos documentos no apuntan al catálogo canónico.
#
# Sin dependencias externas (solo grep/sed/awk). Uso:
#   script/ci/check_claim_topics.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"

SQL="${REPO_ROOT}/RepoTecnico/base_datos.sql"
DICC="${REPO_ROOT}/RepoTecnico/diccionario_datos.md"
DOCS=("${REPO_ROOT}/ARQUITECTURA_FINAL.md" "${REPO_ROOT}/REFERENCIA_TECNICA.md")

for f in "${SQL}" "${DICC}" "${DOCS[@]}"; do
    if [ ! -f "${f}" ]; then
        echo "FAIL: falta ${f}" >&2
        exit 2
    fi
done

fail=0

# --- 1. Topics activos del seed canónico -------------------------------------
mapfile -t seed_rows < <(
    sed -n '/INSERT INTO rwa.claim_topics/,/ON CONFLICT (id) DO UPDATE/p' "${SQL}" \
        | grep -E "^\s*\([0-9]+, '[A-Z_]+'," \
        | grep -E "\btrue\b"
)

if [ "${#seed_rows[@]}" -eq 0 ]; then
    echo "FAIL: no se han podido extraer topics activos del seed de rwa.claim_topics" >&2
    exit 2
fi

echo "Catálogo canónico (seed rwa.claim_topics) — ${#seed_rows[@]} topics activos:"
for row in "${seed_rows[@]}"; do
    id="$(printf '%s' "${row}" | sed -E "s/^\s*\(([0-9]+),.*/\1/")"
    code="$(printf '%s' "${row}" | sed -E "s/^\s*\([0-9]+, '([A-Z_]+)'.*/\1/")"

    echo "  - ${id} = ${code}"

    if ! grep -iqE "^\| *${id} *\| *${code}[[:space:]]*\|" "${DICC}"; then
        echo "FAIL: el diccionario no declara '${id} = ${code}' en su tabla §3.1" >&2
        fail=1
    fi
done

# --- 2. Documentos raíz sin catálogos antiguos --------------------------------
FORBIDDEN=(
    '2[[:space:]]*=[[:space:]]*AML'
    '3[[:space:]]*=[[:space:]]*Accredited Investor'
    '9[[:space:]]*=[[:space:]]*Sanctions'
    '\[1, 2, 3, 4\]'
)
for doc in "${DOCS[@]}"; do
    for re in "${FORBIDDEN[@]}"; do
        if grep -qE "${re}" "${doc}"; then
            echo "FAIL: $(basename "${doc}") reintroduce un catálogo de topics divergente (patrón '${re}')" >&2
            fail=1
        fi
    done
    if ! grep -qi "catálogo canónico" "${doc}"; then
        echo "FAIL: $(basename "${doc}") no apunta al catálogo canónico de claim topics" >&2
        fail=1
    fi
done

if [ "${fail}" -ne 0 ]; then
    echo "" >&2
    echo "FAIL: catálogo de claim topics divergente (H-13 / M-8). Fuente única:" >&2
    echo "      RepoTecnico/base_datos.sql (seed rwa.claim_topics) + RepoTecnico/diccionario_datos.md §3" >&2
    exit 1
fi

echo "OK: catálogo de claim topics único y alineado (seed SQL ↔ diccionario ↔ documentos raíz)."
