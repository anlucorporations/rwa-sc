#!/usr/bin/env bash
#
# RF-009 (Ciclo 11) — simulación local del pipeline de GitLab.
#
# Ejecuta, en el MISMO orden que los jobs de `.gitlab-ci.yml`, exactamente los
# mismos comandos (validate -> build -> fmt -> test -> coverage+gate -> gas ->
# ci-checks) y devuelve exit 0 solo si todas las etapas pasan. Es el ensayo del
# pipeline que aún no puede correr en remoto (no hay `push`, ver README.md).
#
# Uso:
#   sc/script/ci/run_local_ci.sh
#   CI_KEEP_GOING=1 sc/script/ci/run_local_ci.sh   # no parar en la primera etapa que falle
#
# Artefactos locales (mismos ficheros que publica el pipeline como artifacts):
#   sc/ci-artifacts/test-count.txt        conteo real de tests + resumen de la ejecución
#   sc/ci-artifacts/test-run.log          salida completa de `forge test`
#   sc/ci-artifacts/coverage-summary.txt  salida de `forge coverage --report summary`
#   sc/lcov.info                          reporte lcov
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${SC_ROOT}/.." && pwd)"
ARTIFACTS="${SC_ROOT}/ci-artifacts"
KEEP_GOING="${CI_KEEP_GOING:-0}"

export PATH="${HOME}/.foundry/bin:${PATH}"
export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-default}"
export COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
export COVERAGE_CONTRACT_THRESHOLD="${COVERAGE_CONTRACT_THRESHOLD:-${COVERAGE_THRESHOLD}}"

mkdir -p "${ARTIFACTS}"

stage_names=()
stage_status=()
failed=0

record() {
    stage_names+=("$1")
    stage_status+=("$2")
    [ "$2" = "OK" ] || failed=1
}

run_stage() {
    local name="$1"
    shift
    echo ""
    echo "=============================================================="
    echo "== STAGE: ${name}"
    echo "=============================================================="
    if "$@"; then
        echo "-- ${name}: OK"
        record "${name}" "OK"
    else
        local rc=$?
        echo "-- ${name}: FALLO (exit ${rc})" >&2
        record "${name}" "FALLO"
        if [ "${KEEP_GOING}" != "1" ]; then
            echo "" >&2
            echo "Etapa '${name}' fallida; se detiene la simulación (exit ${rc})." >&2
            print_summary
            exit "${rc}"
        fi
    fi
}

print_summary() {
    echo ""
    echo "===================== RESUMEN CI LOCAL ====================="
    local i
    for i in "${!stage_names[@]}"; do
        printf '  %-14s %s\n' "${stage_names[$i]}" "${stage_status[$i]}"
    done
    echo "==========================================================="
}

# --- validate: submódulos pinneados (B-5 / ci_check_RF005_submodulos_pinneados)
stage_validate() {
    cd "${REPO_ROOT}"
    git submodule update --init --recursive
    echo "-- git submodule status --"
    git submodule status
    local bad
    bad="$(git submodule status | grep -E '^[-+]' || true)"
    if [ -n "${bad}" ]; then
        echo "FAIL: submódulos sin inicializar (-) o desalineados (+):" >&2
        printf '%s\n' "${bad}" >&2
        return 1
    fi
    local declared
    declared="$(grep -cE '^[[:space:]]*path = sc/lib/' .gitmodules || true)"
    if [ "${declared}" -ne 3 ]; then
        echo "FAIL: .gitmodules declara ${declared} submódulos en sc/lib/ (se esperan 3)" >&2
        return 1
    fi
    echo "OK: 3 submódulos declarados y pinneados, sin prefijos -/+"
}

# --- build -------------------------------------------------------------------
stage_build() {
    cd "${SC_ROOT}"
    forge build
}

# --- fmt ---------------------------------------------------------------------
stage_fmt() {
    cd "${SC_ROOT}"
    forge fmt --check
}

# --- test: gate RNF-003 + conteo real como artefacto -------------------------
stage_test() {
    cd "${SC_ROOT}"
    local log="${ARTIFACTS}/test-run.log"
    forge test 2>&1 | tee "${log}" | tail -n 6
    local rc="${PIPESTATUS[0]}"
    if [ "${rc}" -ne 0 ]; then
        return "${rc}"
    fi
    local count
    count="$(forge test --list | grep -cE '^    test')"
    local invariant_count
    invariant_count="$(forge test --list | grep -cE '^    invariant_')"
    {
        echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "commit=$(git -C "${REPO_ROOT}" rev-parse HEAD)"
        echo "branch=$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
        echo "tests_listed=${count}"
        echo "invariant_functions_listed=${invariant_count}"
        grep -E 'Suite result|tests passed' "${log}" | tail -n 3
    } > "${ARTIFACTS}/test-count.txt"
    echo "-- artefacto ${ARTIFACTS}/test-count.txt --"
    cat "${ARTIFACTS}/test-count.txt"
    return 0
}

# --- coverage: gate RNF-002/D-042 + lcov -------------------------------------
# La cobertura de `src/` la determinan las suites unitarias (97,12 % estable); los invariantes
# solo anaden coste de instrumentacion. Se ejecutan con el presupuesto minimo (1 run x 1 call)
# para que la etapa siga acotada: 204 s -> 65 s medidos en local, con el mismo 97,12 % de `src/`.
stage_coverage() {
    cd "${SC_ROOT}"
    local summary="${ARTIFACTS}/coverage-summary.txt"
    FOUNDRY_INVARIANT_RUNS=1 FOUNDRY_INVARIANT_DEPTH=1 \
        forge coverage --report summary --report lcov 2>&1 | tee "${summary}" | tail -n 6
    local rc="${PIPESTATUS[0]}"
    if [ "${rc}" -ne 0 ]; then
        return "${rc}"
    fi
    [ -s "${SC_ROOT}/lcov.info" ] || { echo "FAIL: no se ha generado lcov.info" >&2; return 1; }
    echo "-- gate de cobertura (COVERAGE_THRESHOLD=${COVERAGE_THRESHOLD}, CONTRACT=${COVERAGE_CONTRACT_THRESHOLD}) --"
    "${SCRIPT_DIR}/check_coverage.sh" "${summary}"
}

# --- gas: gate RNF-001 / D-039 -----------------------------------------------
stage_gas() {
    cd "${SC_ROOT}"
    forge snapshot --check --tolerance 5
}

# --- ci-checks: RF-002 / RF-006 ----------------------------------------------
stage_ci_checks() {
    cd "${SC_ROOT}"
    "${SCRIPT_DIR}/check_no_bypass_flag.sh"
    "${SCRIPT_DIR}/check_docs.sh"
    "${SCRIPT_DIR}/abi_diff.sh"
}

run_stage "validate" stage_validate
run_stage "build" stage_build
run_stage "fmt" stage_fmt
run_stage "test" stage_test
run_stage "coverage" stage_coverage
run_stage "gas" stage_gas
run_stage "ci-checks" stage_ci_checks

print_summary

if [ "${failed}" -ne 0 ]; then
    echo "RESULTADO: FALLO" >&2
    exit 1
fi
echo "RESULTADO: OK (pipeline local en verde)"
exit 0
