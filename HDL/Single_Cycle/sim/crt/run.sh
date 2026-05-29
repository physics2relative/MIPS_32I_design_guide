#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SEED="${SEED:-1}"
N_INST="${N_INST:-120}"
M_ITER="${M_ITER:-20}"
REG_POOL="${REG_POOL:-8}"
PHASE_START="${PHASE_START:-1}"
PHASE_END="${PHASE_END:-3}"
IMEM_WORDS="${IMEM_WORDS:-512}"
DMEM_BYTES="${DMEM_BYTES:-256}"
DUT_DRAIN_CYCLES="${DUT_DRAIN_CYCLES:-4}"
MAX_WAIT_CYCLES="${MAX_WAIT_CYCLES:-200000}"

echo "[mips_crt] seed=${SEED} n_inst=${N_INST} m_iter=${M_ITER} reg_pool=${REG_POOL} phase=${PHASE_START}..${PHASE_END}"
echo "[mips_crt] imem_words=${IMEM_WORDS} dmem_bytes=${DMEM_BYTES} drain=${DUT_DRAIN_CYCLES} max_wait=${MAX_WAIT_CYCLES}"

rm -rf xcelium.d wave.shm xrun_mips_crt.log xrun_mips_crt.history xrun.history xrun.key xrun.log

xrun -64bit -access +rwc \
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
  -l xrun_mips_crt.log

if ! grep -q "MIPS CRT v3 ALL TESTS PASSED" xrun_mips_crt.log; then
  echo "[mips_crt] FAIL marker detected or PASS marker missing; see $(pwd)/xrun_mips_crt.log" >&2
  exit 1
fi
