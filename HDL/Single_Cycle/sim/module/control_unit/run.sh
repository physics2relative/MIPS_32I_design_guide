#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PROJECT_ROOT="../../../../.."
VECTOR_FILE_REL="${PROJECT_ROOT}/test_vectors/generated/control_unit/vectors.mem"

python3 "${PROJECT_ROOT}/tools/tv_gen/generate_all.py" --root "${PROJECT_ROOT}" --block control_unit
NUM_VECTORS=$(grep -v '^[[:space:]]*$' "${VECTOR_FILE_REL}" | wc -l)

echo "[control_unit] using ${NUM_VECTORS} vectors from ${VECTOR_FILE_REL}"
rm -rf xcelium.d wave.shm xrun_control_unit.log xrun_control_unit.history

xrun -64bit -access +rwc \
  -f run.f \
  -top tb_control_unit \
  +VECTOR_FILE="${VECTOR_FILE_REL}" \
  +NUM_VECTORS="${NUM_VECTORS}" \
  -l xrun_control_unit.log
