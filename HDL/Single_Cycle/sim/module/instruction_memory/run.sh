#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
rm -rf xcelium.d wave.shm xrun_instruction_memory.log xrun_instruction_memory.history
xrun -64bit -access +rwc \
  -f run.f \
  -top tb_instruction_memory \
  -l xrun_instruction_memory.log
