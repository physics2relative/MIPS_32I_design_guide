# Control Unit

## 역할

Control Unit은 `opcode`와 R-type `funct`를 해석해 datapath selector, memory, register write, branch/jump control을 생성합니다. 모든 block은 이 control signal encoding을 명세서와 동일하게 해석해야 합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `opcode[5:0]` | 6 | Inst Split `Inst[31:26]` | 주 decode key |
| `funct[5:0]` | 6 | Inst Split `Inst[5:0]` | R-type 세부 decode key |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `RegWEn` | 1 | Register | register write enable |
| `DestSel` | 2 | Dest Sel | write register 선택 |
| `ASel` | 2 | A Selector | ALU A 선택 |
| `BSel` | 3 | B Selector | ALU B 선택 |
| `ImmSel` | 3 | Imm Generator | immediate 생성 방식 |
| `BrSel` | 1 | Branch Comp | `0=EQ`, `1=NE` 비교 방식 |
| `ALUSel` | 4 | ALU | ALU operation |
| `WBSel` | 2 | WB selector | write-back source |
| `WdLen` | 2 | Data Memory | memory width |
| `MemRW` | 3 | Data Memory | memory operation |
| `LoadEx` | 1 | Data Memory | load extension |
| `Branch` | 1 | Jump Branch / PCControl | branch instruction 여부 |
| `Jump` | 1 | Jump Branch / PCControl | jump instruction 여부 |
| `JumpSel` | 1 | Jump Sel | jump target source |

## Logisim 설계 가이드

1. 먼저 NOP-safe 기본값을 만듭니다: `RegWEn=0`, `DestSel=DEST_NONE`, `WBSel=WB_NONE`, `ASel=A_ZERO`, `BSel=B_ZERO`, `ImmSel=IMM_NONE`, `BrSel=BR_EQ`, `ALUSel=ALU_NONE`, `WdLen=MEM_NONE`, `MemRW=MEM_IDLE`, `LoadEx=0`, `Branch=0`, `Jump=0`, `JumpSel=0`.
2. opcode별 main decoder를 만들고, `opcode=000000`일 때만 funct decoder를 추가로 사용합니다.
3. R-type ALU는 `DestSel=rd`, `WBSel=ALU`, `RegWEn=1`을 공통으로 두고 funct별 `ALUSel`만 바꿉니다.
4. load/store는 ALU를 address adder로 사용하고, memory control은 `WdLen/MemRW/LoadEx`로 분리합니다.
5. branch는 `ALUSel=ADD`, `ASel=PC+4`, `BSel=branch offset`으로 target을 만들고, compare는 Branch Comp가 수행합니다.
6. jump는 `Jump=1`, `PCSel`은 Jump Branch/PCControl에서 최종 결정합니다.


## 최소 control encoding appendix

Control Unit 구현자는 전체 instruction별 row를 `doc/mips_functional_spec.md`의 `#### 6. 명령어별 단일 사이클 제어 표`와 대조해야 합니다. 아래 표는 block wiring에 필요한 최소 encoding 요약입니다.

### Destination / write-back

| Signal | Encoding | 의미 |
|---|---|---|
| `DestSel` | `00=DEST_RT`, `01=DEST_RD`, `10=DEST_RA`, `11=DEST_NONE` | write register 선택 |
| `WBSel` | `00=WB_MEM`, `01=WB_ALU`, `10=WB_PC4`, `11=WB_NONE` | write-back data 선택 |
| `RegWEn` | `0/1` | register write 여부 |

### ALU operand selector

| Signal | Encoding | 의미 |
|---|---|---|
| `ASel` | `00=A_RS`, `01=A_PC4`, `10=A_ZERO`, `11=A_RT` | ALU A 입력 |
| `BSel` | `000=B_RT`, `001=B_IMM`, `010=B_BR_OFFSET`, `011=B_SHAMT`, `100=B_RS_LOW5`, `101=B_ZERO`, `110=예약`, `111=B_NONE` | ALU B 입력 |
| `ImmSel` | `000=IMM_SIGN16`, `001=IMM_ZERO16`, `010=IMM_LUI16`, `011=IMM_BRANCH16`, `100=IMM_J26`, `111=IMM_NONE` | immediate/decode anchor. 이 guide에서 `IMM_J26`는 J-type decode 표시이며, 32-bit jump target 실제 생성 owner는 Jump Target Gen입니다. |

### Branch / ALU / memory / jump

| Signal | Encoding | 의미 |
|---|---|---|
| `BrSel` | `0=BR_EQ`, `1=BR_NE` | 실제 branch는 `beq/bne`만 사용. branch 여부는 별도 `Branch` control로 gating |
| `ALUSel` | `0000=ADD`, `0001=SUB`, `0010=AND`, `0011=OR`, `0100=XOR`, `0101=SLT`, `0110=SLTU`, `0111=SLL`, `1000=SRL`, `1001=SRA`, `1010=NOR`, `1111=NONE` | ALU operation |
| `WdLen` | `00=MEM_BYTE`, `01=MEM_HALF`, `10=MEM_WORD`, `11=MEM_NONE` | memory 접근 폭 |
| `MemRW` | `000=MEM_SB`, `001=MEM_SH`, `010=MEM_SW`, `011=MEM_LOAD`, `100=MEM_IDLE` | memory 동작 |
| `LoadEx` | `0=LOAD_SIGN`, `1=LOAD_ZERO` | `lb/lh` vs `lbu/lhu`; `lw`는 don't care |
| `JumpSel` | 단일 사이클 `0=JUMP_IMM26`, `1=JUMP_REG` | Jump Sel mux 선택 |
| `Branch`, `Jump` | `0/1` | PCControl 우선순위 입력 |

### Instruction group별 control row anchor

| 그룹 | 정본 명세 anchor | 구현 메모 |
|---|---|---|
| R-type ALU | `##### 6.1 R-type ALU` | `RegWEn=1`, `DestSel=RD`, `WBSel=ALU`, funct별 `ALUSel` |
| Shift | `##### 6.2 Shift` | immediate shift는 `B_SHAMT`, variable shift는 `B_RS_LOW5` |
| I-type ALU / Immediate | `##### 6.3 I-type ALU / Immediate` | logical immediate는 zero-extend, arithmetic/slti는 sign-extend |
| Load | `##### 6.4 Load` | `WBSel=MEM`, `MemRW=LOAD`, width/extension 구분 |
| Store | `##### 6.5 Store` | `RegWEn=0`, `MemRW=SB/SH/SW`, `Data_rt` store |
| Branch | `##### 6.6 Branch` | `Branch=1`, `BrSel=EQ/NE`, `PCSel`은 PCControl이 생성 |
| Jump / Link | `##### 6.7 Jump / Link` | `Jump=1`, `jal`은 `$31`, `jalr`은 `rd`, link data는 `PC+4` |

`IMM_J26`를 쓰더라도 Imm Generator 내부에 32-bit jump target 생성기를 중복 배치하지 않습니다. raw `target26`을 Jump Target Gen으로 보내고, Jump Target Gen이 `{PC+4[31:28], target26, 2'b00}`을 만듭니다.

## 검증 포인트

- 명세서의 38개 구현 instruction이 모두 decode됩니다.
- 제외 14개 instruction은 유효 control row를 만들지 않습니다.
- R-type funct decode에서 `add/addu/sub/subu/and/or/xor/nor/slt/sltu/shift/jr/jalr`가 구분됩니다.
- unknown opcode/funct는 NOP-safe 또는 invalid 처리로 떨어집니다.

## 흔한 실수

- `funct` 입력을 `Inst[10:6]`에 연결하는 실수.
- `Branch`와 `Jump`를 동시에 1로 만들 수 있는 decode를 방치하는 실수.
- `MemRW`와 `WdLen`을 하나의 단순 write-enable로 축소해 byte/half/word store를 잃는 실수.
- `LoadEx`를 `lw`까지 강제해 디버깅을 어렵게 만드는 실수. `lw`는 don't care입니다.

## Caveat / 주의사항

Control Unit은 실제 Logisim에서 PLA/ROM/조합논리 중 어느 방식으로 구현해도 됩니다. 단, selector 입력 순서와 control encoding은 `doc/mips_functional_spec.md`의 표와 반드시 일치해야 합니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
