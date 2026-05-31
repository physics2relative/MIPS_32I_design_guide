# Control Unit ROM 방식 설계 가이드

> 기준 ROM: `Project/ROM/control_unit_opcode_funct_rom.hex`  
> ROM map: `Project/ROM/control_unit_opcode_funct_rom_map.csv`  
> 재생성 스크립트: `tools/control_rom/generate_control_rom.py`  
> 목적: Logisim Control Unit에서 `{opcode[5:0], funct[5:0]}`를 ROM 주소로 사용해 명세서 control table을 바로 출력합니다.

## 1. 핵심 결정

Comparator/decoder로 instruction별 control 신호를 모두 게이트로 만들지 않고, instruction의 `opcode`와 `funct`를 합친 12-bit 값을 ROM 주소로 사용합니다.

```text
Inst Splitter
  opcode[5:0] ----\
                   Join/Splitter -> ROM Addr[11:0] -> Control ROM -> ControlWord[31:0] -> Splitter -> control signals
  funct[5:0]  ----/
```

주소 구성은 다음으로 고정합니다.

```text
Addr[11:6] = opcode[5:0]
Addr[5:0]  = funct[5:0]
Addr       = {opcode, funct}
```

I-type/J-type 명령어는 `funct=Inst[5:0]` 값이 실제 opcode decode에는 의미가 없습니다. 하지만 ROM 주소에는 포함되므로, generator는 해당 opcode의 64개 funct slot을 모두 같은 control word로 채웁니다.

예:

```text
lw opcode = 0x23
lw address range = 0x8C0 ~ 0x8FF
ROM[0x8C0..0x8FF] = lw control word
```

## 2. 바뀐 control 신호 기준

현재 Control Unit ROM은 `MemRW`를 store 폭까지 포함하는 3-bit 신호로 만들지 않습니다.  
메모리 동작 방향은 `MemRW[1:0]`, 접근 폭은 `WdLen[1:0]`으로 분리합니다.

### 2.1 `WdLen[1:0]`

| 값 | 이름 | 의미 |
|---:|---|---|
| `00` | `MEM_BYTE` | byte access |
| `01` | `MEM_HALF` | halfword access |
| `10` | `MEM_WORD` | word access |
| `11` | `MEM_NONE` | memory access 없음 |

### 2.2 `MemRW[1:0]`

| 값 | 이름 | 의미 |
|---:|---|---|
| `00` | `MEM_IDLE` | memory access 없음 |
| `01` | `MEM_LOAD` | load |
| `10` | `MEM_STORE` | store |
| `11` | `RESERVED` | 사용하지 않음 |

따라서 Logisim Data Memory 쪽에서는 다음처럼 decode합니다.

```text
WE     = (MemRW == MEM_STORE)  // MemRW == 2'b10
LoadEn = (MemRW == MEM_LOAD)   // MemRW == 2'b01
폭 선택 = WdLen                // byte/half/word 구분
```

예:

| 명령어 | `WdLen` | `MemRW` | 의미 |
|---|---:|---:|---|
| `lb/lbu` | `00` | `01` | byte load |
| `lh/lhu` | `01` | `01` | halfword load |
| `lw` | `10` | `01` | word load |
| `sb` | `00` | `10` | byte store |
| `sh` | `01` | `10` | halfword store |
| `sw` | `10` | `10` | word store |
| ALU/branch/jump | `11` | `00` | memory 사용 안 함 |

### 2.3 `LoadEx`

| 값 | 의미 |
|---:|---|
| `0` | sign extension (`lb`, `lh`) |
| `1` | zero extension (`lbu`, `lhu`) |

`lw`는 32-bit 전체를 읽으므로 `LoadEx`가 기능적으로 don't-care입니다. 현재 generator에서는 안전하게 `0`으로 둡니다.

## 3. ROM 파일 정보

| 항목 | 값 |
|---|---|
| ROM 파일 | `Project/ROM/control_unit_opcode_funct_rom.hex` |
| ROM map CSV | `Project/ROM/control_unit_opcode_funct_rom_map.csv` |
| Address Bit Width | `12` |
| Data Bit Width | `32` |
| Depth | `4096` words |
| 파일 포맷 | Logisim `v2.0 raw` |

Logisim ROM 설정:

```text
Memory -> ROM
Address Bit Width = 12
Data Bit Width    = 32
```

ROM에 파일을 넣는 방법:

1. ROM component 우클릭
2. `Load Image...` 또는 `Load Contents...`
3. `Project/ROM/control_unit_opcode_funct_rom.hex` 선택

## 4. ControlWord bit layout

ROM output은 32-bit `ControlWord[31:0]`입니다.  
현재 실제 control 신호는 25-bit이고, 나머지 bit는 향후 확장/정렬을 위한 reserved입니다.

| Bit range | Signal | Width | 의미 |
|---:|---|---:|---|
| `[31:27]` | reserved | 5 | 0으로 고정, 사용하지 않음 |
| `[26]` | `RegWEn` | 1 | Register write enable |
| `[25:24]` | `DestSel` | 2 | write register 선택 |
| `[23:22]` | `ASel` | 2 | ALU A input 선택 |
| `[21:19]` | `BSel` | 3 | ALU B input 선택 |
| `[18:17]` | `ImmSel` | 2 | immediate 생성 방식 |
| `[16]` | `BrSel` | 1 | branch comparator EQ/NE 선택 |
| `[15:12]` | `ALUSel` | 4 | ALU 연산 선택 |
| `[11:10]` | `WBSel` | 2 | write-back data 선택 |
| `[9:8]` | `WdLen` | 2 | memory access width |
| `[7]` | reserved | 1 | 0으로 고정, 사용하지 않음 |
| `[6:5]` | `MemRW` | 2 | memory operation direction |
| `[4]` | `LoadEx` | 1 | load sign/zero extension 선택 |
| `[3]` | `Branch` | 1 | branch instruction 여부 |
| `[2]` | `Jump` | 1 | jump instruction 여부 |
| `[1]` | `JumpSel` | 1 | jump target source 선택 |
| `[0]` | reserved | 1 | 0으로 고정, 사용하지 않음 |

ControlWord pack 공식:

```text
ControlWord = {
  5'b00000,       // [31:27] reserved
  RegWEn,         // [26]
  DestSel[1:0],   // [25:24]
  ASel[1:0],      // [23:22]
  BSel[2:0],      // [21:19]
  ImmSel[1:0],    // [18:17]
  BrSel,          // [16]
  ALUSel[3:0],    // [15:12]
  WBSel[1:0],     // [11:10]
  WdLen[1:0],     // [9:8]
  1'b0,           // [7] reserved
  MemRW[1:0],     // [6:5]
  LoadEx,         // [4]
  Branch,         // [3]
  Jump,           // [2]
  JumpSel,        // [1]
  1'b0            // [0] reserved
}
```

> 중요: 이전 구형 구조처럼 `MemRW[2:0]`를 `[7:5]`에 연결하면 안 됩니다. 현재 `[7]`은 reserved이고, `MemRW`는 반드시 `[6:5]` 2-bit만 사용합니다.

## 5. Address bus 만드는 방법

### 5.1 Inst Splitter 출력 준비

Inst Splitter에서 아래 두 신호가 이미 나와 있어야 합니다.

```text
opcode = Inst[31:26]  // 6-bit
funct  = Inst[5:0]    // 6-bit
```

### 5.2 Splitter를 joiner처럼 사용

12-bit address bus를 만들기 위해 `Wiring -> Splitter`를 반대로 사용합니다.

Splitter 설정 예:

| 항목 | 값 |
|---|---|
| `Bit Width In` | `12` |
| `Fan Out` | `2` |
| `Bit 0..5` | output branch 0 |
| `Bit 6..11` | output branch 1 |

연결:

```text
branch 0 -> funct[5:0]   // Addr[5:0]
branch 1 -> opcode[5:0]  // Addr[11:6]
trunk    -> ROM Address
```

검증용 probe:

| Instruction 예 | opcode | funct | 예상 ROM address |
|---|---:|---:|---:|
| `add` | `0x00` | `0x20` | `0x020` |
| `jr` | `0x00` | `0x08` | `0x008` |
| `j` | `0x02` | 임의 | `0x080 ~ 0x0BF` |
| `beq` | `0x04` | 임의 | `0x100 ~ 0x13F` |
| `lw` | `0x23` | 임의 | `0x8C0 ~ 0x8FF` |
| `sw` | `0x2B` | 임의 | `0xAC0 ~ 0xAFF` |

주소가 위와 다르게 나오면 opcode/funct 위치가 뒤집힌 것입니다.

## 6. ControlWord splitter 설정

ROM의 32-bit 출력은 `ControlWord[31:0]`입니다. 이것을 control signal로 나눕니다.

가장 단순한 방법은 32-bit Splitter 하나를 두고 `Fan Out=17`로 설정하는 것입니다.  
`Bit[7]`과 `Bit[0]`, `Bit[31:27]`은 reserved branch로 분리하고 실제 회로에는 연결하지 않습니다.

| Splitter output branch | 연결 bit | 연결할 signal |
|---:|---|---|
| `out0` | `[0]` | reserved, 미사용 |
| `out1` | `[1]` | `JumpSel` |
| `out2` | `[2]` | `Jump` |
| `out3` | `[3]` | `Branch` |
| `out4` | `[4]` | `LoadEx` |
| `out5` | `[6:5]` | `MemRW[1:0]` |
| `out6` | `[7]` | reserved, 미사용 |
| `out7` | `[9:8]` | `WdLen[1:0]` |
| `out8` | `[11:10]` | `WBSel[1:0]` |
| `out9` | `[15:12]` | `ALUSel[3:0]` |
| `out10` | `[16]` | `BrSel` |
| `out11` | `[18:17]` | `ImmSel[1:0]` |
| `out12` | `[21:19]` | `BSel[2:0]` |
| `out13` | `[23:22]` | `ASel[1:0]` |
| `out14` | `[25:24]` | `DestSel[1:0]` |
| `out15` | `[26]` | `RegWEn` |
| `out16` | `[31:27]` | reserved, 미사용 |

Logisim Splitter 속성에서 각 bit를 아래처럼 배정합니다.

| ControlWord bit | Splitter branch |
|---:|---:|
| `0` | `0` |
| `1` | `1` |
| `2` | `2` |
| `3` | `3` |
| `4` | `4` |
| `5` | `5` |
| `6` | `5` |
| `7` | `6` |
| `8` | `7` |
| `9` | `7` |
| `10` | `8` |
| `11` | `8` |
| `12` | `9` |
| `13` | `9` |
| `14` | `9` |
| `15` | `9` |
| `16` | `10` |
| `17` | `11` |
| `18` | `11` |
| `19` | `12` |
| `20` | `12` |
| `21` | `12` |
| `22` | `13` |
| `23` | `13` |
| `24` | `14` |
| `25` | `14` |
| `26` | `15` |
| `27` | `16` |
| `28` | `16` |
| `29` | `16` |
| `30` | `16` |
| `31` | `16` |

> 주의: Splitter branch 번호와 control signal 이름이 헷갈리기 쉬우므로, 각 branch 끝에 반드시 tunnel label을 붙입니다. 예: `RegWEn`, `DestSel`, `ASel`, `BSel`, `ImmSel`, `ALUSel`, `WdLen`, `MemRW`.

## 7. ROM 값 예시

아래 값은 현재 생성된 `Project/ROM/control_unit_opcode_funct_rom_map.csv` 기준입니다.

| 주소 | 의미 | ControlWord |
|---:|---|---:|
| `0x000` | `sll` | `0x05D07700` |
| `0x008` | `jr` | `0x0338FF06` |
| `0x009` | `jalr` | `0x0538FB06` |
| `0x020` | `add` | `0x05000700` |
| `0x022` | `sub` | `0x05001700` |
| `0x080` | `j` range start | `0x03B8FF04` |
| `0x0C0` | `jal` range start | `0x06B8FB04` |
| `0x100` | `beq` range start | `0x034E0F08` |
| `0x140` | `bne` range start | `0x034F0F08` |
| `0x800` | `lb` range start | `0x04080020` |
| `0x900` | `lbu` range start | `0x04080030` |
| `0x8C0` | `lw` range start | `0x04080220` |
| `0xA00` | `sb` range start | `0x03080C40` |
| `0xA40` | `sh` range start | `0x03080D40` |
| `0xAC0` | `sw` range start | `0x03080E40` |
| `0xFC0` | unknown-safe NOP range start | `0x03A0FF00` |

`0x000`이 NOP control word가 아니라 `sll` control word인 이유는 MIPS에서 `0x00000000`이 `sll $0,$0,0`으로 decode되기 때문입니다. Register File이 `$zero` write를 무시하므로 실제로는 NOP처럼 동작합니다.

## 8. 대표 명령어별 확인 포인트

| 명령어 | 확인할 ROM output |
|---|---|
| `lw` | `RegWEn=1`, `WBSel=WB_MEM`, `WdLen=MEM_WORD(10)`, `MemRW=MEM_LOAD(01)` |
| `lb` | `WdLen=MEM_BYTE(00)`, `MemRW=MEM_LOAD(01)`, `LoadEx=0` |
| `lbu` | `WdLen=MEM_BYTE(00)`, `MemRW=MEM_LOAD(01)`, `LoadEx=1` |
| `sw` | `RegWEn=0`, `WdLen=MEM_WORD(10)`, `MemRW=MEM_STORE(10)` |
| `sb` | `RegWEn=0`, `WdLen=MEM_BYTE(00)`, `MemRW=MEM_STORE(10)` |
| `beq` | `Branch=1`, `BrSel=BR_EQ(0)`, `MemRW=MEM_IDLE(00)` |
| `bne` | `Branch=1`, `BrSel=BR_NE(1)`, `MemRW=MEM_IDLE(00)` |
| `j/jal` | `Jump=1`, `JumpSel=0` |
| `jr/jalr` | `Jump=1`, `JumpSel=1` |
| unsupported | `RegWEn=0`, `WBSel=WB_NONE`, `ALUSel=ALU_NONE`, `MemRW=MEM_IDLE(00)` |

## 9. 재생성 방법

ROM은 수동 작성하지 말고 Python generator로 재생성합니다.

```bash
cd /user/choi.jw/PROJECT/MIPS_logisim
python3 tools/control_rom/generate_control_rom.py
```

생성물:

```text
Project/ROM/control_unit_opcode_funct_rom.hex
Project/ROM/control_unit_opcode_funct_rom_map.csv
```

`*_map.csv`는 instruction별 address range와 control word를 확인하기 위한 사람이 읽는 표입니다. Logisim에 load하는 파일은 `.hex`입니다.

## 10. 검증 체크리스트

1. ROM Address width가 12인지 확인합니다.
2. ROM Data width가 32인지 확인합니다.
3. address가 `{opcode, funct}` 순서인지 probe로 확인합니다.
4. `lw` instruction을 넣었을 때 address가 `0x8C0~0x8FF` 범위인지 확인합니다.
5. `add` instruction을 넣었을 때 address가 `0x020`인지 확인합니다.
6. ROM output splitter에서 `RegWEn`이 bit 26에서 나오는지 확인합니다.
7. ROM output splitter에서 `MemRW`가 `[6:5]` 2-bit로만 나오는지 확인합니다.
8. `Bit[7]` reserved를 Data Memory에 연결하지 않았는지 확인합니다.
9. `sw/sh/sb`에서 `MemRW=MEM_STORE(10)`이고 store 폭은 `WdLen=WORD/HALF/BYTE`로 나뉘는지 확인합니다.
10. `lw/lh/lb/lhu/lbu`에서 `MemRW=MEM_LOAD(01)`이고 load 폭은 `WdLen`으로 나뉘는지 확인합니다.
11. unsupported instruction은 `RegWEn=0`, `MemRW=MEM_IDLE`, `ALUSel=ALU_NONE`, `WBSel=WB_NONE`인지 확인합니다.

## 11. 이 방식의 의미

이 Control Unit은 전형적인 gate-only hardwired control이라기보다, **opcode/funct direct-addressed control ROM** 방식입니다. 과제 설명에서는 다음처럼 말하면 됩니다.

> opcode와 funct를 합친 12-bit 값을 control ROM address로 사용하고, ROM에는 명세서의 instruction별 control word를 저장했다. I/J-type은 funct field가 don't-care이므로 해당 opcode의 64개 ROM entry를 같은 control word로 채웠다. ROM output은 splitter로 각 control signal에 분배된다. 메모리 제어는 `MemRW[1:0]`가 idle/load/store 방향을 담당하고, `WdLen[1:0]`가 byte/half/word 폭을 담당하도록 분리했다.
