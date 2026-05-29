#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Path 기준:
#   cwd = HDL/Single_Cycle/sim/top/smoke
#   project root = ../../../../..
PROJECT_ROOT="../../../../.."
TV_DIR_REL="${PROJECT_ROOT}/test_vectors/generated/top_smoke"
PROGRAM_FILE_REL="${TV_DIR_REL}/program.hex"
CHECK_FILE_REL="${TV_DIR_REL}/checks.mem"
RUN_CYCLES_FILE_REL="${TV_DIR_REL}/run_cycles.txt"

python3 "${PROJECT_ROOT}/tools/testvector_generators/generate_top_smoke.py" \
  --root "${PROJECT_ROOT}"

NUM_CHECKS="$(grep -cve '^[[:space:]]*$' "${CHECK_FILE_REL}")"
RUN_CYCLES="$(tr -d '[:space:]' < "${RUN_CYCLES_FILE_REL}")"
TRACE="${TRACE:-0}"

echo "[top_smoke] program=${PROGRAM_FILE_REL} checks=${CHECK_FILE_REL} run_cycles=${RUN_CYCLES} num_checks=${NUM_CHECKS} trace=${TRACE}"

rm -rf xcelium.d wave.shm xrun_top_smoke.log xrun_top_smoke.history

xrun -64bit -access +rwc \
  -f run.f \
  -top tb_mips_single_cycle_top_smoke \
  +PROGRAM_FILE="${PROGRAM_FILE_REL}" \
  +CHECK_FILE="${CHECK_FILE_REL}" \
  +RUN_CYCLES="${RUN_CYCLES}" \
  +NUM_CHECKS="${NUM_CHECKS}" \
  +TRACE="${TRACE}" \
  -l xrun_top_smoke.log
