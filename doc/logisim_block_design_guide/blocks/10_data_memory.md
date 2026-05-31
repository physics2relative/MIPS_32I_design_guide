# Data Memory

## 역할

Data Memory는 `lb/lbu/lh/lhu/lw`와 `sb/sh/sw`의 byte/half/word memory 접근을 처리합니다. 주소는 ALU 결과인 `Addr=ALUResult`를 사용하고, store data는 Register File의 `Data_rt`에서 옵니다.

현재 Logisim single-cycle 회로에서는 **2-port RAM의 read port가 주소 변화에 대해 async로 읽히는 구조**를 사용합니다. 따라서 RAM 자체는 32-bit word array로 두고, byte/half/word 선택과 sign/zero extension은 Data Memory 블록 내부 조합 로직으로 구현합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Addr` | 32 | ALUResult | data memory byte address |
| `Data_rt` / store data | 32 | Register File | store할 원본 data |
| `WdLen` | 2 | Control Unit | byte/half/word 접근 폭 |
| `MemRW` | 2 | Control Unit | idle/load/store 동작 방향 |
| `LoadEx` | 1 | Control Unit | load sign/zero extension 선택 |
| `clk` | 1 | top level | store write clock |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `Data_RD` | 32 | WB selector | load 결과. `lb/lh`는 sign-extend, `lbu/lhu`는 zero-extend된 32-bit 값 |
| `MisalignedAccess` | 1 | debug/test probe | half/word misaligned access 감지. CPU 제어에는 사용하지 않는 관찰용 신호 |

## Control encoding

| 신호 | 값 | 이름 | 의미 |
|---|---:|---|---|
| `MemRW` | `00` | `MEM_IDLE` | memory 접근 없음 |
| `MemRW` | `01` | `MEM_LOAD` | load |
| `MemRW` | `10` | `MEM_STORE` | store |
| `MemRW` | `11` | `RESERVED` | 사용하지 않음. idle처럼 처리 권장 |
| `WdLen` | `00` | `MEM_BYTE` | byte 접근 |
| `WdLen` | `01` | `MEM_HALF` | halfword 접근 |
| `WdLen` | `10` | `MEM_WORD` | word 접근 |
| `WdLen` | `11` | `MEM_NONE` | memory 접근 없음 |
| `LoadEx` | `0` | sign | `lb/lh` sign extension |
| `LoadEx` | `1` | zero | `lbu/lhu` zero extension |

기본 enable은 다음처럼 만듭니다.

```text
LoadEn  = (MemRW == MEM_LOAD)   // MemRW == 2'b01
StoreEn = (MemRW == MEM_STORE)  // MemRW == 2'b10

HalfMisaligned = (WdLen == MEM_HALF) & Addr[0]
WordMisaligned = (WdLen == MEM_WORD) & (Addr[1] | Addr[0])
MisalignedAccess = (LoadEn | StoreEn) & (HalfMisaligned | WordMisaligned)

EffectiveLoadEn  = LoadEn  & ~MisalignedAccess
EffectiveStoreEn = StoreEn & ~MisalignedAccess
WE = EffectiveStoreEn & (WdLen != MEM_NONE)
```

## `lane`이란?

`lane`은 **32-bit word 안에서 몇 번째 byte를 선택할지 나타내는 byte offset**입니다.

```text
WordAddr = Addr[31:2]  // RAM word address
Lane     = Addr[1:0]   // selected byte lane within that word
```

Data Memory는 32-bit word 단위로 저장하지만, MIPS load/store 주소는 byte address입니다. 따라서 하위 2비트 `Addr[1:0]`를 따로 떼어 byte 위치를 선택해야 합니다. 이 값이 `lane`입니다.

Little-endian 기준 byte lane은 다음과 같습니다.

| `Lane = Addr[1:0]` | word 내부 bit | byte address 의미 | 예: word=`0xAABBCCDD` |
|---:|---:|---|---:|
| `00` | `[7:0]` | base + 0 | `0xDD` |
| `01` | `[15:8]` | base + 1 | `0xCC` |
| `10` | `[23:16]` | base + 2 | `0xBB` |
| `11` | `[31:24]` | base + 3 | `0xAA` |

즉 `lane`은 별도의 memory가 아니라 **address 하위 2비트에서 나온 선택 신호**입니다.

- byte load/store: `lane[1:0]` 전체를 사용해 4개 byte 중 하나 선택
- half load/store: `lane[1]`만 사용해 lower half / upper half 선택
- word load/store: `lane`을 사용하지 않고 32-bit 전체 접근

> 현재 프로젝트는 exception/trap을 구현하지 않습니다. 대신 `lh/lhu/sh`에서 `Addr[0]=1`이거나 `lw/sw`에서 `Addr[1:0] != 00`이면 misaligned access로 보고 **idle 처리**합니다. misaligned load는 `Data_RD=0`, misaligned store는 `WE=0`으로 memory를 변경하지 않습니다. byte 접근은 모든 lane에서 aligned로 취급합니다.

## 2-port RAM 기반 전체 구조

Logisim RAM은 32-bit word storage로 설정합니다.

```text
Addr[31:2] ───────────────┐
                          │
                    +-----▼------+
LoadEn/StoreEn      | 2-port RAM |
clk ───────────────►|           |
StoreWord ─────────►| store port|
ReadWord ◄──────────| load port |
                    +-----▲------+
                          │
Addr[1:0] = lane ─────────┘
```

권장 설정:

| 항목 | 값 |
|---|---|
| RAM data width | `32` |
| RAM address | `WordAddr = Addr[31:2]` 중 필요한 하위 bit |
| load/read port address | `WordAddr` |
| store/write port address | `WordAddr` |
| store/write data | `StoreWord` |
| store/write enable | `WE = EffectiveStoreEn & (WdLen != MEM_NONE)` |

중요한 점은 RAM 주소에 `Addr[31:0]` 전체를 넣지 않는 것입니다. RAM이 32-bit word array라면 RAM address는 word index이고, byte 위치는 `lane=Addr[1:0]`가 따로 담당합니다.

## Load path 설계

### 1. RAM read word

2-port RAM의 read port output을 `ReadWord[31:0]`라고 둡니다.

### 2. byte 선택

`lane[1:0]`을 selector로 하는 4-to-1 mux를 둡니다.

| lane | `SelectedByte` |
|---:|---|
| `00` | `ReadWord[7:0]` |
| `01` | `ReadWord[15:8]` |
| `10` | `ReadWord[23:16]` |
| `11` | `ReadWord[31:24]` |

### 3. half 선택

`lane[1]`을 selector로 하는 2-to-1 mux를 둡니다.

| `lane[1]` | `SelectedHalf` |
|---:|---|
| `0` | `ReadWord[15:0]` |
| `1` | `ReadWord[31:16]` |

### 4. sign/zero extension

`LoadEx` convention은 다음입니다.

```text
LoadEx = 0 -> sign extension
LoadEx = 1 -> zero extension
```

구현은 두 값을 모두 만들어 mux로 고르는 방식이 쉽습니다.

```text
ByteSignExt = {{24{SelectedByte[7]}}, SelectedByte}
ByteZeroExt = {24'b0, SelectedByte}
ByteExt     = (LoadEx == 0) ? ByteSignExt : ByteZeroExt

HalfSignExt = {{16{SelectedHalf[15]}}, SelectedHalf}
HalfZeroExt = {16'b0, SelectedHalf}
HalfExt     = (LoadEx == 0) ? HalfSignExt : HalfZeroExt
```

Logisim에서는 `Extender`를 쓰거나, sign bit 복제 + splitter/joiner + mux로 직접 만들면 됩니다. dynamic sign/zero 선택이 헷갈리면 `SignExt`와 `ZeroExt`를 따로 만든 뒤 `LoadEx` mux로 선택하는 방식이 가장 안전합니다.

### 5. WdLen으로 최종 load data 선택

```text
if WdLen == MEM_BYTE: LoadData = ByteExt
if WdLen == MEM_HALF: LoadData = HalfExt
if WdLen == MEM_WORD: LoadData = ReadWord
else:                 LoadData = 0

Data_RD = EffectiveLoadEn ? LoadData : 0
```

`Data_RD`는 non-load에서는 WB에서 사용되지 않지만, test/debug를 쉽게 하기 위해 `EffectiveLoadEn=0`이면 `0`을 내보내는 것을 권장합니다. misaligned load도 여기 포함되어 `0`을 반환합니다.

## Store path 설계

Logisim RAM에 byte write enable이 없거나 쓰기 동작이 복잡하다면, **read-modify-write 방식으로 32-bit 전체 word를 만들어 쓰는 방식**이 가장 단순합니다.

```text
ReadWord + Data_rt + WdLen + lane
        ↓
    StoreWord 생성
        ↓
2-port RAM store data에 32-bit 전체 write
```

### 1. byte store merge

`sb`는 `Data_rt[7:0]`만 선택된 byte lane에 쓰고, 나머지 byte는 기존 `ReadWord`를 보존합니다.

| lane | `ByteMerged` |
|---:|---|
| `00` | `{ReadWord[31:8],  Data_rt[7:0]}` |
| `01` | `{ReadWord[31:16], Data_rt[7:0], ReadWord[7:0]}` |
| `10` | `{ReadWord[31:24], Data_rt[7:0], ReadWord[15:0]}` |
| `11` | `{Data_rt[7:0],    ReadWord[23:0]}` |

### 2. half store merge

`sh`는 `Data_rt[15:0]`를 lower half 또는 upper half에 쓰고, 반대쪽 half는 보존합니다.

| `lane[1]` | `HalfMerged` |
|---:|---|
| `0` | `{ReadWord[31:16], Data_rt[15:0]}` |
| `1` | `{Data_rt[15:0],   ReadWord[15:0]}` |

### 3. word store merge

`sw`는 32-bit 전체를 씁니다.

```text
WordMerged = Data_rt
```

### 4. WdLen으로 store word 선택

```text
if WdLen == MEM_BYTE: StoreWord = ByteMerged
if WdLen == MEM_HALF: StoreWord = HalfMerged
if WdLen == MEM_WORD: StoreWord = Data_rt
else:                 StoreWord = ReadWord
```

RAM write enable은 `EffectiveStoreEn & (WdLen != MEM_NONE)`로 둡니다. 그러면 `MEM_NONE`, `MEM_IDLE`, misaligned store에서 실수로 write되지 않습니다.

## Selection 신호별 동작 표

| `MemRW` | `WdLen` | alignment 조건 | 동작 | 주요 선택 신호 |
|---:|---:|---|---|---|
| `00 IDLE` | any | - | read/write 없음. `Data_RD=0` 권장 | 없음 |
| `01 LOAD` | `00 BYTE` | 항상 aligned | `lane`으로 byte 선택 후 sign/zero extend | `lane[1:0]`, `LoadEx` |
| `01 LOAD` | `01 HALF` | `Addr[0]=0` | `lane[1]`으로 half 선택 후 sign/zero extend | `lane[1]`, `LoadEx` |
| `01 LOAD` | `01 HALF` | `Addr[0]=1` | misaligned idle. `Data_RD=0` | `MisalignedAccess` |
| `01 LOAD` | `10 WORD` | `Addr[1:0]=00` | 32-bit word 전체 읽기 | 없음 |
| `01 LOAD` | `10 WORD` | `Addr[1:0] != 00` | misaligned idle. `Data_RD=0` | `MisalignedAccess` |
| `10 STORE` | `00 BYTE` | 항상 aligned | `lane` 위치 byte만 교체 후 word write | `lane[1:0]` |
| `10 STORE` | `01 HALF` | `Addr[0]=0` | `lane[1]` 위치 half만 교체 후 word write | `lane[1]` |
| `10 STORE` | `01 HALF` | `Addr[0]=1` | misaligned idle. `WE=0`, word 유지 | `MisalignedAccess` |
| `10 STORE` | `10 WORD` | `Addr[1:0]=00` | 32-bit word 전체 write | 없음 |
| `10 STORE` | `10 WORD` | `Addr[1:0] != 00` | misaligned idle. `WE=0`, word 유지 | `MisalignedAccess` |
| `11 RESERVED` | any | - | idle처럼 처리 권장 | 없음 |

## Diagram label ↔ 명세 signal adapter

block diagram의 Data Memory 하단 라벨은 구현 친화적 이름이고, 정본 명세의 control signal과 아래처럼 대응합니다.

| Diagram label | 명세 signal | 생성 규칙 | 설명 |
|---|---|---|---|
| `Byte Sel` | `WdLen[1:0]` | 그대로 전달 | `00=byte`, `01=half`, `10=word`, `11=none` |
| `Lane` | `Addr[1:0]` | 주소 하위 2비트 | 32-bit word 내부 byte offset |
| `WE` | `MemRW`, `WdLen`, `Addr[1:0]`에서 파생 | `EffectiveStoreEn & (WdLen != MEM_NONE)` | store이고 misaligned가 아닐 때만 1 |
| store lane select | `WdLen[1:0]` + `Addr[1:0]` | `MEM_STORE`일 때 `WdLen` decode | byte/half/word store 폭과 lane 결정 |
| load enable | `MemRW`, `Addr[1:0]`에서 파생 | `EffectiveLoadEn` | aligned load data만 WB selector로 전달 |
| `MisalignedAccess` | `WdLen`, `MemRW`, `Addr[1:0]`에서 파생 | half는 `Addr[0]`, word는 `Addr[1:0]` 확인 | debug/test 관찰용. CPU trap/flush에는 연결하지 않음 |
| `Extension` | `LoadEx` | 그대로 전달 | `0=sign`, `1=zero`; `lw`는 don't care |

따라서 그림의 `WE`를 Control Unit에서 직접 1-bit로 만들지 말고, Data Memory 내부 adapter가 `MemRW==MEM_STORE`와 alignment 조건을 decode해 생성하게 둡니다. `Byte Sel`은 접근 폭(`WdLen`)이고, address 기반 byte lane 선택은 `Addr[1:0]`입니다.

## Logisim 구현 순서

1. `Addr` splitter를 둡니다.
   - `WordAddr = Addr[필요상위:2]`
   - `Lane = Addr[1:0]`
2. 2-port RAM을 32-bit data width로 둡니다.
   - read/load address = `WordAddr`
   - write/store address = `WordAddr`
3. `MemRW` comparator 2개를 둡니다.
   - `MemRW == 01` → `LoadEn`
   - `MemRW == 10` → `StoreEn`
4. `WdLen` comparator 또는 decoder를 둡니다.
   - byte/half/word/none 구분
5. Misaligned detector를 만듭니다.
   - `HalfMisaligned = IsHalf & Lane[0]`
   - `WordMisaligned = IsWord & (Lane[1] | Lane[0])`
   - `MisalignedAccess = (LoadEn | StoreEn) & (HalfMisaligned | WordMisaligned)`
6. Read path를 만듭니다.
   - `ReadWord` → byte mux / half mux / word pass
   - sign/zero extension
   - `WdLen` mux
   - `LoadEn` gate
7. Store path를 만듭니다.
   - `ReadWord`와 `Data_rt`를 merge해서 `ByteMerged`, `HalfMerged`, `WordMerged` 생성
   - `WdLen` mux로 `StoreWord` 선택
   - RAM store data에 `StoreWord` 연결
   - RAM write enable에 `EffectiveStoreEn & (WdLen != MEM_NONE)` 연결
8. Probe를 붙여 debug합니다.
   - `WordAddr`
   - `Lane`
   - `ReadWord`
   - `SelectedByte`
   - `SelectedHalf`
   - `StoreWord`
   - `LoadEn`, `StoreEn`, `EffectiveLoadEn`, `EffectiveStoreEn`, `WE`
   - `MisalignedAccess`
   - `Data_RD`

## 검증 포인트

예제 word가 `0xAABBCCDD`일 때 다음이 맞으면 endian/lane이 맞습니다.

| 동작 | 주소 lane | 예상 결과 |
|---|---:|---:|
| `lb`, `LoadEx=0` | `00` | `0xFFFFFFDD` |
| `lbu`, `LoadEx=1` | `00` | `0x000000DD` |
| `lb`, `LoadEx=0` | `01` | `0xFFFFFFCC` |
| `lbu`, `LoadEx=1` | `01` | `0x000000CC` |
| `lh`, `LoadEx=0`, lower half | `00` | `0xFFFFCCDD` |
| `lhu`, `LoadEx=1`, lower half | `00` | `0x0000CCDD` |
| `lh/lhu`, misaligned | `01` 또는 `11` | `MisalignedAccess=1`, `Data_RD=0` |
| `lh`, `LoadEx=0`, upper half | `10` | `0xFFFFAABB` |
| `lhu`, `LoadEx=1`, upper half | `10` | `0x0000AABB` |
| `lw`, aligned | `00` | `0xAABBCCDD` |
| `lw`, misaligned | `01`, `10`, `11` | `MisalignedAccess=1`, `Data_RD=0` |
| `sb Data_rt=0x11`, lane `00` | `00` | new word `0xAABBCC11` |
| `sb Data_rt=0x11`, lane `01` | `01` | new word `0xAABB11DD` |
| `sb Data_rt=0x11`, lane `10` | `10` | new word `0xAA11CCDD` |
| `sb Data_rt=0x11`, lane `11` | `11` | new word `0x11BBCCDD` |
| `sh Data_rt=0x2233`, lower half | `00` | new word `0xAABB2233` |
| `sh Data_rt=0x2233`, upper half | `10` | new word `0x2233CCDD` |
| `sh Data_rt=0x2233`, misaligned | `01`, `11` | `MisalignedAccess=1`, word unchanged |
| `sw Data_rt=0x44556677`, aligned | `00` | new word `0x44556677` |
| `sw Data_rt=0x44556677`, misaligned | `01`, `10`, `11` | `MisalignedAccess=1`, word unchanged |

## 흔한 실수

- RAM address에 `Addr[31:0]` 전체를 넣는 실수. 32-bit word RAM이면 `Addr[31:2]`가 RAM address이고 `Addr[1:0]`은 lane입니다.
- `MemRW`만으로 store 폭을 구분하려는 실수. store 폭은 `WdLen`이 담당합니다.
- `lane=00`을 MSB byte로 해석하는 실수. 현재 little-endian 기준에서는 `lane=00`이 `ReadWord[7:0]`입니다.
- half access에서 `lane[1:0]` 전체로 4개 half를 만들려는 실수. 32-bit word 안에는 lower/upper half 2개만 있으므로 aligned half 선택은 `lane[1]`만 사용하고, `lane[0]`은 misaligned 감지에 사용합니다.
- `LoadEx` 의미를 뒤집는 실수. 현재 기준은 `0=sign`, `1=zero`입니다.
- store에서 새 byte/half만 RAM에 넣고 나머지 byte를 잃는 실수. byte/half store는 반드시 기존 `ReadWord`와 merge해야 합니다.
- misaligned store에서도 merge 결과를 RAM에 쓰는 실수. misaligned이면 `WE=0`이어야 합니다.

## Caveat / 주의사항

- 현재 설계는 CPU exception을 구현하지 않으므로 unaligned load/store trap은 처리하지 않습니다.
- trap 대신 idle 정책을 씁니다. `lh/lhu/sh`에서 `Addr[0]=1`, `lw/sw`에서 `Addr[1:0] != 00`이면 `MisalignedAccess=1`입니다.
- misaligned load는 `Data_RD=0`, misaligned store는 `WE=0`으로 word를 유지합니다.
- 정상 program/test는 aligned address를 사용해야 하지만, 회로 검증 벡터에는 misaligned idle case를 포함합니다.
- 단일 사이클에서 load read/extension 경로는 조합으로 관찰할 수 있지만, store write는 clock edge에서 확정됩니다.

## 파이프라인 확장 시 메모

파이프라인/FPGA 합성용 HDL에서는 BRAM 특성 때문에 sync read memory를 쓰는 것이 자연스럽습니다. 이 경우 `Data Memory`와 pipeline register 배치가 달라질 수 있습니다. 그러나 control 의미는 동일합니다.

```text
MemRW = idle/load/store 방향
WdLen = byte/half/word 폭
Lane  = Addr[1:0]
MisalignedAccess = half/word alignment 위반 감지
```

파이프라인에서는 MEM stage control(`WdLen`, `MemRW`, `LoadEx`)과 store data forwarding 결과를 함께 전달해야 합니다. sync-read Data Memory를 쓸 때는 `MisalignedAccess`도 read data와 같은 cycle 의미가 되도록 내부에서 지연시켜 load 결과 0 또는 write disable을 적용합니다.
