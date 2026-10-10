#!/usr/bin/env bash
#
# RF-010 (Ciclo 9) — gate de CI de gestion de secretos. Materializa el criterio
# Gherkin de CU-13 `ci_check_RF010_secret_scan_sin_hallazgos` y refuerza el resto de
# criterios estaticos de RF-010:
#
#   * `ci_check_RF010_secret_scan_sin_hallazgos` — ningun secreto en el arbol versionado.
#   * `ci_check_RF010_script_sin_keys_json`       — ningun script lee `keys.json`.
#   * `ci_check_RF010_script_usa_env`             — `deploy.sh` toma la clave de una variable
#                                                   de entorno / Secret Manager, no de disco.
#   * `ci_check_RF010_env_en_gitignore`           — `.env` y `.env.*` ignorados por git.
#
# Que considera "secreto":
#   (1) claves privadas de 64 hex (`0x` + 64) en scripts/configuracion versionados;
#   (2) asignaciones de `private_key`/`mnemonic`/`secret` con un valor de 64 hex en cualquier
#       archivo versionado;
#   (3) tokens de proveedor (`glpat-`, `ghp_`, `AKIA...`);
#   (4) uso de `keys.json` o de `--private-key` en scripts.
#
# Sitios permitidos (no escaneados para (1)): dependencias de terceros `sc/lib/**`, salidas
# de build (`sc/out/`, `sc/cache/`, `sc/broadcast/`, `sc/ci-artifacts/`), manifest de ABIs
# (`sc/abis/**`) y registros de despliegue (`sc/deployments/**`), que contienen hashes de 32
# bytes legitimos. La documentacion (`*.md`, `RepoTecnico/**`) se excluye de (1) porque cita
# hashes/topic0 como evidencia de auditoria.
#
# Uso:
#   script/ci/check_secrets.sh              # escanea la raiz del repositorio
#   script/ci/check_secrets.sh <ruta>       # escanea <ruta> (para la demostracion negativa)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_ROOT="$(cd "${SC_ROOT}/.." && pwd)"
ROOT="${1:-${DEFAULT_ROOT}}"
ROOT="$(cd "${ROOT}" && pwd)"

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

# --- lista de archivos "versionados" -----------------------------------------
if git -C "${ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
    mapfile -t FILES < <(git -C "${ROOT}" ls-files)
else
    mapfile -t FILES < <(cd "${ROOT}" && find . -type f -not -path './.git/*' | sed 's|^\./||')
fi

# Rutas no escaneadas para (1): dependencias/salidas/ABIs/registros y documentacion.
EXCLUDE_RE='^(sc/lib/|node_modules/|sc/out/|sc/cache/|sc/broadcast/|sc/ci-artifacts/|sc/abis/|sc/deployments/|\.git/)'
DOC_RE='\.(md|txt|rst)$|^RepoTecnico/'
# Scripts y configuracion: donde se exige (1) y (4).
SCRIPT_RE='\.(sh|bash|zsh|yml|yaml|env|toml|ini|cfg|conf|py|js|ts|mjs|cjs)$|(^|/)\.env($|\.)'

script_files=()
all_files=()
for f in "${FILES[@]}"; do
    [[ "${f}" =~ ${EXCLUDE_RE} ]] && continue
    [[ -f "${ROOT}/${f}" ]] || continue
    all_files+=("${f}")
    if [[ "${f}" =~ ${SCRIPT_RE} ]]; then
        # Un gate que DOCUMENTA los patrones prohibidos no debe escanearse a si mismo:
        # sus comentarios citan `keys.json` y `--private-key` y generaban un falso
        # positivo (detectado por el Lead al re-verificar el gate).
        [[ "${f}" == "sc/script/ci/check_secrets.sh" ]] && continue
        script_files+=("${f}")
    fi
done

# --- (1) claves privadas crudas en scripts/configuracion ---------------------
if [ "${#script_files[@]}" -gt 0 ]; then
    raw_hits="$(grep -HnIE '0x[0-9a-fA-F]{64}' "${script_files[@]/#/${ROOT}/}" 2>/dev/null || true)"
    if [ -n "${raw_hits}" ]; then
        err "clave privada (0x + 64 hex) en script/configuracion versionado:"
        printf '%s\n' "${raw_hits}" >&2
    fi
fi

# --- (2) asignaciones de secreto con valor de 64 hex -------------------------
SECRET_ASSIGN_RE='(private[_-]?key|priv[_-]?key|secret[_-]?key|mnemonic|seed[_-]?phrase)[[:space:]]*[:=][[:space:]]*["'\'']?0x[0-9a-fA-F]{64}'
if [ "${#all_files[@]}" -gt 0 ]; then
    assign_hits="$(grep -HnIiE "${SECRET_ASSIGN_RE}" "${all_files[@]/#/${ROOT}/}" 2>/dev/null || true)"
    if [ -n "${assign_hits}" ]; then
        err "asignacion de secreto con valor de 64 hex:"
        printf '%s\n' "${assign_hits}" >&2
    fi
fi

# --- (3) tokens de proveedor -------------------------------------------------
if [ "${#all_files[@]}" -gt 0 ]; then
    token_hits="$(grep -HnIE 'glpat-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}' \
        "${all_files[@]/#/${ROOT}/}" 2>/dev/null || true)"
    if [ -n "${token_hits}" ]; then
        err "token de proveedor en archivo versionado:"
        printf '%s\n' "${token_hits}" >&2
    fi
fi

# --- (4) keys.json / --private-key en scripts --------------------------------
if [ "${#script_files[@]}" -gt 0 ]; then
    keys_hits="$(grep -HnIE 'keys\.json' "${script_files[@]/#/${ROOT}/}" 2>/dev/null || true)"
    if [ -n "${keys_hits}" ]; then
        err "un script lee 'keys.json' (prohibido por RF-010):"
        printf '%s\n' "${keys_hits}" >&2
    fi

    pk_hits="$(grep -HnIE -- '--private-key' "${script_files[@]/#/${ROOT}/}" 2>/dev/null || true)"
    if [ -n "${pk_hits}" ]; then
        err "un script usa '--private-key' en argv (prohibido por RF-010):"
        printf '%s\n' "${pk_hits}" >&2
    fi
fi

# --- (5) .env ignorado por git ----------------------------------------------
if [ -f "${ROOT}/.gitignore" ]; then
    if ! grep -qE '(^|/)\.env[[:space:]]*$' "${ROOT}/.gitignore"; then
        err ".gitignore no ignora '.env'"
    fi
    if ! grep -qE '(^|/)\.env\.' "${ROOT}/.gitignore"; then
        err ".gitignore no ignora '.env.*'"
    fi
else
    err "falta .gitignore en la raiz"
fi

# --- (6) deploy.sh toma la clave del entorno / Secret Manager ---------------
DEPLOY="${ROOT}/sc/script/deploy.sh"
if [ -f "${DEPLOY}" ]; then
    grep -qE 'PRIVATE_KEY' "${DEPLOY}" || err "deploy.sh no referencia ninguna variable de entorno con la clave"
    grep -qE 'gcloud secrets versions access' "${DEPLOY}" || err "deploy.sh no soporta GCP Secret Manager"
    grep -qE 'trap cleanup' "${DEPLOY}" || err "deploy.sh no limpia el keystore temporal con 'trap cleanup'"
    grep -qE -- '--keystore' "${DEPLOY}" || err "deploy.sh no firma con keystore temporal"
fi

if [ "${fail}" -ne 0 ]; then
    echo "" >&2
    echo "FAIL: gate de secretos RF-010 (ver arriba)." >&2
    exit 1
fi

echo "OK: RF-010 sin secretos — ${#all_files[@]} archivos versionados escaneados (${#script_files[@]} scripts/config), sin claves de 64 hex, sin tokens de proveedor, sin 'keys.json' ni '--private-key', '.env' ignorado."
