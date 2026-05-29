# 임시 정리: MIPS 5-stage Pipelined Block Diagram 점검표

> 목적: 현재 작성 중인 MIPS 5-stage pipeline block diagram에서 ID stage 이후 확인해야 할 datapath/control/hazard 포인트를 빠르게 점검하기 위한 임시 문서입니다.
>
> 전제:
> - IF stage는 별도 확인 완료
> - `RsUsed` / `RtUsed` control은 ID에서 생성하는 방향으로 처리 완료
> - `DestReg` / `WriteReg`를 정하는 mux는 ID stage에 배치
> - Hazard Unit은 특정 stage 내부가 아니라 pipeline 전체를 감시/제어하는 전역 block으로 표현

---

## 1. 전체 점검 순서

```text
ID → ID/EX → EX → EX/MEM → MEM → MEM/WB → WB → Hazard/Forward/Flush Unit
```

핵심 확인 항목은 다음입니다.

```text
1. MIPS instruction field가 올바르게 분리되는가?
2. ID에서 control / immediate / WriteReg / RsUsed / RtUsed가 생성되는가?
3. ID/EX에 EX 이후 필요한 데이터와 control만 전달되는가?
4. Forwarding이 rs/rt + RsUsed/RtUsed 기준으로 동작하는가?
5. load-use stall, store data forwarding, branch/jump flush가 빠지지 않았는가?
```

---

## 2. ID stage 점검

### 2.1 Instruction field split

MIPS instruction field는 다음과 같습니다.

```text
opcode = inst[31:26]
rs     = inst[25:21]
rt     = inst[20:16]
rd     = inst[15:11]
shamt  = inst[10:6]
funct  = inst[5:0]
imm16  = inst[15:0]
target = inst[25:0]
```

점검:

```text
RISC-V의 rs1 / rs2 / rd 표현이 남아 있지 않은가?
MIPS의 rt가 source일 수도 있고 destination일 수도 있다는 점이 반영됐는가?
```

---

### 2.2 Control Unit

ID stage에서 생성할 주요 control은 다음입니다.

```text
RegWEn
DestSel
WBSel
ASel
BSel
ALUSel
BrSel
Branch
Jump
JumpSel
MemRW
WdLen
LoadEx
RsUsed
RtUsed
ImmSel
```

점검:

```text
ImmSel은 ID stage의 Imm Generator로만 들어가는가?
ImmSel 자체를 ID/EX로 넘기지 않는가?
RsUsed/RtUsed가 Hazard Unit과 ID/EX pipeline register로 나가는가?
DestSel이 ID stage의 WriteReg mux로 들어가는가?
```

---

### 2.3 RsUsed / RtUsed

`RsUsed`, `RtUsed`는 해당 instruction이 실제로 `rs`, `rt` 값을 source로 읽는지 표시합니다.

| 명령어 종류 | RsUsed | RtUsed | 비고 |
|---|---:|---:|---|
| R-type ALU | 1 | 1 | `add/sub/and/or/xor/nor/slt/sltu` |
| Shift immediate | 0 | 1 | `sll/srl/sra`, source는 `rt`, shift amount는 `shamt` |
| Shift variable | 1 | 1 | `sllv/srlv/srav`, shift amount source가 `rs` |
| I-type ALU | 1 | 0 | `rt`는 destination |
| `lui` | 0 | 0 | register source 없음 |
| Load | 1 | 0 | `rs`는 base, `rt`는 destination |
| Store | 1 | 1 | `rs`는 base, `rt`는 store data |
| Branch | 1 | 1 | `beq/bne` 비교 operand |
| `j/jal` | 0 | 0 | register source 없음 |
| `jr` | 1 | 0 | jump target source는 `rs` |
| `jalr` | 1 | 0 | target source는 `rs`, destination은 `rd` |

용도:

```text
ID stage: load-use stall 판단
EX stage: forwarding 판단
```

따라서 구조는 다음이 좋습니다.

```text
ID stage Control Unit
  → ID_RsUsed / ID_RtUsed
       ↘ Hazard Unit의 load-use 판단에 바로 사용
       ↘ ID/EX.RsUsed / ID/EX.RtUsed로 저장 후 EX forwarding 판단에 사용
```

---

### 2.4 Register File

ID stage에서 register file은 두 read port를 사용합니다.

```text
ReadAddr1 = rs
ReadAddr2 = rt
```

출력:

```text
rs_data
rt_data
```

점검:

```text
WB stage의 RegWEn / WriteReg / WriteData가 Register File write port로 되돌아오는가?
동일 cycle read/write 정책을 설명할 수 있는가?
$zero write는 내부에서 무시되는가?
```

---

### 2.5 Immediate Generator

`ImmSel`로 immediate 값을 생성합니다.

출력 예:

```text
ImmVal
ImmVal
```

점검:

```text
addi/addiu/lw/sw/lb/lh/slti/sltiu = sign extend
andi/ori/xori = zero extend
lui = imm16 << 16
branch offset = sign_ext(imm16) << 2
ImmSel 자체가 아니라 생성된 ImmVal가 ID/EX로 넘어가는가?
```

---

### 2.6 Jump Target Generator

ID stage에 둘 경우 입력은 다음입니다.

```text
IF/ID.PC4
instruction[25:0]
register jump target 후보
```

출력:

```text
JumpImmTarget
```

점검:

```text
j/jal target = {PC4[31:28], target26, 2'b00}
jr/jalr target = rs value 또는 EX stage에서 forwarding된 rs value
```

주의:

```text
jr/jalr를 ID에서 확정하면 ID-stage forwarding 또는 stall이 필요합니다.
초기 설계에서는 JumpImmTarget 후보는 ID에서 만들고,
최종 redirect 결정은 EX stage에서 forwarding 이후 확정하는 편이 안전합니다.
```

---

### 2.7 DestReg / WriteReg mux

현재 설계처럼 ID stage에 배치해도 좋습니다.

입력:

```text
rt
rd
5'd31
5'd0 또는 none
```

선택:

```text
DestSel
```

출력:

```text
WriteReg_ID
```

점검:

| 명령어 | WriteReg |
|---|---|
| R-type | `rd` |
| I-type ALU / load / lui | `rt` |
| `jal` | `$31` |
| `jalr` | `rd` |
| store / branch / `j` / `jr` | none 또는 `5'd0` |

`WriteReg_ID`는 `ID/EX.WriteReg`로 저장하고, 이후 `EX/MEM.WriteReg`, `MEM/WB.WriteReg`로 계속 전달합니다.

---

## 3. ID/EX pipeline register 점검

`ID/EX`에는 ID에서 생성한 결과 중 EX/MEM/WB에 필요한 것만 저장합니다.

추천 구성:

```text
Data:
  PC4
  rs_data
  rt_data
  ImmVal
  ImmVal
  JumpImmTarget

Register / metadata:
  rs
  rt
  shamt
  WriteReg
  RsUsed
  RtUsed

EX control:
  ASel
  BSel
  ALUSel
  BrSel
  Branch
  Jump
  JumpSel

MEM control:
  MemRW
  WdLen
  LoadEx

WB control:
  RegWEn
  WBSel
```

점검:

```text
ImmSel이 ID/EX에서 빠졌는가?
ImmVal / JumpImmTarget이 들어갔는가?
WriteReg_ID가 들어갔는가?
rs / rt가 forwarding 비교용으로 들어갔는가?
rt_data가 store data용으로 들어갔는가?
RsUsed / RtUsed가 forwarding 판단용으로 들어갔는가?
```

---

## 4. EX stage 점검

### 4.1 Forwarding mux

ALU A/B 앞에 각각 3-to-1 forwarding mux를 둡니다.

```text
ForwardA Mux:
  00: ID/EX.rs_data
  10: EX/MEM.ALUResult
  01: MEM/WB.WriteData
```

```text
ForwardB Mux:
  00: ID/EX.rt_data
  10: EX/MEM.ALUResult
  01: MEM/WB.WriteData
```

점검:

```text
ForwardA는 rs 기준인가?
ForwardB는 rt 기준인가?
EX/MEM forwarding이 MEM/WB forwarding보다 우선인가?
RsUsed/RtUsed gating이 들어가는가?
WriteReg == 0인 경우 forwarding을 막는가?
```

Forwarding 조건 개념:

```text
EX/MEM.RegWEn && EX/MEM.WriteReg != 0 && ID/EX.RsUsed && EX/MEM.WriteReg == ID/EX.rs
EX/MEM.RegWEn && EX/MEM.WriteReg != 0 && ID/EX.RtUsed && EX/MEM.WriteReg == ID/EX.rt
MEM/WB.RegWEn && MEM/WB.WriteReg != 0 && ID/EX.RsUsed && MEM/WB.WriteReg == ID/EX.rs
MEM/WB.RegWEn && MEM/WB.WriteReg != 0 && ID/EX.RtUsed && MEM/WB.WriteReg == ID/EX.rt
```

---

### 4.2 ASel / BSel mux

추천 순서:

```text
rs_data → ForwardA → ASel → ALU_A
rt_data → ForwardB → BSel → ALU_B
```

점검:

```text
ASel이 rs / PC4 / zero 등을 고를 수 있는가?
BSel이 rt / ImmVal / shamt / zero 등을 고를 수 있는가?
shift immediate에서 shamt가 ALU 입력으로 갈 수 있는가?
lui가 zero + ImmVal 방식으로 처리 가능한가?
```

---

### 4.3 ALU

점검 대상:

```text
add/sub/and/or/xor/nor
slt/sltu
sll/srl/sra
sllv/srlv/srav
```

주의:

```text
slt = signed compare
sltu = unsigned compare
sra = arithmetic right shift
```

---

### 4.4 Branch Comparator

Branch Comparator는 forwarding 이후 값을 봐야 합니다.

입력:

```text
Forwarded rs value
Forwarded rt value
BrSel
```

출력:

```text
BranchTaken
```

점검:

```text
beq = rs == rt
bne = rs != rt
ALU zero flag와 분리되어 있는가?
branch operand dependency가 forwarding으로 해결되는가?
```

---

### 4.5 Branch Target Adder

입력:

```text
ID/EX.PC4
ID/EX.ImmVal
```

출력:

```text
BranchTarget
```

점검:

```text
BranchTarget(ALUResult) = PCPlus4 + ImmVal
ImmVal = sign_ext(imm16) << 2
```

---

### 4.6 Jump / Branch Decision Unit

입력:

```text
Branch
BranchTaken
Jump
JumpSel
JumpImmTarget
BranchTarget
Forwarded rs value for jr/jalr if needed
```

출력:

```text
RedirectTaken
RedirectTarget
Flush
```

점검:

```text
j/jal immediate jump target 가능?
jr/jalr register jump target이 forwarding된 rs를 사용할 수 있는가?
BranchTaken이면 BranchTarget 선택?
Jump와 Branch 우선순위가 정의되어 있는가?
```

추천 우선순위:

```text
Jump > BranchTaken > PC+4
```

단, 같은 instruction에서 `Jump`와 `Branch`가 동시에 1이 되지 않도록 Control Unit에서 막는 것이 더 좋습니다.

---

## 5. EX/MEM pipeline register 점검

추천 구성:

```text
ALUResult
StoreData
WriteReg
PC4

RegWEn
WBSel
MemRW
WdLen
LoadEx
```

필요하면 redirect 관련 신호도 둘 수 있습니다.

```text
RedirectTaken
RedirectTarget
```

다만 PC redirect는 보통 EX stage에서 바로 IF stage의 next PC mux로 feedback합니다.

점검:

```text
StoreData가 ForwardB 결과인가?
WriteReg가 ID에서 확정된 값 그대로 전달되는가?
jal/jalr용 PC4가 WB까지 넘어갈 수 있는가?
```

---

## 6. MEM stage 점검

### 6.1 Data Memory

입력:

```text
Address = EX/MEM.ALUResult
WriteData = EX/MEM.StoreData
MemRW
WdLen
```

점검:

```text
lw/lh/lhu/lb/lbu load 가능?
sw/sh/sb store 가능?
address alignment 처리 방침이 있는가?
```

---

### 6.2 Load Extender

입력:

```text
RawMemData
WdLen
LoadEx
Address[1:0]
```

출력:

```text
LoadDataExt
```

점검:

```text
lb  = sign extend byte
lbu = zero extend byte
lh  = sign extend halfword
lhu = zero extend halfword
lw  = 32-bit 그대로
```

---

## 7. MEM/WB pipeline register 점검

추천 구성:

```text
LoadDataExt
ALUResult
PC4
WriteReg

RegWEn
WBSel
```

점검:

```text
memory data와 ALU result 둘 다 WB로 가는가?
PC4가 jal/jalr writeback용으로 남아 있는가?
WriteReg가 유지되는가?
RegWEn/WBSel이 유지되는가?
```

---

## 8. WB stage 점검

### 8.1 Writeback mux

입력:

```text
ALUResult
LoadDataExt
PC4
zero/none
```

선택:

```text
WBSel
```

출력:

```text
WriteData
```

점검:

| 명령어 | WB data |
|---|---|
| R/I ALU | ALUResult |
| load | LoadDataExt |
| `jal/jalr` | PC4 |
| store/branch/`j`/`jr` | write 없음 |

---

### 8.2 Register File writeback

WB 출력은 ID stage의 Register File write port로 돌아갑니다.

```text
RegWEn
WriteReg
WriteData
```

점검:

```text
WriteReg == 0이면 write 무시?
RegWEn == 0이면 write 없음?
```

---

## 9. Hazard / Forward / Flush Unit 점검

Hazard Unit은 전역 block으로 그려도 됩니다.

### 9.1 주요 입력

```text
IF/ID.rs
IF/ID.rt
ID_RsUsed
ID_RtUsed

ID/EX.rs
ID/EX.rt
ID/EX.RsUsed
ID/EX.RtUsed
ID/EX.WriteReg
ID/EX.RegWEn
ID/EX.MemRead 또는 ID/EX.MemRW == LOAD

EX/MEM.WriteReg
EX/MEM.RegWEn

MEM/WB.WriteReg
MEM/WB.RegWEn

RedirectTaken_EX
```

### 9.2 주요 출력

```text
PCWrite
IF_ID_Write
IF_ID_Flush
ID_EX_Flush
ForwardA[1:0]
ForwardB[1:0]
```

필요 시:

```text
StoreForward[1:0]
```

---

### 9.3 Load-use hazard

조건:

```text
load_use_hazard =
  ID/EX가 load이고
  ID/EX.WriteReg != 0이고
  (
    ID_RsUsed && IF/ID.rs == ID/EX.WriteReg
    또는
    ID_RtUsed && IF/ID.rt == ID/EX.WriteReg
  )
```

발생 시 제어:

```text
PCWrite     = 0
IF_ID_Write = 0
ID_EX_Flush = 1
```

의미:

```text
PC 유지
IF/ID 유지
ID/EX에 bubble 삽입
```

---

### 9.4 Branch / jump flush

EX stage에서 redirect가 확정되는 구조라면 younger instruction을 제거해야 합니다.

```text
RedirectTaken_EX = BranchTaken_EX 또는 JumpTaken_EX
```

발생 시:

```text
IF_ID_Flush = 1
ID_EX_Flush = 1
```

주의:

```text
flush된 instruction의 RegWEn / MemRW / Branch / Jump는 반드시 0 또는 safe value가 되어야 합니다.
```

---

### 9.5 Stall과 flush 우선순위

명세에 우선순위를 명확히 두는 것이 좋습니다.

추천:

```text
flush > stall
```

또는 설계 상황에 맞게:

```text
redirect가 확정되면 wrong-path instruction 제거를 우선한다.
load-use stall은 valid instruction 사이의 data hazard에만 적용한다.
```

---

## 10. 반드시 손으로 따라가볼 instruction

기본 datapath 확인:

```asm
add  $t0, $t1, $t2
addi $t0, $t1, 5
lw   $t0, 0($s0)
sw   $t0, 4($s0)
beq  $t0, $t1, label
j    target
jal  target
jr   $ra
jalr $ra, $t0
sll  $t0, $t1, 4
lui  $t0, 0x1234
```

Hazard 확인:

```asm
lw  $t0, 0($s0)
add $t1, $t0, $t2      # load-use stall

add $t0, $t1, $t2
beq $t0, $t3, label    # branch operand forwarding

add $t0, $t1, $t2
sw  $t0, 0($s0)        # store data forwarding

add $ra, $t1, $t2
jr  $ra                # register jump target dependency
```

---

## 11. 최종 핵심 요약

```text
ID 이후 점검 핵심은 다음입니다.

1. WriteReg를 ID에서 확정했는가?
2. ImmSel은 ID에서 소비하고, ImmVal/JumpImmTarget만 ID/EX로 넘기는가?
3. rs/rt, RsUsed/RtUsed, WriteReg가 hazard/forwarding에 충분히 전달되는가?
4. Forwarding은 WriteReg → rs/rt 비교에 RsUsed/RtUsed gating을 적용하는가?
5. StoreData는 ForwardB 결과 또는 별도 store forwarding으로 최신 값을 받는가?
6. load-use hazard에서 PC/IF_ID는 유지하고 ID_EX는 bubble 처리하는가?
7. branch/jump redirect 시 wrong-path instruction의 RegWEn/MemRW가 kill되는가?
8. jal/jalr용 PC4가 WB까지 유지되는가?
```
