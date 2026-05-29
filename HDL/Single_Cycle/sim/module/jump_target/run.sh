#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PROJECT_ROOT="../../../../.."
VECTOR_FILE_REL="${PROJECT_ROOT}/test_vectors/generated/jump_target/vectors.mem"
python3 "${PROJECT_ROOT}/tools/tv_gen/generate_all.py" --root "${PROJECT_ROOT}" --block jump_target
NUM_VECTORS=$(grep -v '^[[:space:]]*$' "${VECTOR_FILE_REL}" | wc -l)
echo "[jump_target] using ${NUM_VECTORS} vectors from ${VECTOR_FILE_REL}"
rm -rf xcelium.d wave.shm xrun_jump_target.log xrun_jump_target.history
xrun -64bit -access +rwc \
  -f run.f \
  -top tb_jump_target_generator \
  +VECTOR_FILE="${VECTOR_FILE_REL}" \
  +NUM_VECTORS="${NUM_VECTORS}" \
  -l xrun_jump_target.log
