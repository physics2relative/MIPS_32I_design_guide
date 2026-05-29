# Logisim 설계 완료 후 HDL Export / 검증 / FPGA 적용 가이드라인

## 1. 문서 목적

이 문서는 MIPS Logisim 회로 설계를 완료한 뒤 다음 단계를 어떻게 가져갈지 정리합니다.

- Logisim 회로를 HDL로 export할지 여부
- Verilog/SystemVerilog 기반 constrained random test를 어떻게 활용할지
- 합성 가능성, resource, timing 분석을 어떻게 해석할지
- FPGA 보드 검증을 어느 수준까지 수행하는 것이 과제 관점에서 의미 있는지
- 직접 HDL을 작성할 경우 Logisim 회로와의 동치성을 어떻게 설명할지

핵심 기준은 다음입니다.

```text
MIPS 기능 명세
  -> Python golden model / ISS
  -> Logisim 회로 검증
  -> HDL 검증
  -> synthesis / timing 분석
  -> FPGA self-test demo
```

---

## 2. 최종 권장 방향

과제 완성도와 검증 신뢰성을 기준으로 하면 다음 구조를 권장합니다.

```text
Logisim 회로
  = 설계 시각화 / 구조 설명 / 기본 기능 검증

Logisim-evolution HDL export
  = 가능성 실험 / 참고 산출물 / export 한계 분석

직접 작성 HDL
  = constrained random test / synthesis / timing / FPGA 후보 구현

FPGA 보드
  = 최종 smoke test / self-test demo
```

즉, **Logisim HDL export를 최종 FPGA 구현의 주 경로로 신뢰하기보다는, 명세 기반으로 직접 HDL을 작성하고 동일 golden model로 Logisim과 HDL을 각각 검증하는 방식**이 가장 안전합니다.

---

## 3. 왜 HDL export만으로는 부족한가?

### 3.1 현재 프로젝트에서 관측된 문제

ALU에 대해 Logisim-evolution 4.1.0 export 실험을 수행한 결과, dummy board와 mapping file을 사용하면 HDL export 자체는 가능했습니다.

관측 결과:

- dummy board 기반 HDL export: 가능
- generated Verilog compile/elaboration/simulation: 가능
- 일부 ALU vector mismatch 관측
- VHDL export는 예약어 label 등으로 xrun compile에 바로 사용하기 어려움
- Verilog는 전역 `-sv` 옵션을 빼고 `.sv` testbench만 SystemVerilog로 처리해야 compile 가능

특히 Logisim 기본 라이브러리 컴포넌트 중 다음 계열에서 export 결과를 신뢰하기 어렵다는 정황이 있었습니다.

- Bit Extender 계열
- Shifter 계열
- 일부 Arithmetic / Comparator 주변 연결

따라서 현재 프로젝트에서 HDL export는 다음과 같이 해석하는 것이 적절합니다.

```text
Logisim 회로가 맞다/틀리다를 단정하는 기준이 아니라,
Logisim -> HDL 변환 체인의 가능성과 한계를 확인하는 실험 산출물
```

### 3.2 CLI 자동화 한계

Logisim-evolution의 `--test-fpga ... HDLONLY` CLI는 custom board를 classpath로 인식시킬 수는 있지만, board mapping file을 직접 넘기는 일반적인 경로가 제한적입니다. 그래서 headless 자동화를 위해서는 helper script 또는 내부 API 호출이 필요합니다.

현재 관련 실험/재현 파일:

```text
HDL_export/boards/HDL_ONLY_ALU_DUMMY.xml
HDL_export/boards/HDL_ONLY_ALU_DUMMY_ALU.map.xml
HDL_export/scripts/export_alu_logisim_dummy_board.sh
HDL_export/scripts/run_alu_xrun_logisim_verilog.sh
HDL_export/reports/dummy_board_hdl_export_report.md
```

---

## 4. FPGA에 올려보는 것이 얼마나 유의미한가?

FPGA 업로드는 의미가 있습니다. 다만 그 의미는 “모든 기능이 맞다”를 증명하는 것이 아니라 다음에 가깝습니다.

```text
설계가 실제 하드웨어 primitive로 구현 가능한 구조인지 확인한다.
합성 가능성, resource 사용량, timing 특성을 확인한다.
보드에서 clock 기반으로 동작하는 smoke test를 통과한다.
```

### 4.1 FPGA가 증명하는 것

- 합성 가능한 구조인지
- FPGA resource에 들어가는지
- 특정 clock에서 timing을 만족하는지
- self-test program이 보드에서 동작하는지
- single-cycle CPU의 critical path가 어느 정도인지
- pipelined 구조로 바꿨을 때 timing이 어떻게 개선되는지

### 4.2 FPGA가 증명하지 못하는 것

- 모든 corner case가 맞는지
- constrained random test를 충분히 통과했는지
- 내부 상태가 cycle마다 정확히 맞는지
- pipeline hazard/forwarding/stall/flush가 완전한지

이런 부분은 FPGA보다 HDL simulator에서 검증하는 것이 훨씬 적합합니다.

---

## 5. Logisim block 설계에서도 합성가능성 검토가 의미 있는가?

의미는 있습니다. 다만 HDL에서 말하는 “합성가능성”과 조금 다릅니다.

HDL에서는 다음과 같은 시뮬레이션 전용 문법 때문에 합성 불가능한 코드가 생깁니다.

```verilog
#10
initial begin ... end
파일 입출력
동적 배열
real type
불명확한 while loop
```

Logisim은 gate, mux, adder, register, memory 같은 하드웨어 block 기반 설계이므로 이런 문제는 상대적으로 적습니다. 하지만 여전히 다음을 확인할 필요가 있습니다.

1. 모든 Logisim 컴포넌트가 HDL export와 FPGA synthesis에 적합한가?
2. Logisim-evolution이 해당 컴포넌트를 의도대로 HDL화하는가?
3. 생성된 HDL이 synthesis tool에서 받아들여지는가?
4. FPGA resource와 IO pin 제약을 만족하는가?
5. 원하는 clock frequency에서 timing을 만족하는가?

따라서 과제 보고서에서는 “합성가능성 증명”보다 아래 표현이 더 정확합니다.

```text
FPGA 구현 가능성 검토
HDL export 및 synthesis feasibility check
resource / timing 분석
```

---

## 6. Constrained random test를 위한 권장 구조

Constrained random test는 FPGA보다 HDL simulator에서 수행하는 것이 적합합니다.

권장 구조:

```text
MIPS 명세
  -> Python golden model 또는 SystemVerilog reference model
  -> constrained random input / program 생성
  -> HDL DUT simulation
  -> expected vs observed 비교
  -> seed, failure case, waveform, coverage 저장
```

### 6.1 ALU block-level random

입력:

```text
ALUA[31:0]
ALUB[31:0]
ALUSel[3:0]
```

검증 대상:

- ADD
- SUB
- AND
- OR
- XOR
- NOR
- SLT signed
- SLTU unsigned
- SLL
- SRL
- SRA

corner-biased 값:

```text
0x00000000
0x00000001
0xFFFFFFFF
0x7FFFFFFF
0x80000000
0xAAAAAAAA
0x55555555
shift amount = 0, 1, 4, 31
```

목표:

```text
수천~수만 case random regression
operation coverage
corner value coverage
failure seed 재현 가능
```

### 6.2 Register File random

검증 항목:

- `$zero`는 항상 0
- `RegWEn=0`이면 write 없음
- `RegWEn=1`이면 지정 register write
- rs/rt 2-port read 독립성
- 같은 cycle read/write timing 정책 확인
- reset 동작

### 6.3 Control Unit 검증

Control Unit은 random보다 instruction table 기반 exhaustive 검증이 적합합니다.

```text
opcode/funct -> control signals
```

모든 지원 instruction에 대해 expected control table과 DUT output을 비교합니다.

### 6.4 CPU integration 검증

CPU 전체는 instruction sequence 단위로 검증합니다.

Directed program:

- arithmetic program
- logic program
- load/store program
- branch taken / not taken program
- jump program
- slt/sltu program
- shift program

Random program:

- 지원 instruction만 생성
- branch target은 프로그램 범위 안으로 제한
- memory 주소는 유효 범위 안으로 제한
- `$zero` write는 허용하되 항상 0인지 확인
- undefined behavior는 생성하지 않음

비교 기준:

```text
Python MIPS ISS trace == HDL CPU trace
```

trace 비교 항목:

```text
cycle
PC
instruction
register write enable
register write address
register write data
memory write enable
memory write address
memory write data
```


### 6.5 기존 RISC-V CRT v3 방식 분석

참고 파일:

```text
/user/choi.jw/PROJECT/verilog/RISCV/RISCV_32I_PIPELINED/testbench/tb_CRT_v3.v
```

해당 테스트벤치는 RISC-V pipelined CPU 검증에서 사용한 **program-level constrained random test** 구조입니다. 핵심은 다음과 같습니다.

```text
DUT pipelined CPU
    +
Behavioral golden model
    +
Random instruction program generator
    +
Final architectural state comparison
```

구체적인 흐름:

1. DUT pipeline CPU와 `RISCV_Golden` behavioral model을 동시에 둡니다.
2. 테스트벤치 내부에서 random instruction sequence를 생성합니다.
3. 같은 instruction을 DUT instruction memory와 golden instruction memory에 동시에 로드합니다.
4. Golden model은 1 instruction/cycle 방식으로 architectural behavior를 계산합니다.
5. DUT는 pipeline drain을 고려해 halt instruction이 WB stage에 도달할 때까지 기다립니다.
6. 마지막에 register file과 data memory 전체를 golden과 비교합니다.
7. 실패 시 golden/DUT register dump와 waveform으로 원인을 추적합니다.

이 방식의 장점:

| 장점 | 의미 |
|---|---|
| Random program 기반 | 사람이 놓치기 쉬운 instruction 조합을 많이 만듭니다. |
| Golden model 비교 | 사람이 expected value를 직접 계산하지 않아도 됩니다. |
| Pipeline 검증 가능 | forwarding, stall, flush 오류가 최종 state mismatch로 드러납니다. |
| Seed 재현 가능 | 실패한 random case를 같은 seed로 다시 실행할 수 있습니다. |
| Phase 확장 가능 | ALU → memory → branch → jump 순서로 복잡도를 높일 수 있습니다. |

특히 `REG_POOL`을 작게 잡아 일부 register만 반복 사용하면 RAW dependency가 자주 발생하므로 forwarding/stall 검증에 유리합니다.

### 6.6 RISC-V CRT v3 방식을 MIPS에 적용할 수 있는가?

결론적으로 **방식 자체는 MIPS에도 유효합니다.** 다만 instruction encoding, immediate 규칙, destination register 규칙, jump/branch 규칙이 다르므로 generator와 golden model은 MIPS 전용으로 새로 작성해야 합니다.

MIPS 적용 시 바뀌는 핵심 항목:

| 항목 | RISC-V CRT v3 | MIPS CRT 적용 |
|---|---|---|
| Instruction format | R/I/S/B/U/J | R/I/J |
| Destination register | 대부분 `rd` | R-type은 `rd`, I-type/load/lui는 `rt`, `jal`은 `$31`, `jalr`은 `rd` |
| Branch target | RISC-V B-type immediate | `PC + 4 + (sign_ext(imm) << 2)` |
| Jump target | JAL/JALR | `j/jal`은 `{PC+4[31:28], target26, 2'b00}`, `jr/jalr`은 register target |
| Logical immediate | RISC-V I-type immediate 규칙 | `andi/ori/xori`는 zero extension |
| 실제 branch subset | BEQ/BNE/BLT/BGE/BLTU/BGEU 등 | 프로젝트 기준 실제 hardware branch는 `beq`, `bne` 중심 |
| Pseudo branch | 일부 ISA에 직접 존재 | `blt/bge/bltu/bgeu`는 `slt/sltu + beq/bne` pseudo sequence로만 처리 |

따라서 MIPS에서는 다음 helper가 필요합니다.

```verilog
function [31:0] enc_R;
    input [4:0] rs, rt, rd;
    input [4:0] shamt;
    input [5:0] funct;
    enc_R = {6'b000000, rs, rt, rd, shamt, funct};
endfunction

function [31:0] enc_I;
    input [5:0] opcode;
    input [4:0] rs, rt;
    input [15:0] imm;
    enc_I = {opcode, rs, rt, imm};
endfunction

function [31:0] enc_J;
    input [5:0] opcode;
    input [25:0] target;
    enc_J = {opcode, target};
endfunction
```

### 6.7 기존 CRT v3 방식의 한계

RISC-V CRT v3 방식은 좋은 baseline이지만, 그대로 MIPS 최종 검증으로 쓰기에는 몇 가지 한계가 있습니다.

1. **최종 state만 비교합니다.**

   Register/memory 최종 결과가 틀린 것은 알 수 있지만, 어느 instruction에서 처음 틀렸는지 찾기 어렵습니다.

2. **DUT 내부 계층 이름에 의존합니다.**

   예를 들어 다음과 같은 접근은 RTL 구조가 바뀌면 테스트벤치도 깨집니다.

   ```verilog
   uut.u_reg_file.reg32[i]
   uut.u_dmem.u_bram.mem[i]
   uut.PC_WB
   ```

3. **Golden model도 Verilog로 직접 작성하면 DUT와 같은 착각을 공유할 수 있습니다.**

   예를 들어 `andi/ori/xori` zero extension을 DUT와 golden이 동시에 잘못 구현하면 테스트가 통과할 수 있습니다.

4. **Cycle-by-cycle pipeline state를 비교하지 않습니다.**

   이 자체는 장점이기도 합니다. pipeline microarchitecture가 달라도 final architectural state만 맞으면 통과할 수 있기 때문입니다. 하지만 디버깅 관점에서는 첫 mismatch 위치를 바로 찾기 어렵습니다.

### 6.8 MIPS에서 더 권장하는 CRT 구조

MIPS 최종 검증은 다음 구조를 권장합니다.

```text
Python MIPS random program generator
        ↓
Python MIPS ISS / golden model 실행
        ↓
program.hex / program.asm / expected_trace.csv 생성
        ↓
HDL testbench가 program.hex 로드
        ↓
DUT 실행
        ↓
commit/retire trace와 expected_trace 비교
        ↓
최종 register/memory state 재확인
```

이 구조의 장점:

| 장점 | 설명 |
|---|---|
| RTL과 독립된 golden | Verilog DUT와 같은 실수를 공유할 가능성이 줄어듭니다. |
| 디버깅 쉬움 | 실패한 `program.asm`, seed, trace를 바로 확인할 수 있습니다. |
| Logisim과 공유 가능 | 같은 `program.hex`를 Logisim ROM에도 넣을 수 있습니다. |
| 재현성 좋음 | seed와 generated artifact를 저장하면 실패 case를 고정할 수 있습니다. |
| 확장성 좋음 | directed, random, corner-biased random을 같은 구조로 처리할 수 있습니다. |

생성 artifact 예시:

```text
program.hex
program.asm
expected_commit_trace.csv
expected_final_regs.csv
expected_final_mem.csv
seed_info.txt
```

### 6.9 Pipeline CPU용 commit/retire trace 비교 권장

Pipeline CPU에서는 최종 state 비교보다 **commit/retire 단위 비교**가 더 좋습니다. DUT에 검증 전용 debug interface를 추가하는 것을 권장합니다.

권장 commit interface:

```verilog
output        commit_valid,
output [31:0] commit_pc,
output [31:0] commit_inst,
output        commit_reg_we,
output [4:0]  commit_reg_waddr,
output [31:0] commit_reg_wdata,
output        commit_mem_we,
output [31:0] commit_mem_addr,
output [31:0] commit_mem_wdata,
output [3:0]  commit_mem_wmask
```

비교 기준:

```text
DUT가 retire한 instruction == Python golden trace의 다음 instruction
```

비교 방식별 특징:

| 방식 | 장점 | 단점 | 추천도 |
|---|---|---|---|
| Final state 비교 | 구현이 쉽습니다. | 첫 오류 지점을 찾기 어렵습니다. | baseline |
| Commit trace 비교 | 첫 mismatch instruction을 바로 찾을 수 있습니다. | commit debug signal이 필요합니다. | 가장 추천 |
| Cycle-by-cycle pipeline 비교 | 내부 동작을 가장 자세히 볼 수 있습니다. | pipeline 구조에 너무 종속됩니다. | 특수 디버깅용 |

따라서 MIPS pipeline CRT의 기본 pass/fail 기준은 다음으로 둡니다.

```text
1. 모든 retired instruction의 PC/instruction/writeback/memory write가 golden trace와 일치
2. 프로그램 종료 후 register file 최종 상태 일치
3. 프로그램 종료 후 data memory 최종 상태 일치
4. timeout 없음
5. X/Z propagation 없음
```

### 6.10 MIPS CRT phase 구성 권장

처음부터 full random을 돌리면 디버깅이 어렵기 때문에 phase를 나눕니다.

```text
Phase 0: directed smoke test
Phase 1: R-type / I-type ALU
Phase 2: load/store
Phase 3: beq/bne branch taken / not-taken
Phase 4: j / jal
Phase 5: jr / jalr
Phase 6: dependency torture
Phase 7: full random
```

각 phase의 목적:

| Phase | 목적 |
|---|---|
| 0 | reset, fetch, 기본 writeback 확인 |
| 1 | ALU와 immediate extension 확인 |
| 2 | byte/halfword/word load-store와 sign/zero extension 확인 |
| 3 | branch comparator, PC update, flush 확인 |
| 4 | absolute jump와 link register `$31` 확인 |
| 5 | register jump와 jump target hazard 확인 |
| 6 | forwarding/stall 집중 검증 |
| 7 | 전체 instruction 조합 random regression |

### 6.11 MIPS CRT에서 반드시 넣을 corner case

ALU corner 값:

```text
0x00000000
0x00000001
0xFFFFFFFF
0x7FFFFFFF
0x80000000
0xAAAAAAAA
0x55555555
shift amount = 0, 1, 4, 31
```

Memory corner:

```text
lb/lbu: 모든 byte lane
lh/lhu: halfword lane, sign bit 0/1
lw: word-aligned address
sb/sh/sw: byte enable 또는 word merge 확인
```

Branch/jump hazard corner:

```asm
add  $t0, $t1, $t2
beq  $t0, $t3, label     # branch operand dependency

add  $ra, $t1, $t2
jr   $ra                 # jump target dependency

jal  func                # $31 = PC + 4
nop
```

Pseudo branch는 실제 hardware instruction으로 생성하지 않습니다. 필요한 경우 assembler/generator 단계에서 다음처럼 확장합니다.

```asm
blt $s0, $s1, label
# pseudo expansion
slt $at, $s0, $s1
bne $at, $zero, label
```

### 6.12 MIPS CRT 최종 권장안

RISC-V의 `tb_CRT_v3.v` 방식은 MIPS CRT의 좋은 출발점입니다. 하지만 최종 제출/검증 완성도를 높이려면 다음 방향을 권장합니다.

```text
RISC-V tb_CRT_v3 방식
= DUT + Verilog golden + random program + final state comparison

MIPS 권장 방식
= Python generator/ISS + program.hex + commit trace scoreboard + final state comparison
```

즉, 최종 방향은 다음과 같습니다.

```text
1. Python MIPS generator와 Python golden ISS를 작성한다.
2. seed 기반으로 program.asm, program.hex, expected_trace.csv를 생성한다.
3. HDL testbench는 program.hex를 instruction memory에 로드한다.
4. DUT의 commit interface를 통해 retire instruction을 golden trace와 비교한다.
5. 프로그램 종료 후 register/memory 최종 상태도 한 번 더 비교한다.
6. 실패 시 seed, asm, trace, waveform을 저장한다.
```

한 줄 요약:

```text
기존 RISC-V CRT v3 방식은 baseline으로 유효하지만,
MIPS 최종 검증은 Python golden + HDL commit scoreboard 구조가 더 좋다.
```
---

## 7. 직접 HDL 작성 시 Logisim 회로와 동치성을 설명하는 방법

직접 HDL을 작성하면 구조가 Logisim export HDL과 다를 수 있습니다. 과제 관점에서 중요한 것은 구조 동일성이 아니라 **기능 동치성**입니다.

### 7.1 동일 명세 기반

Logisim 회로와 HDL 구현은 모두 동일한 문서를 기준으로 합니다.

```text
doc/mips_functional_spec.md
```

### 7.2 동일 인터페이스

예: ALU

```text
Logisim ALU:
  ALUA[31:0]
  ALUB[31:0]
  ALUSel[3:0]
  ALURESULT[31:0]

HDL ALU:
  input  [31:0] ALUA
  input  [31:0] ALUB
  input  [3:0]  ALUSel
  output [31:0] ALURESULT
```

동일한 port 의미를 갖도록 정의합니다.

### 7.3 동일 test vector

동일한 입력 벡터를 Logisim과 HDL 양쪽에 적용합니다.

```text
Python golden vector
  -> Logisim testbench
  -> HDL xrun testbench
```

둘 다 golden output과 일치하면, 테스트된 입력 공간에서 기능적으로 동치라고 설명할 수 있습니다.

### 7.4 CPU는 architectural state 기준

CPU 전체는 내부 wire 구조가 같을 필요는 없습니다. 대신 architectural state가 같아야 합니다.

비교 대상:

```text
PC
register file state
memory state
commit trace
```

보고서 표현 예:

> Logisim 회로와 HDL 구현은 동일한 MIPS 기능 명세를 구현한다. 두 구현은 동일한 block interface와 동일한 golden test vector를 공유하며, block-level output 및 CPU-level architectural trace가 Python reference와 일치함을 확인했다. 따라서 두 구현은 검증된 입력 공간에서 기능적으로 동치이다.

---

## 8. Synthesis / timing 분석 권장 방법

### 8.1 Single-cycle CPU

single-cycle CPU는 한 cycle 안에 다음 경로가 모두 포함될 수 있습니다.

```text
PC -> Instruction Memory -> Decode -> Register File read -> ALU -> Data Memory -> Writeback
```

따라서 critical path가 길고 maximum frequency가 낮을 가능성이 큽니다.

확인할 것:

- critical path report
- ALU path delay
- memory path delay
- register file read/write timing
- control decode delay
- achieved Fmax

### 8.2 Pipelined CPU

pipelined CPU에서는 stage를 나눕니다.

```text
IF -> ID -> EX -> MEM -> WB
```

확인할 것:

- stage별 critical path
- pipeline register overhead
- forwarding path delay
- hazard detection delay
- branch flush/stall timing
- single-cycle 대비 Fmax 개선

보고서에서 의미 있는 비교:

```text
single-cycle은 구조가 단순하지만 critical path가 길다.
pipelined 구조는 hazard 제어가 필요하지만 stage별 delay를 줄여 clock frequency를 높일 수 있다.
```

---

## 9. FPGA 보드 검증 권장 방식

FPGA는 대규모 random 검증용이 아니라 최종 smoke test용으로 사용하는 것이 좋습니다.

권장 방식:

```text
ROM에 self-test program 저장
CPU가 자체 검증 program 실행
성공하면 LED PASS
실패하면 LED FAIL 또는 error count 표시
```

예:

```text
LED[0] = PASS
LED[1] = FAIL
7-segment = error count 또는 current test id
```

가능하면 내부 debug를 위해 다음도 고려합니다.

- PC 하위 bit 표시
- 현재 test id 표시
- error count counter
- memory/register mismatch code 표시

---

## 10. 과제 제출 관점의 권장 산출물

최소 권장 산출물:

```text
doc/mips_functional_spec.md
doc/logisim_hdl_export_fpga_guide.md
HDL_export/reports/dummy_board_hdl_export_report.md
vectors/ 또는 HDL_export/vectors/
Python golden generator
Logisim block별 test 결과
HDL xrun test 결과
```

완성도 높은 산출물:

```text
block-level directed test report
block-level constrained random test report
CPU program-level directed test report
CPU random instruction test report
synthesis resource report
timing report
FPGA self-test demo report
```

---

## 11. 최종 권장 플로우

```text
1. MIPS 기능 명세 확정
2. Python golden model / MIPS ISS 작성
3. Logisim 회로를 directed vector로 검증
4. Logisim-evolution HDL export는 실험/부록으로 정리
5. FPGA/timing 검증용 HDL은 직접 작성
6. HDL block-level constrained random test 수행
7. HDL CPU program-level directed/random test 수행
8. synthesis/resource/timing report 분석
9. 시간이 남으면 FPGA self-test demo 수행
```

한 줄 요약:

```text
Logisim은 설계와 시각화의 기준,
Python golden은 기능 정답의 기준,
직접 HDL은 random 검증과 FPGA/timing 분석의 기준,
FPGA는 최종 구현 가능성의 smoke test로 둔다.
```
