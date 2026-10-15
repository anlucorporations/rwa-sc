#!/usr/bin/env bash
#
# RNF-107 (H-09) — gate de análisis estático con Slither.
# Concreta el check `ci_check_RNF107_slither_sin_high`.
#
# Ejecuta Slither sobre `src/` (framework Foundry, toolchain fijado) y falla si aparece algún
# hallazgo con impacto >= SLITHER_MAX_IMPACT (por defecto `medium`; la política mínima de RNF-107 es
# "sin High"). Los hallazgos de dependencias (`lib/`), tests y scripts se filtran por
# `slither.config.json`.
#
# Sin Slither disponible el gate hace SKIP (exit 0) con aviso: en el pipeline hay un job dedicado
# (`slither`) con Python que lo instala, de modo que allí sí es obligatorio; en un runner sin Python
# no se puede evaluar y no debe romper el resto del pipeline.
#
# Uso:
#   script/ci/check_slither.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${SC_ROOT}"

MAX_IMPACT="${SLITHER_MAX_IMPACT:-medium}"

SLITHER="$(command -v slither 2>/dev/null || true)"
if [ -z "${SLITHER}" ] && [ -x "${HOME}/.local/bin/slither" ]; then
    SLITHER="${HOME}/.local/bin/slither"
fi
if [ -z "${SLITHER}" ]; then
    echo "SKIP: 'slither' no está disponible; el análisis estático se ejecuta en el job 'slither' del pipeline."
    exit 0
fi

if ! command -v forge >/dev/null 2>&1; then
    export PATH="${HOME}/.foundry/bin:${PATH}"
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: 'python3' no está disponible para interpretar el informe de Slither."
    exit 0
fi

REPORT_DIR="$(mktemp -d)"
REPORT="${REPORT_DIR}/slither.json"
trap 'rm -rf "${REPORT_DIR}"' EXIT

echo "Slither ${MAX_IMPACT}+ sobre src/ (config: sc/slither.config.json)..."
# Slither devuelve exit != 0 cuando hay hallazgos; el veredicto lo da el parser del JSON.
"${SLITHER}" . \
    --compile-force-framework foundry \
    --config-file slither.config.json \
    --json "${REPORT}" >/dev/null 2>&1 || true

if [ ! -s "${REPORT}" ]; then
    echo "FAIL: Slither no ha generado informe (revisa que 'forge build' funcione)." >&2
    exit 1
fi

python3 - "${REPORT}" "${MAX_IMPACT}" <<'PY'
import json, sys, collections

report_path, max_impact = sys.argv[1], sys.argv[2].lower()
order = {"informational": 0, "optimization": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}
limit = order.get(max_impact, 2)

try:
    data = json.load(open(report_path))
except json.JSONDecodeError as exc:
    print(f"FAIL: informe de Slither ilegible: {exc}", file=sys.stderr)
    sys.exit(1)

detectors = data.get("results", {}).get("detectors", [])


def in_src(finding):
    for element in finding.get("elements", []):
        path = element.get("source_mapping", {}).get("filename_relative", "")
        if path.startswith("src/"):
            return True
    return False


src = [f for f in detectors if in_src(f)]
counts = collections.Counter((f.get("impact") or "Informational").lower() for f in src)
violations = [f for f in src if order.get((f.get("impact") or "").lower(), 0) >= limit and limit > 0]

print("Hallazgos Slither en src/ por impacto: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))

if violations:
    print(f"FAIL: {len(violations)} hallazgo(s) con impacto >= {max_impact}:", file=sys.stderr)
    for f in violations:
        print(f"  - [{f.get('impact')}] {f.get('check')}: {f.get('description','')[:160]}", file=sys.stderr)
    sys.exit(1)

print(f"OK: Slither sin hallazgos de impacto >= {max_impact} en src/.")
PY
