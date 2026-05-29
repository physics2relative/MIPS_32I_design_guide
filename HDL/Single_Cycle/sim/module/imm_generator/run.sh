#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PROJECT_ROOT="../../../../.."
VECTOR_FILE_REL="${PROJECT_ROOT}/test_vectors/generated/imm_generator/vectors.mem"

python3 "${PROJECT_ROOT}/tools/tv_gen/generate_all.py" --root "${PROJECT_ROOT}" --block imm_generator
NUM_VECTORS=$(grep -v '^[[:space:]]*$' "${VECTOR_FILE_REL}" | wc -l)

echo "[imm_generator] using ${NUM_VECTORS} vectors from ${VECTOR_FILE_REL}"
rm -rf xcelium.d wave.shm xrun_imm_generator.log xrun_imm_generator.history

xrun -64bit -access +rwc \
  -f run.f \
  -top tb_immediate_generator \
  +VECTOR_FILE="${VECTOR_FILE_REL}" \
  +NUM_VECTORS="${NUM_VECTORS}" \
  -l xrun_imm_generator.log
