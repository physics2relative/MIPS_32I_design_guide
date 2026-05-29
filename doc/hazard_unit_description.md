# MIPS 5-Stage Pipeline Hazard Unit 설계 설명

이 문서는 `HDL/5_Stage_PipeLined/rtl/core/hazard_unit.v` 및 `mips_pipeline_top.v`의 현재 구조를 기준으로 MIPS 5-stage pipeline의 hazard 처리 방식을 설명합니다. 현재 RTL은 forwarding 전용 모듈을 따로 두지 않고, **`hazard_unit` 하나가 forwarding selector, stall, flush를 모두 생성**합니다.

## 0. Pipeline 전제

현재 pipeline stage 배치는 다음 기준입니다.

```text
IF  : PC register, instruction memory, PC+4
ID  : instruction split, control, register file read, immediate generation,
      jump immediate target generation, DestReg selection
EX  : ALU operand select, ALU execute, Branch Comparator,
      JumpSel/register-target selection, PC redirect decision
MEM : data memory access
WB  : writeback mux, register file write
```

중요한 설계 결정은 다음과 같습니다.

- **Branch Comparator는 EX stage**에 둡니다.
- **JumpSel, 즉 jump immediate target과 register target 중 선택하는 mux는 EX stage**에 둡니다.
- **Jump Target Generator는 ID stage**에 둡니다. `target26`과 `PC+4`만으로 `{PC+4[31:28], target26, 2'b00}`을 만들 수 있기 때문입니다.
- **DestReg selection mux는 ID stage**에 둡니다. `rt/rd/$31/none` 선택은 decode 직후 결정 가능하고, 이후 stage에서는 선택된 `DestReg`만 전달합니다.
- Branch/jump redirect는 EX stage에서 확정되므로, taken branch 또는 jump가 발생하면 그보다 어린 IF/ID, ID/EX instruction을 flush합니다.
- Branch/jump operand forwarding은 별도 ID forwarding이 아니라 **EX stage forwarding 경로**를 그대로 사용합니다.

## 1. Data hazard - forwarding 처리 가능

### 1.1 문제 정의

Data hazard는 뒤 instruction이 앞 instruction의 결과 register를 읽어야 하는데, 그 값이 아직 register file에 writeback되지 않은 상황입니다.

```mips
add  $1, $2, $3
sub  $4, $1, $5
```

`sub`가 `$1`을 사용할 때 `add` 결과가 아직 WB에 도달하지 않았더라도, 값이 MEM/WB 쪽에 존재하면 stall 없이 forwarding으로 해결합니다.

현재 설계에서 forwarding은 **EX stage operand**에 대해서만 수행합니다. 이 EX operand는 다음 블록들이 공유합니다.

- ALU 입력 A/B
- EX stage Branch Comparator 입력 `Data_rs_EX_fwd`, `Data_rt_EX_fwd`
- `jr/jalr`의 register jump target인 `Data_rs_EX_fwd`
- store data로 MEM stage에 넘어가는 `Data_rt_EX_fwd`

따라서 ID-stage 전용 forwarding selector 없이 EX-stage forwarding selector만 사용합니다.

### 1.2 Forwarding selector encoding

`hazard_unit`은 다음 selector를 생성합니다.

| Selector | 의미 | 사용 위치 |
| --- | --- | --- |
| `2'b00` (`FWD_REG`) | 원래 ID/EX pipeline register operand 사용 | EX |
| `2'b01` (`FWD_WB`) | WB stage writeback value 사용 | EX |
| `2'b10` (`FWD_MEM`) | MEM stage forwarding value 사용 | EX |

EX-stage forwarding은 MEM/WB producer만 대상으로 합니다. 같은 cycle의 EX 결과를 동일 EX stage의 다른 instruction으로 forwarding하는 것은 불가능하기 때문입니다.

### 1.3 EX stage forwarding 판정

출력 신호는 다음 두 개입니다.

```verilog
ForwardA_EX
ForwardB_EX
```

`ForwardA_EX`는 `rs_EX`, `ForwardB_EX`는 `rt_EX`에 대응합니다.

우선순위는 다음과 같습니다.

```text
1순위: MEM stage producer
2순위: WB stage producer
3순위: 원래 ID/EX register 값
```

개념식은 다음과 같습니다.

```verilog
if (rs_EX != 0) begin
    if (RegWEn_MEM && DestReg_MEM != 0 && DestReg_MEM == rs_EX)
        ForwardA_EX = FWD_MEM;
    else if (RegWEn_WB && DestReg_WB != 0 && DestReg_WB == rs_EX)
        ForwardA_EX = FWD_WB;
    else
        ForwardA_EX = FWD_REG;
end

if (rt_EX != 0) begin
    if (RegWEn_MEM && DestReg_MEM != 0 && DestReg_MEM == rt_EX)
        ForwardB_EX = FWD_MEM;
    else if (RegWEn_WB && DestReg_WB != 0 && DestReg_WB == rt_EX)
        ForwardB_EX = FWD_WB;
    else
        ForwardB_EX = FWD_REG;
end
```

MEM이 WB보다 우선인 이유는 같은 register에 연속 write가 있을 때 가장 최신 값이 MEM 쪽에 있을 수 있기 때문입니다.

```mips
addi $1, $0, 1
addi $1, $1, 2
add  $2, $1, $3
```

세 번째 instruction에서 `$1`의 최신 값은 첫 번째 instruction의 WB 값이 아니라 두 번째 instruction의 MEM 값입니다.

### 1.4 Branch/jump에서의 forwarding 사용

Branch Comparator가 EX stage에 있으므로 `beq/bne`도 일반 ALU operand forwarding과 동일한 값을 사용합니다.

```text
BranchComp.rs = Data_rs_EX_fwd
BranchComp.rt = Data_rt_EX_fwd
```

`jr/jalr`의 register target도 EX stage에서 선택합니다.

```text
SelectedJumpTarget_EX = (JumpSel_EX == 1) ? Data_rs_EX_fwd : JumpImmTarget_EX
```

따라서 아래 같은 dependency는 별도 ID forwarding 없이 EX forwarding으로 처리됩니다.

```mips
addi $1, $0, 16
jr   $1
```

`jr`가 EX stage에 도달했을 때 `$1` 값은 MEM/WB forwarding을 통해 `Data_rs_EX_fwd`로 공급됩니다.

## 2. Data hazard - load-use hazard, stall 필요

### 2.1 문제 정의

Load-use hazard는 load instruction 바로 뒤의 instruction이 load 결과를 필요로 하는 경우입니다.

```mips
lw  $1, 0($0)
add $2, $1, $3
```

`add`가 EX stage에서 `$1`을 사용해야 하는 시점에 `lw`의 loaded data는 아직 data memory에서 준비되지 않았습니다. 따라서 forwarding만으로 해결할 수 없고, pipeline을 한 cycle stall해야 합니다.

Branch/jump도 EX에서 operand를 쓰므로 원리는 같습니다.

```mips
lw  $1, 0($0)
beq $1, $2, target

lw  $1, 0($0)
jr  $1
```

이 경우 branch comparator 또는 jump register target이 EX stage에서 load 결과를 필요로 하지만, 바로 다음 cycle에는 아직 load data가 없으므로 한 cycle bubble을 넣습니다.

### 2.2 Load-use hazard 판정식

RTL은 ID stage instruction이 실제 사용하는 source register와 EX stage load destination이 겹치는지 확인합니다.

```verilog
rs_load_use = RsUsed_ID && (rs_ID != 0) &&
              RegWEn_EX && MemRead_EX && (DestReg_EX == rs_ID);

rt_load_use = RtUsed_ID && (rt_ID != 0) &&
              RegWEn_EX && MemRead_EX && (DestReg_EX == rt_ID);

load_use_hazard = rs_load_use || rt_load_use;
```

각 조건의 의미는 다음과 같습니다.

| 조건 | 의미 |
| --- | --- |
| `RsUsed_ID` / `RtUsed_ID` | ID instruction이 해당 register field를 실제 source로 사용할 때만 hazard로 봅니다. |
| `rs_ID != 0`, `rt_ID != 0` | `$zero`는 항상 0이므로 dependency 대상에서 제외합니다. |
| `RegWEn_EX` | EX instruction이 register write를 수행할 때만 producer입니다. |
| `MemRead_EX` | EX instruction이 load일 때만 load-use hazard입니다. |
| `DestReg_EX == rs_ID/rt_ID` | load destination과 consumer source가 같으면 hazard입니다. |

### 2.3 `RsUsed_ID`, `RtUsed_ID`가 필요한 이유

MIPS instruction field 이름만 보고 hazard를 판단하면 false stall이 생길 수 있습니다.

예를 들어 I-type ALU instruction은 `rt` field가 source가 아니라 destination입니다.

```mips
addi $2, $1, 5
```

이 instruction은 다음 의미입니다.

```text
rs = $1 : source
rt = $2 : destination
```

따라서 `rt_ID == DestReg_EX`라는 이유만으로 stall하면 안 됩니다. 이 문제를 막기 위해 control unit이 instruction별로 `RsUsed_ID`, `RtUsed_ID`를 생성합니다.

| Instruction 종류 | RsUsed | RtUsed | 설명 |
| --- | --- | --- | --- |
| R-type ALU | 1 | 1 | `rs`, `rt` 모두 source |
| Shift immediate `sll/srl/sra` | 0 | 1 | `rt`만 source |
| I-type ALU `addi/ori/...` | 1 | 0 | `rs`만 source, `rt`는 destination |
| Load | 1 | 0 | base register만 source |
| Store | 1 | 1 | base register와 store data 모두 source |
| `beq/bne` | 1 | 1 | 비교 operand 둘 다 source |
| `j/jal` | 0 | 0 | register source 없음 |
| `jr/jalr` | 1 | 0 | jump register target으로 `rs` 사용 |

### 2.4 Stall 동작

Load-use hazard가 발생하면 다음 제어를 출력합니다.

```verilog
Stall_PC    = 1'b1;
Stall_IF_ID = 1'b1;
Flush_ID_EX = 1'b1;
Flush_IF_ID = 1'b0;
```

의미는 다음과 같습니다.

| 신호 | 동작 |
| --- | --- |
| `Stall_PC=1` | PC를 유지해서 fetch를 멈춥니다. |
| `Stall_IF_ID=1` | IF/ID stage를 유지해서 consumer instruction을 ID에 붙잡아 둡니다. |
| `Flush_ID_EX=1` | ID/EX에 NOP bubble을 넣어 load와 consumer 사이에 한 cycle 간격을 만듭니다. |
| `Flush_IF_ID=0` | load-use는 잘못 가져온 instruction이 아니라 기다려야 하는 instruction이므로 flush하지 않습니다. |

## 3. Control hazard - flush 필요

### 3.1 문제 정의

Control hazard는 branch/jump 때문에 다음 PC가 순차 PC(`PC+4`)가 아닌 값으로 바뀌는 상황입니다. 이 설계에서는 branch/jump redirect가 **EX stage에서 확정**됩니다.

```text
ID stage:
  - JumpImmTarget_ID 생성
  - DestReg_ID 선택
  - Branch/Jump/JumpSel/BrSel control을 ID/EX로 전달

EX stage:
  - BranchComp(Data_rs_EX_fwd, Data_rt_EX_fwd, BrSel_EX)
  - BranchTarget_EX = ALU_Result_EX = PCPlus4_EX + ImmVal_EX  // branch에서 ASel=A_PC4, BSel=B_IMM
  - SelectedJumpTarget_EX = JumpSel_EX ? Data_rs_EX_fwd : JumpImmTarget_EX
  - PCControl이 branch/jump 여부를 보고 redirect 결정
```

### 3.2 EX stage redirect 판정

개념식은 다음과 같습니다.

```verilog
BranchCond_EX = BranchComp(Data_rs_EX_fwd, Data_rt_EX_fwd, BrSel_EX);
PCSel_EX      = pc_control(Branch_EX, Jump_EX, BranchCond_EX);
PCRedirect_EX = valid_EX && (PCSel_EX != PC_PLUS4);

NextPC = (PCRedirect_EX && PCSel_EX == PC_JUMP)   ? SelectedJumpTarget_EX :
         (PCRedirect_EX && PCSel_EX == PC_BRANCH) ? ALU_Result_EX       :
                                                    PCPlus4_IF;
```

`pc_control`은 jump를 branch보다 우선합니다. 정상 decode에서는 branch와 jump가 동시에 1이 되지 않지만, 안전한 우선순위는 다음과 같습니다.

```text
1순위: Jump
2순위: taken Branch
3순위: PC+4
```

### 3.3 Flush 동작

EX stage instruction이 redirect를 결정한 시점에는 그보다 어린 instruction들이 IF/ID, ID/EX에 존재할 수 있습니다. 따라서 redirect가 발생하면 다음 제어를 출력합니다.

```verilog
Flush_IF_ID = 1'b1;
Flush_ID_EX = 1'b1;
Stall_PC    = 1'b0;
Stall_IF_ID = 1'b0;
```

의미는 다음과 같습니다.

| 신호 | 동작 |
| --- | --- |
| `Flush_IF_ID=1` | 잘못 fetch/decode된 younger instruction을 NOP로 바꿉니다. |
| `Flush_ID_EX=1` | ID에 있던 younger instruction이 EX로 들어가지 못하게 NOP bubble을 넣습니다. |
| `Stall_PC=0` | PC는 redirect target으로 갱신되어야 하므로 stall하지 않습니다. |
| `Stall_IF_ID=0` | redirect 시점에는 잘못된 instruction을 유지하면 안 되므로 stall하지 않습니다. |

### 3.4 Redirect와 load-use가 동시에 보일 때의 우선순위

현재 `hazard_unit`은 EX-stage redirect를 load-use stall보다 우선합니다.

```verilog
if (PCRedirect_EX) begin
    Flush_IF_ID = 1'b1;
    Flush_ID_EX = 1'b1;
end else if (load_use_hazard) begin
    Stall_PC    = 1'b1;
    Stall_IF_ID = 1'b1;
    Flush_ID_EX = 1'b1;
end
```

이유는 EX stage instruction이 ID stage instruction보다 오래된 instruction이기 때문입니다. older branch/jump가 redirect를 결정했다면, 현재 ID의 instruction은 잘못된 path의 younger instruction일 수 있으므로 stall보다 flush가 맞습니다.

## 4. 요약

| 항목 | 현재 위치/방식 |
| --- | --- |
| DestReg 선택 | ID stage |
| Jump immediate target 생성 | ID stage |
| Jump register/immediate target 선택 (`JumpSel`) | EX stage |
| Branch Comparator | EX stage |
| Branch target adder | EX stage |
| ALU operand forwarding | EX stage, MEM/WB producer 기준 |
| Branch/jump operand forwarding | 별도 ID forwarding 없음. EX forwarding 공유 |
| Load-use stall | ID instruction source와 EX load destination 비교 |
| Control hazard flush | EX redirect 시 IF/ID + ID/EX flush |
