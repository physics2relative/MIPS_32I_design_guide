# Control Unit Comparator 방식 설계 가이드

> 기준: `doc/mips_functional_spec.md`, `HDL/Single_Cycle/rtl/core/control_unit.v`  
> 목적: Logisim에서 6-bit decoder 제한을 피하고, `opcode/funct comparator -> instruction one-hot -> control signal` 구조로 Control Unit을 사람이 읽기 쉽게 구현합니다.

## 1. 전체 구조

Logisim 기본 Decoder는 5-bit까지만 편하게 다룰 수 있으므로, MIPS의 6-bit `opcode`, 6-bit `funct`는 **Comparator**로 직접 비교하는 방식을 권장합니다.

```text
opcode[5:0] -> 6-bit comparator bank -> op_* 신호
funct[5:0]  -> 6-bit comparator bank -> fn_*_raw 신호

op_rtype AND fn_*_raw -> R-type is_* 신호
op_*                  -> I/J-type is_* 신호

is_* 신호들 -> group 신호 -> control output bit 생성
```

Logisim에서 각 comparator는 다음처럼 설정합니다.

| 항목 | 설정 |
|---|---|
| 위치 | `Arithmetic -> Comparator` |
| `Data Bits` | 6 |
| A 입력 | `opcode[5:0]` 또는 `funct[5:0]` |
| B 입력 | 6-bit Constant |
| 사용하는 출력 | `A = B` 출력만 사용 |

Comparator 출력에는 반드시 tunnel/label을 붙입니다. 예: `op_lw`, `fn_add_raw`, `is_add`.

## 2. Opcode comparator output 전체 목록

아래 comparator들은 모두 `opcode[5:0]`을 A 입력에, 표의 constant를 B 입력에 넣고, `A=B` 출력을 사용합니다.

| Constant | Comparator output | 의미 | 다음 연결 |
|---:|---|---|---|
| `6'h00` | `op_rtype` | R-type instruction group | 모든 `fn_*_raw`와 AND하여 R-type `is_*` 생성 |
| `6'h02` | `op_j` | `j` | `is_j = op_j` |
| `6'h03` | `op_jal` | `jal` | `is_jal = op_jal` |
| `6'h04` | `op_beq` | `beq` | `is_beq = op_beq` |
| `6'h05` | `op_bne` | `bne` | `is_bne = op_bne` |
| `6'h08` | `op_addi` | `addi` | `is_addi = op_addi` |
| `6'h09` | `op_addiu` | `addiu` | `is_addiu = op_addiu` |
| `6'h0A` | `op_slti` | `slti` | `is_slti = op_slti` |
| `6'h0B` | `op_sltiu` | `sltiu` | `is_sltiu = op_sltiu` |
| `6'h0C` | `op_andi` | `andi` | `is_andi = op_andi` |
| `6'h0D` | `op_ori` | `ori` | `is_ori = op_ori` |
| `6'h0E` | `op_xori` | `xori` | `is_xori = op_xori` |
| `6'h0F` | `op_lui` | `lui` | `is_lui = op_lui` |
| `6'h20` | `op_lb` | `lb` | `is_lb = op_lb` |
| `6'h21` | `op_lh` | `lh` | `is_lh = op_lh` |
| `6'h23` | `op_lw` | `lw` | `is_lw = op_lw` |
| `6'h24` | `op_lbu` | `lbu` | `is_lbu = op_lbu` |
| `6'h25` | `op_lhu` | `lhu` | `is_lhu = op_lhu` |
| `6'h28` | `op_sb` | `sb` | `is_sb = op_sb` |
| `6'h29` | `op_sh` | `sh` | `is_sh = op_sh` |
| `6'h2B` | `op_sw` | `sw` | `is_sw = op_sw` |

### Opcode comparator 배치 팁

- 같은 `opcode[5:0]` bus를 모든 opcode comparator A 입력으로 fan-out합니다.
- 각 comparator B 입력에는 `Wiring -> Constant`를 붙이고 `Data Bits=6`, `Value=0xXX`로 설정합니다.
- comparator의 `A=B` 출력만 tunnel로 빼고, `<`, `>` 출력은 사용하지 않습니다.
- wire가 복잡해지면 `opcode` 입력 bus와 comparator output은 tunnel로 처리합니다.

## 3. Funct comparator output 전체 목록

아래 comparator들은 모두 `funct[5:0]`을 A 입력에, 표의 constant를 B 입력에 넣고, `A=B` 출력을 사용합니다. 단, raw funct 비교 결과만으로 instruction을 확정하면 안 됩니다. 반드시 `op_rtype`과 AND해야 합니다.

| Constant | Raw comparator output | 최종 instruction one-hot | 의미 |
|---:|---|---|---|
| `6'h00` | `fn_sll_raw` | `is_sll  = op_rtype AND fn_sll_raw` | `sll` |
| `6'h02` | `fn_srl_raw` | `is_srl  = op_rtype AND fn_srl_raw` | `srl` |
| `6'h03` | `fn_sra_raw` | `is_sra  = op_rtype AND fn_sra_raw` | `sra` |
| `6'h04` | `fn_sllv_raw` | `is_sllv = op_rtype AND fn_sllv_raw` | `sllv` |
| `6'h06` | `fn_srlv_raw` | `is_srlv = op_rtype AND fn_srlv_raw` | `srlv` |
| `6'h07` | `fn_srav_raw` | `is_srav = op_rtype AND fn_srav_raw` | `srav` |
| `6'h08` | `fn_jr_raw` | `is_jr   = op_rtype AND fn_jr_raw` | `jr` |
| `6'h09` | `fn_jalr_raw` | `is_jalr = op_rtype AND fn_jalr_raw` | `jalr` |
| `6'h20` | `fn_add_raw` | `is_add  = op_rtype AND fn_add_raw` | `add` |
| `6'h21` | `fn_addu_raw` | `is_addu = op_rtype AND fn_addu_raw` | `addu` |
| `6'h22` | `fn_sub_raw` | `is_sub  = op_rtype AND fn_sub_raw` | `sub` |
| `6'h23` | `fn_subu_raw` | `is_subu = op_rtype AND fn_subu_raw` | `subu` |
| `6'h24` | `fn_and_raw` | `is_and  = op_rtype AND fn_and_raw` | `and` |
| `6'h25` | `fn_or_raw` | `is_or   = op_rtype AND fn_or_raw` | `or` |
| `6'h26` | `fn_xor_raw` | `is_xor  = op_rtype AND fn_xor_raw` | `xor` |
| `6'h27` | `fn_nor_raw` | `is_nor  = op_rtype AND fn_nor_raw` | `nor` |
| `6'h2A` | `fn_slt_raw` | `is_slt  = op_rtype AND fn_slt_raw` | `slt` |
| `6'h2B` | `fn_sltu_raw` | `is_sltu = op_rtype AND fn_sltu_raw` | `sltu` |

### Funct comparator 주의점

`funct` field는 R-type에서만 의미가 있습니다. 예를 들어 I-type 명령어의 하위 6-bit가 우연히 `6'h20`이어도 `add`가 아닙니다. 따라서 다음 구조를 반드시 지킵니다.

```text
funct == 6'h20 -> fn_add_raw
op_rtype AND fn_add_raw -> is_add
```

## 4. Instruction one-hot 신호

### R-type one-hot

```text
is_add  = op_rtype AND fn_add_raw
is_addu = op_rtype AND fn_addu_raw
is_sub  = op_rtype AND fn_sub_raw
is_subu = op_rtype AND fn_subu_raw
is_and  = op_rtype AND fn_and_raw
is_or   = op_rtype AND fn_or_raw
is_xor  = op_rtype AND fn_xor_raw
is_nor  = op_rtype AND fn_nor_raw
is_slt  = op_rtype AND fn_slt_raw
is_sltu = op_rtype AND fn_sltu_raw

is_sll  = op_rtype AND fn_sll_raw
is_srl  = op_rtype AND fn_srl_raw
is_sra  = op_rtype AND fn_sra_raw
is_sllv = op_rtype AND fn_sllv_raw
is_srlv = op_rtype AND fn_srlv_raw
is_srav = op_rtype AND fn_srav_raw

is_jr   = op_rtype AND fn_jr_raw
is_jalr = op_rtype AND fn_jalr_raw
```

### I/J-type one-hot

```text
is_j     = op_j
is_jal   = op_jal
is_beq   = op_beq
is_bne   = op_bne
is_addi  = op_addi
is_addiu = op_addiu
is_slti  = op_slti
is_sltiu = op_sltiu
is_andi  = op_andi
is_ori   = op_ori
is_xori  = op_xori
is_lui   = op_lui
is_lb    = op_lb
is_lh    = op_lh
is_lw    = op_lw
is_lbu   = op_lbu
is_lhu   = op_lhu
is_sb    = op_sb
is_sh    = op_sh
is_sw    = op_sw
```

## 5. Group 신호 만들기

Control output을 직접 38개 instruction에서 OR하면 회로가 지저분합니다. 먼저 group 신호를 만듭니다.

```text
g_r_alu = is_add OR is_addu OR is_sub OR is_subu
       OR is_and OR is_or OR is_xor OR is_nor
       OR is_slt OR is_sltu

g_shift_imm = is_sll OR is_srl OR is_sra
g_shift_var = is_sllv OR is_srlv OR is_srav
g_shift     = g_shift_imm OR g_shift_var

g_i_logic = is_andi OR is_ori OR is_xori
g_i_alu   = is_addi OR is_addiu OR is_slti OR is_sltiu OR g_i_logic OR is_lui

g_load  = is_lb OR is_lbu OR is_lh OR is_lhu OR is_lw
g_store = is_sb OR is_sh OR is_sw
g_mem   = g_load OR g_store

g_branch = is_beq OR is_bne
g_jump   = is_j OR is_jal OR is_jr OR is_jalr
g_reg_jump = is_jr OR is_jalr

g_write_alu = g_r_alu OR g_shift OR g_i_alu
g_write_pc4 = is_jal OR is_jalr
g_write     = g_write_alu OR g_load OR g_write_pc4
```

Unsupported instruction을 안전한 NOP로 만들기 위해 `known_instr`도 만듭니다.

```text
known_instr = g_r_alu OR g_shift OR g_i_alu OR g_load OR g_store OR g_branch OR g_jump
unknown_instr = NOT known_instr
```

`unknown_instr`는 NOP-safe default를 만들 때 사용합니다.

## 6. 1-bit control output 연결

| Control | 회로 연결 |
|---|---|
| `RegWEn` | `g_write` |
| `Branch` | `g_branch` |
| `BrSel` | `is_bne` (`0=EQ`, `1=NE`) |
| `Jump` | `g_jump` |
| `JumpSel` | `g_reg_jump` (`0=JumpImmTarget`, `1=Data_rs`) |
| `LoadEx` | `is_lbu OR is_lhu` (`1=zero extension`) |

주의: `Jump`를 Jump Sel mux selector로 쓰면 안 됩니다. `Jump`는 `j/jal/jr/jalr`에서 모두 1이고, `JumpSel`만 immediate target과 register target을 구분합니다.

## 7. Multi-bit control output 연결

아래 식은 bit별로 1-bit wire를 만든 뒤, Splitter를 반대로 사용해 bus로 묶는 방식입니다. Logisim에서는 `Splitter`의 `Bit Width In`을 control 폭에 맞추고, 각 bit wire를 해당 bit에 연결합니다.

### 7.1 `DestSel[1:0]`

Encoding:

```text
00 = DEST_RT
01 = DEST_RD
10 = DEST_RA
11 = DEST_NONE
```

Group:

```text
dest_rt   = g_i_alu OR g_load
dest_rd   = g_r_alu OR g_shift OR is_jalr
dest_ra   = is_jal
dest_none = NOT RegWEn
```

Bit 연결:

```text
DestSel[1] = dest_ra OR dest_none
DestSel[0] = dest_rd OR dest_none
```

### 7.2 `WBSel[1:0]`

Encoding:

```text
00 = WB_MEM
01 = WB_ALU
10 = WB_PC4
11 = WB_NONE
```

Group:

```text
wb_mem  = g_load
wb_alu  = g_write_alu
wb_pc4  = g_write_pc4
wb_none = NOT RegWEn
```

Bit 연결:

```text
WBSel[1] = wb_pc4 OR wb_none
WBSel[0] = wb_alu OR wb_none
```

### 7.3 `ASel[1:0]`

Encoding:

```text
00 = A_RS
01 = A_PC4
10 = A_ZERO
11 = A_RT
```

Group:

```text
a_pc4  = g_branch
a_rt   = g_shift
a_zero = is_lui OR is_j OR is_jal OR unknown_instr
```

그 외 R-type ALU, I-type ALU, load/store, `jr/jalr`는 자연스럽게 `A_RS(00)`입니다.

Bit 연결:

```text
ASel[1] = a_zero OR a_rt
ASel[0] = a_pc4 OR a_rt
```

### 7.4 `BSel[2:0]`

Encoding:

```text
000 = B_RT
001 = B_IMM
010 = B_SHAMT
011 = B_RS_LOW5
100 = B_ZERO
111 = B_NONE
```

Group:

```text
b_imm     = g_i_alu OR g_load OR g_store OR g_branch
b_shamt   = g_shift_imm
b_rs_low5 = g_shift_var
b_none    = g_jump
b_zero    = unknown_instr
```

그 외 R-type ALU는 자연스럽게 `B_RT(000)`입니다.

Bit 연결:

```text
BSel[2] = b_zero OR b_none
BSel[1] = b_shamt OR b_rs_low5 OR b_none
BSel[0] = b_imm OR b_rs_low5 OR b_none
```

### 7.5 `ImmSel[1:0]`

Encoding:

```text
00 = IMM_SIGN16
01 = IMM_ZERO16
10 = IMM_LUI16
11 = IMM_BRANCH16
```

Bit 연결:

```text
ImmSel[1] = is_lui OR g_branch
ImmSel[0] = g_i_logic OR g_branch
```

검증:

| 명령어 그룹 | ImmSel |
|---|---|
| `addi/addiu/slti/sltiu/load/store` | `00 SIGN16` |
| `andi/ori/xori` | `01 ZERO16` |
| `lui` | `10 LUI16` |
| `beq/bne` | `11 BRANCH16` |

### 7.6 `ALUSel[3:0]`

Encoding:

```text
0000 = ALU_ADD
0001 = ALU_SUB
0010 = ALU_AND
0011 = ALU_OR
0100 = ALU_XOR
0101 = ALU_SLT
0110 = ALU_SLTU
0111 = ALU_SLL
1000 = ALU_SRL
1001 = ALU_SRA
1010 = ALU_NOR
1111 = ALU_NONE
```

먼저 ALU operation group을 만듭니다.

```text
alu_add  = is_add OR is_addu OR is_addi OR is_addiu OR is_lui OR g_load OR g_store OR g_branch
alu_sub  = is_sub OR is_subu
alu_and  = is_and OR is_andi
alu_or   = is_or OR is_ori
alu_xor  = is_xor OR is_xori
alu_slt  = is_slt OR is_slti
alu_sltu = is_sltu OR is_sltiu
alu_sll  = is_sll OR is_sllv
alu_srl  = is_srl OR is_srlv
alu_sra  = is_sra OR is_srav
alu_nor  = is_nor
alu_none = g_jump OR unknown_instr
```

Bit 연결:

```text
ALUSel[3] = alu_srl OR alu_sra OR alu_nor OR alu_none
ALUSel[2] = alu_xor OR alu_slt OR alu_sltu OR alu_sll OR alu_none
ALUSel[1] = alu_and OR alu_or OR alu_sltu OR alu_sll OR alu_nor OR alu_none
ALUSel[0] = alu_sub OR alu_or OR alu_slt OR alu_sll OR alu_sra OR alu_none
```

### 7.7 `WdLen[1:0]`

Encoding:

```text
00 = MEM_BYTE
01 = MEM_HALF
10 = MEM_WORD
11 = MEM_NONE
```

Group:

```text
wd_byte = is_lb OR is_lbu OR is_sb
wd_half = is_lh OR is_lhu OR is_sh
wd_word = is_lw OR is_sw
wd_none = NOT g_mem
```

Bit 연결:

```text
WdLen[1] = wd_word OR wd_none
WdLen[0] = wd_half OR wd_none
```

### 7.8 `MemRW[1:0]`

Encoding:

```text
00 = MEM_IDLE
01 = MEM_LOAD
10 = MEM_STORE
11 = reserved
```

Group:

```text
mem_store = g_store
mem_load  = g_load
mem_idle  = NOT g_mem
```

Bit 연결:

```text
MemRW[1] = mem_store
MemRW[0] = mem_load
```

`sb/sh/sw`의 byte/half/word 구분은 `MemRW`가 아니라 `WdLen[1:0]`의 `MEM_BYTE/MEM_HALF/MEM_WORD` 값으로 결정합니다.

## 8. Logisim에서 bus output 만드는 방법

Multi-bit control은 bit별 equation으로 만든 뒤 bus로 합칩니다.

예: `ImmSel[1:0]`

```text
ImmSel_1 = is_lui OR g_branch
ImmSel_0 = g_i_logic OR g_branch

ImmSel_1 ----\
              Splitter/Joiner -> ImmSel[1:0]
ImmSel_0 ----/
```

Logisim Splitter 설정 예:

| 항목 | 값 |
|---|---|
| `Bit Width In` | 출력 bus 폭, 예: `2` |
| `Fan Out` | 출력 bit 수, 예: `2` |
| bit 0 | `ImmSel_0` 연결 |
| bit 1 | `ImmSel_1` 연결 |

`ALUSel[3:0]`, `BSel[2:0]`, `MemRW[1:0]`도 같은 방식으로 묶습니다.

## 9. 회로 배치 추천

Control Unit 내부를 아래처럼 영역으로 나누면 디버깅이 쉽습니다.

```text
[왼쪽]   opcode[5:0], funct[5:0] 입력
[상단]   opcode comparator bank -> op_* tunnel
[중단]   funct comparator bank  -> fn_*_raw tunnel
[중단R]  is_* instruction one-hot 생성
[오른쪽] group 신호 생성
[최우측] control output bit 생성 + Splitter로 bus 출력
```

추천 tunnel 이름:

```text
op_lw, op_sw, op_beq, op_jal
fn_add_raw, fn_jr_raw
is_add, is_lw, is_jalr
g_load, g_store, g_branch, g_jump
ALUSel_0, ALUSel_1, ALUSel_2, ALUSel_3
```

OR gate 입력이 너무 많으면 Logisim gate의 `Number of Inputs`를 늘리거나, 2~4입력 OR tree로 나눕니다.

## 10. 검증 체크리스트

1. `op_rtype`이 1일 때만 R-type `is_*`가 켜지는지 확인합니다.
2. `is_jr/is_jalr`에서 `Jump=1`, `JumpSel=1`인지 확인합니다.
3. `is_j/is_jal`에서 `Jump=1`, `JumpSel=0`인지 확인합니다.
4. `beq/bne`에서 `Branch=1`, `BrSel`은 각각 `0/1`인지 확인합니다.
5. `lbu/lhu`에서만 `LoadEx=1`인지 확인합니다.
6. `sw/sh/sb`에서 `RegWEn=0`, `MemRW=MEM_STORE(10)`이고 `WdLen`이 각각 `WORD/HALF/BYTE`인지 확인합니다.
7. unsupported opcode/funct에서 `RegWEn=0`, `WBSel=WB_NONE`, `MemRW=MEM_IDLE`, `ALUSel=ALU_NONE`가 되는지 확인합니다.
8. `test_vectors/generated/control_unit/`의 control vector와 Logisim 출력이 일치하는지 확인합니다.

## 11. 구현상 주의사항

- `sll $0, $0, 0`은 기계어 `0x00000000`이고 R-type `sll`로 decode됩니다. Register File이 `$zero` write를 무시하므로 NOP처럼 동작합니다.
- `jalr`은 현재 명세 기준 `DestSel=DEST_RD`입니다. `$31` 고정이 아니라 instruction의 `rd` field로 link를 씁니다.
- `JumpSel`은 jump 여부가 아니라 target source selector입니다. `Jump`와 분리해서 배선합니다.
- J-type `target26`은 Imm Generator로 보내지 않고 Jump Target Generator로 직접 보냅니다.
- Comparator output은 one-hot이 아닐 수 있는 raw 단계가 있습니다. 특히 `fn_*_raw`는 반드시 `op_rtype`과 AND한 뒤 사용합니다.
