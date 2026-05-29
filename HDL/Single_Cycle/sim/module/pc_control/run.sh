#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PROJECT_ROOT="../../../../.."
VECTOR_FILE_REL="${PROJECT_ROOT}/test_vectors/generated/pc_control/vectors.mem"

python3 "${PROJECT_ROOT}/tools/tv_gen/generate_all.py" --root "${PROJECT_ROOT}" --block pc_control
NUM_VECTORS=$(grep -v '^[[:space:]]*$' "${VECTOR_FILE_REL}" | wc -l)

echo "[pc_control] using ${NUM_VECTORS} vectors from ${VECTOR_FILE_REL}"
rm -rf xcelium.d wave.shm xrun_pc_control.log xrun_pc_control.history

xrun -64bit -access +rwc \
  -f run.f \
  -top tb_pc_control \
  +VECTOR_FILE="${VECTOR_FILE_REL}" \
  +NUM_VECTORS="${NUM_VECTORS}" \
  -l xrun_pc_control.log
