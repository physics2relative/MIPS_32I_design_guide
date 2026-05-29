# Single Cycle MIPS CRT 실행 폴더

현재 Single Cycle DUT에 대해 `HDL/common/testbench/tb_MIPS_CRT_v3.v`를 실행하는 wrapper입니다.

## 빠른 실행

```bash
cd HDL/Single_Cycle/sim/crt
./run.sh
```

성공 기준:

```text
FINAL: 60 PASSED / 0 FAILED
>>> MIPS CRT v3 ALL TESTS PASSED <<<
```

## 재현 실행

```bash
SEED=1 N_INST=120 M_ITER=20 PHASE_START=1 PHASE_END=3 ./run.sh
```

주요 산출물:

- `xrun_mips_crt.log`: compile/elaboration/run 및 PASS/FAIL 로그
- `wave.shm/`: SimVision ACMTF waveform
- `xcelium.d/`: Xcelium work directory

자세한 generator/triage/coverage 설명은 `../../../common/testbench/README_MIPS_CRT_v3.md`를 참고합니다.
