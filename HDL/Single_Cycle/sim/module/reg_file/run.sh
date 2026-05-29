#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Path 기준:
#   cwd = HDL/Single_Cycle/sim/module/reg_file
#   project root = ../../../../..
PROJECT_ROOT="../../../../.."
VECTOR_FILE_REL="${PROJECT_ROOT}/test_vectors/generated/register_file/vectors.mem"

# 기존 Logisim용 test_vectors/generated/register_file/*.hex는 그대로 두고,
# HDL testbench가 읽을 packed mem만 같은 위치에 추가/갱신합니다.
python3 "${PROJECT_ROOT}/tools/tv_gen/generate_all.py" \
  --root "${PROJECT_ROOT}" \
  --block register_file

NUM_VECTORS="$(grep -cve '^[[:space:]]*$' "${VECTOR_FILE_REL}")"
echo "[register_file] using ${NUM_VECTORS} vectors from ${VECTOR_FILE_REL}"

# 시뮬레이션 잔여물은 이 module/reg_file 폴더 안에만 정리합니다.
rm -rf xcelium.d wave.shm xrun_register_file.log xrun_register_file.history

xrun -64bit -access +rwc \
  -f run.f \
  -top tb_register_file \
  +VECTOR_FILE="${VECTOR_FILE_REL}" \
  +NUM_VECTORS="${NUM_VECTORS}" \
  -l xrun_register_file.log
