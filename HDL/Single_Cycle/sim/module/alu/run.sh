#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PROJECT_ROOT="../../../../.."
VECTOR_FILE_REL="${PROJECT_ROOT}/test_vectors/generated/alu/vectors.mem"

python3 "${PROJECT_ROOT}/tools/tv_gen/generate_all.py" --root "${PROJECT_ROOT}" --block alu
NUM_VECTORS=$(grep -v '^[[:space:]]*$' "${VECTOR_FILE_REL}" | wc -l)

echo "[alu] using ${NUM_VECTORS} vectors from ${VECTOR_FILE_REL}"
rm -rf xcelium.d wave.shm xrun_alu.log xrun_alu.history

xrun -64bit -access +rwc \
  -f run.f \
  -top tb_ALU \
  +VECTOR_FILE="${VECTOR_FILE_REL}" \
  +NUM_VECTORS="${NUM_VECTORS}" \
  -l xrun_alu.log
