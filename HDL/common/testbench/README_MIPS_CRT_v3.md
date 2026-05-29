# MIPS CRTv3 공용 검증 가이드

이 디렉터리는 MIPS Single Cycle RTL과 향후 5-stage Pipeline RTL이 같은 golden/testbench 철학으로 검증되도록 만든 공용 CRT(Constrained Random Test) 계층입니다. DUT별 hierarchy 차이는 `mips_crt_adapter.vh`에 가두고, 실제 검증 로직은 `MIPS_Golden.v`와 `tb_MIPS_CRT_v3.v`가 공유합니다.

## 구성 파일

| 파일 | 역할 |
| --- | --- |
| `mips_crt_adapter.vh` | Single Cycle / future Pipeline hierarchy adapter macro |
| `MIPS_Golden.v` | MIPS subset behavioral golden model |
| `tb_MIPS_CRT_v3.v` | directed prelude + constrained random generator + 최종 state compare testbench |
| `HDL/Single_Cycle/sim/crt/run.sh` | 현재 실행 가능한 Single Cycle CRT wrapper |
| `HDL/5_Stage_PipeLined/sim/crt/README.md` | 향후 Pipeline CRT 연결 계약 |

## 실행 방법

현재 runnable 대상은 Single Cycle입니다.

```bash
cd HDL/Single_Cycle/sim/crt
./run.sh
```

대표 성공 로그는 다음 형태입니다.

```text
FINAL: 60 PASSED / 0 FAILED
>>> MIPS CRT v3 ALL TESTS PASSED <<<
```

`run.sh`는 이 PASS marker가 없으면 실패 exit code를 반환합니다. 실패 시 `xrun_mips_crt.log`와 `wave.shm`을 확인합니다.

## 파라미터와 seed 재현

`run.sh`는 환경변수로 testbench parameter를 override합니다.

| 환경변수 | 기본값 | 의미 |
| --- | ---: | --- |
| `SEED` | `1` | `$random(seed)` 초기 seed |
| `N_INST` | `120` | iteration별 random instruction 생성 목표 수 |
| `M_ITER` | `20` | phase별 반복 횟수 |
| `REG_POOL` | `8` | random generator가 주로 사용하는 nonzero register 범위 |
| `PHASE_START` | `1` | 시작 phase |
| `PHASE_END` | `3` | 종료 phase |
| `IMEM_WORDS` | `512` | testbench/golden instruction memory word 수 |
| `DMEM_BYTES` | `256` | 최종 비교 대상 data memory byte window |
| `DUT_DRAIN_CYCLES` | `4` | halt 도달 후 DUT settle/drain cycle |
| `MAX_WAIT_CYCLES` | `200000` | 무한루프/비정상 종료 방지 timeout |

재현 예시는 다음과 같습니다.

```bash
cd HDL/Single_Cycle/sim/crt
SEED=7 N_INST=200 M_ITER=50 PHASE_START=1 PHASE_END=3 ./run.sh
```

실패 로그에는 `SEED`, `seed_state`, `phase`, `iter`, `g_ptr`, `halt_pc`, golden/DUT PC 및 writeback debug 정보가 함께 출력됩니다.

## Coverage 성격

`tb_MIPS_CRT_v3.v`는 두 층으로 program을 만듭니다.

1. **Directed prelude**: 구현 대상 ISA class를 최소 1회 이상 명시적으로 포함합니다.
   - R-type ALU/shift: `add/addu/sub/subu/and/or/xor/nor/slt/sltu/sll/srl/sra/sllv/srlv/srav`
   - I-type: `addi/addiu/andi/ori/xori/slti/sltiu/lui`
   - Memory: `lb/lbu/lh/lhu/lw/sb/sh/sw`
   - Control flow: `beq/bne/j/jal/jr/jalr`
2. **Constrained random body**: phase별로 instruction category를 넓혀가며 random program을 생성합니다.
   - Phase 1: ALU/shift/I-type/load/store 중심
   - Phase 2: branch 추가
   - Phase 3: jump/jal/jr/jalr 추가

기본 random profile은 현재 Single Cycle register-file bypass topology의 combinational feedback을 피하기 위해 같은 instruction 안의 write/read alias를 피합니다.

예:

- R-type ALU: `rd != rs`, `rd != rt`
- shift immediate: `rd != rt`, `rs=0`
- variable shift: `rd != rs`, `rd != rt`
- I-type ALU/load: `rt != rs`
- `jalr`: `rd != rs`

## 비교 기준

CRT는 매 iteration마다 동일 program/data image를 DUT와 golden에 주입한 뒤 `j self` halt까지 실행합니다. 이후 다음 architectural state를 비교합니다.

- register file `r1..r31`, 그리고 `r0 == 0` invariant
- data memory `DMEM_BYTES` 범위의 byte-level little-endian 값

Pipeline은 나중에 retire/debug 계약이 갖춰지면 같은 final state 비교를 공유합니다.

## Waveform 보기

실행 후 생성되는 waveform은 다음 위치에 있습니다.

```text
HDL/Single_Cycle/sim/crt/wave.shm
```

SimVision에서 열어 다음 신호를 우선 확인합니다.

- `tb_MIPS_CRT_v3.ascii_state`
- `tb_MIPS_CRT_v3.ascii_phase`
- `tb_MIPS_CRT_v3.ascii_iter_state`
- `tb_MIPS_CRT_v3.ascii_last_emit_name`
- `tb_MIPS_CRT_v3.golden.*`
- `tb_MIPS_CRT_v3.uut.dbg_*`
- `tb_MIPS_CRT_v3.uut.u_regfile.regs[*]`
- `tb_MIPS_CRT_v3.uut.u_dmem.u_bram.mem[*]`

## 실패 triage 순서

1. `xrun_mips_crt.log`에서 첫 `FAIL Phase/Iter`를 찾습니다.
2. 같은 seed/phase/iter를 재현합니다. 필요하면 `M_ITER=1` 또는 phase 범위를 좁힙니다.
3. 로그의 register/memory mismatch를 봅니다.
4. `golden.inst_name`, `uut.dbg_inst`, `uut.dbg_pc`, `uut.dbg_next_pc`, `uut.dbg_reg_wen`, `uut.dbg_write_reg`, `uut.dbg_wdata`를 waveform에서 비교합니다.
5. generator/golden/testbench 문제인지 DUT RTL 문제인지 분리합니다.
6. DUT RTL 기능 문제로 보이면, 원칙상 바로 수정하지 않고 mismatch evidence를 공유한 뒤 RTL fix 승인을 받습니다.

## Non-goal / 경계

- Logisim 회로와 기존 block-level testvector는 수정하지 않습니다.
- Pipeline RTL은 현재 CRT pass에서 수정하거나 compile하지 않습니다.
- CRT 편의를 위해 DUT timing/memory 구조를 재설계하지 않습니다.
- 기본 CRT는 alias stress test가 아닙니다. write/read alias stress는 별도 opt-in profile로 분리하는 것이 안전합니다.
