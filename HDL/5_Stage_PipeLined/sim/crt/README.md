# MIPS Pipeline CRTv3 실행 가이드

이 디렉터리는 `HDL/common/testbench/tb_MIPS_CRT_v3.v` **하나의 공통 테스트벤치**를 Pipeline DUT로 실행하기 위한 xrun 설정입니다.

## 구조

- 공통 TB: `HDL/common/testbench/tb_MIPS_CRT_v3.v`
- 공통 Golden model: `HDL/common/testbench/MIPS_Golden.v`
- DUT 선택: `run.f`의 `+define+MIPS_CRT_DUT_PIPELINE`
- DUT adapter: `HDL/common/testbench/mips_crt_adapter.vh`

Single Cycle과 Pipeline은 테스트 시나리오/golden model/TB 본체를 공유하고, run file의 define과 RTL filelist만 다르게 둡니다.

## 실행

```bash
cd HDL/5_Stage_PipeLined/sim/crt
./run.sh
```

기본값은 빠른 smoke용이며 phase 1..3을 모두 실행합니다.

```bash
SEED=1 N_INST=20 M_ITER=1 PHASE_START=1 PHASE_END=3 ./run.sh
```

확장 실행 예시는 다음과 같습니다.

```bash
SEED=1 N_INST=1000 M_ITER=1000 PHASE_START=1 PHASE_END=3 MAX_WAIT_CYCLES=1000000 ./run.sh
```

## Pipeline retire 계약

Pipeline은 single-cycle처럼 현재 PC를 halt 기준으로 보면 안 됩니다. CRT는 아래 WB retire 신호 기준으로 halt를 판정합니다.

```verilog
uut.dbg_wb_valid
uut.dbg_wb_pc
uut.dbg_wb_inst
uut.dbg_wb_reg_wen
uut.dbg_wb_write_reg
uut.dbg_wb_wdata
```

상태 비교는 최종 architectural state 기준입니다.

```verilog
uut.u_imem.u_bram.mem[index]
uut.u_dmem.u_bram.mem[index]
uut.u_regfile.regs[index]
```

## 주의

- Pipeline IMEM은 sync BRAM이므로 `mips_pipeline_top`에서 `IMEM_AW(12)`로 넉넉하게 잡습니다.
- 첫 검증은 smoke부터 시작하고, branch/jump 포함 phase 확장은 mismatch를 확인하면서 진행합니다.
- CRT는 cycle-by-cycle 비교가 아니라 최종 register/data memory 비교입니다.

대규모 regression에서는 기본적으로 waveform을 끕니다. 파형이 필요하면 `ENABLE_WAVE=1 ./run.sh`로 실행합니다.
