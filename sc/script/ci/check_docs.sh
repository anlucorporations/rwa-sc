#!/usr/bin/env bash
#
# RF-006 (Ciclo 10) — gate de documentación. Concreta los checks de CU-12
# `ci_check_RF006_refs_rotas_cero`, `ci_check_RF006_security_md_existe`,
# `ci_check_RF006_changelog_abis_existe` y `ci_check_RF006_hallazgos_cubiertos`.
#
# Falla (exit != 0) si:
#   (a) algún documento raíz referencia archivos/contratos que no existen
#       (H-15: Token.sol, Identity.sol, TOKEN_CLONE_FACTORY.md,
#        COMPLIANCE_AGGREGATOR_FINAL.md, COMPLIANCE_AGGREGATOR_V2.md y
#        DeployIdentityRegistry.s.sol);
#   (b) falta `SECURITY.md` o está vacío;
#   (c) falta `CHANGELOG_ABIS.md` o está vacío;
#   (d) aparece una afirmación prohibida sin matizar ("139 tests",
#       "production-ready", "ERC-3643 compliant");
#   (e) `SECURITY.md` no cubre los 12 hallazgos HB-01..HB-12;
#   (f) un documento contiene un marcador sin sustituir (TODO/FIXME/TBD).
#
# Alcance: los documentos "raíz" de `rwa-sc/` (los que publica el proyecto).
# `RepoTecnico/` queda fuera porque es el registro de auditoría y de requisitos,
# donde estas cadenas aparecen citadas como hallazgo histórico o como texto
# prohibido; ese uso está permitido por diseño.
#
# Uso: script/ci/check_docs.sh   (desde sc/, o con la ruta completa; el script
# localiza la raíz del repositorio por sí mismo).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "${REPO_ROOT}"

DOCS=(
    "README.md"
    "START_HERE.md"
    "ARQUITECTURA_FINAL.md"
    "GUIA_ESTUDIANTE.md"
    "EJERCICIOS_PRACTICOS.md"
    "REFERENCIA_TECNICA.md"
    "DEPENDENCIAS_CONTRATOS.md"
    "OPTIMIZACION_VERIFICACION.md"
    "VERIFICACION_TRUSTED_ISSUER.md"
    "CLAIM_TOPICS_REGISTRY_FACTORY.md"
    "SECURITY.md"
    "CHANGELOG_ABIS.md"
)

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

# --- (b) / (c) existencia de los artefactos obligatorios -----------------------
if [ ! -s "SECURITY.md" ]; then
    err "falta SECURITY.md (o está vacío)"
fi
if [ ! -s "CHANGELOG_ABIS.md" ]; then
    err "falta CHANGELOG_ABIS.md (o está vacío)"
fi

# Documentos existentes sobre los que se aplican (a), (d) y (f).
present_docs=()
for d in "${DOCS[@]}"; do
    [ -f "$d" ] && present_docs+=("$d")
done

# --- (a) referencias a archivos/contratos inexistentes (H-15) ------------------
REFS_RE='\bToken\.sol\b|\bIdentity\.sol\b|\bTOKEN_CLONE_FACTORY\.md\b|\bCOMPLIANCE_AGGREGATOR_FINAL\.md\b|\bCOMPLIANCE_AGGREGATOR_V2\.md\b|\bDeployIdentityRegistry\b'
if [ "${#present_docs[@]}" -gt 0 ]; then
    refs_hits="$(grep -HnE "${REFS_RE}" "${present_docs[@]}" || true)"
    if [ -n "${refs_hits}" ]; then
        err "referencias a archivos/contratos inexistentes (H-15):"
        printf '%s\n' "${refs_hits}" >&2
    fi
fi

# --- (d) afirmaciones prohibidas sin matizar -----------------------------------
CLAIMS_RE='139[[:space:]]+tests|production-ready|erc-3643[[:space:]]+compliant'
MATIZ_RE='no es|no somos|no está|no estan|no están|no product|retirad|prohibid|sin auditor|históric|historic|falso|no verificable|obsolet|nunca|evitar|no apto|sin respaldo|sin criterio'
if [ "${#present_docs[@]}" -gt 0 ]; then
    while IFS= read -r hit; do
        [ -z "${hit}" ] && continue
        if ! printf '%s' "${hit}" | grep -qiE "${MATIZ_RE}"; then
            err "afirmación prohibida sin matizar: ${hit}"
        fi
    done < <(grep -HniE "${CLAIMS_RE}" "${present_docs[@]}" || true)
fi

# --- (e) cobertura de hallazgos HB-01..HB-12 en SECURITY.md --------------------
if [ -s "SECURITY.md" ]; then
    for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
        if ! grep -qE "HB-${i}\b" "SECURITY.md"; then
            err "SECURITY.md no cubre HB-${i}"
        fi
    done
fi

# --- (f) marcadores sin sustituir ----------------------------------------------
PLACEHOLDER_RE='<pendiente>|<placeholder>|<TBD>|\bTBD\b|\[TODO\]|\[FIXME\]'
if [ "${#present_docs[@]}" -gt 0 ]; then
    ph_hits="$(grep -HnE "${PLACEHOLDER_RE}" "${present_docs[@]}" || true)"
    if [ -n "${ph_hits}" ]; then
        err "marcadores sin sustituir:"
        printf '%s\n' "${ph_hits}" >&2
    fi
fi

if [ "${fail}" -ne 0 ]; then
    echo "" >&2
    echo "FAIL: gate de documentación RF-006 (ver arriba)." >&2
    exit 1
fi

echo "OK: documentación RF-006 consistente (${#present_docs[@]} documentos; sin referencias rotas, sin afirmaciones sin matizar, SECURITY.md y CHANGELOG_ABIS.md presentes)."
