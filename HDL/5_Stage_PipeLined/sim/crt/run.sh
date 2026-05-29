#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SEED="${SEED:-1}"
N_INST="${N_INST:-20}"
M_ITER="${M_ITER:-1}"
REG_POOL="${REG_POOL:-8}"
PHASE_START="${PHASE_START:-1}"
PHASE_END="${PHASE_END:-3}"
IMEM_WORDS="${IMEM_WORDS:-4096}"
DMEM_BYTES="${DMEM_BYTES:-256}"
DUT_DRAIN_CYCLES="${DUT_DRAIN_CYCLES:-8}"
MAX_WAIT_CYCLES="${MAX_WAIT_CYCLES:-1000000}"
GLOBAL_TIMEOUT_CYCLES="${GLOBAL_TIMEOUT_CYCLES:-0}"
ENABLE_WAVE="${ENABLE_WAVE:-0}"

WAVE_DEFINE="+define+MIPS_CRT_NO_WAVE"
if [[ "$ENABLE_WAVE" == "1" || "$ENABLE_WAVE" == "true" || "$ENABLE_WAVE" == "yes" ]]; then
  WAVE_DEFINE=""
fi

printf '[mips_pipeline_crt] seed=%s n_inst=%s m_iter=%s reg_pool=%s phase=%s..%s wave=%s\n' \
  "$SEED" "$N_INST" "$M_ITER" "$REG_POOL" "$PHASE_START" "$PHASE_END" "$ENABLE_WAVE"
printf '[mips_pipeline_crt] imem_words=%s dmem_bytes=%s drain=%s max_wait=%s global_timeout=%s\n' \
  "$IMEM_WORDS" "$DMEM_BYTES" "$DUT_DRAIN_CYCLES" "$MAX_WAIT_CYCLES" "$GLOBAL_TIMEOUT_CYCLES"

rm -rf xcelium.d wave.shm xrun_mips_pipeline_crt.log xrun_mips_pipeline_crt.history xrun.history xrun.key xrun.log

xrun -64bit -access +rwc \
  ${WAVE_DEFINE} \
  -f run.f \
  -top tb_MIPS_CRT_v3 \
  -defparam tb_MIPS_CRT_v3.SEED="${SEED}" \
  -defparam tb_MIPS_CRT_v3.N_INST="${N_INST}" \
  -defparam tb_MIPS_CRT_v3.M_ITER="${M_ITER}" \
  -defparam tb_MIPS_CRT_v3.REG_POOL="${REG_POOL}" \
  -defparam tb_MIPS_CRT_v3.PHASE_START="${PHASE_START}" \
  -defparam tb_MIPS_CRT_v3.PHASE_END="${PHASE_END}" \
  -defparam tb_MIPS_CRT_v3.IMEM_WORDS="${IMEM_WORDS}" \
  -defparam tb_MIPS_CRT_v3.DMEM_BYTES="${DMEM_BYTES}" \
  -defparam tb_MIPS_CRT_v3.DUT_DRAIN_CYCLES="${DUT_DRAIN_CYCLES}" \
  -defparam tb_MIPS_CRT_v3.MAX_WAIT_CYCLES="${MAX_WAIT_CYCLES}" \
  -defparam tb_MIPS_CRT_v3.GLOBAL_TIMEOUT_CYCLES="${GLOBAL_TIMEOUT_CYCLES}" \
  -l xrun_mips_pipeline_crt.log

if ! grep -q "MIPS CRT v3 ALL TESTS PASSED" xrun_mips_pipeline_crt.log; then
  echo "[mips_pipeline_crt] FAIL marker detected or PASS marker missing; see $(pwd)/xrun_mips_pipeline_crt.log" >&2
  exit 1
fi
