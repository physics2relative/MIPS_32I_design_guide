# Data Memory

## 역할

Data Memory는 load/store 명령어의 byte/half/word memory 접근을 처리합니다. `ALUResult`를 주소로 쓰고, store data는 `Data_rt`에서 옵니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Addr` | 32 | ALUResult | data memory byte address |
| `Data_rt` / store data | 32 | Register | store할 원본 data |
| `WdLen` | 2 | Control Unit | byte/half/word width |
| `MemRW` | 3 | Control Unit | store/load/idle 종류 |
| `LoadEx` | 1 | Control Unit | signed/zero extension |
| `clk` | 1 | top level | store clock |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `Data_RD` | 32 | WB selector | load 결과 |

## Logisim 설계 가이드

1. 기본 memory는 32-bit word storage로 두고, byte lane 선택 로직을 별도 구현합니다.
2. `WdLen=MEM_BYTE/HALF/WORD`로 접근 폭을 선택합니다.
3. `MemRW=MEM_SB/SH/SW`일 때 write enable을 만들고, `MEM_LOAD`일 때 read path를 활성화합니다.
4. byte/half store는 address 하위 bit로 lane을 골라 기존 word의 나머지 byte를 보존해야 합니다.
5. byte/half load는 lane을 선택한 뒤 `LoadEx`에 따라 sign-extend 또는 zero-extend합니다.
6. `MEM_IDLE`에서는 memory write enable이 반드시 0입니다.

## Diagram label ↔ 명세 signal adapter

block diagram의 Data Memory 하단 라벨은 구현 친화적 이름이고, 정본 명세의 control signal과 아래처럼 대응합니다.

| Diagram label | 명세 signal | 생성 규칙 | 설명 |
|---|---|---|---|
| `Byte Sel` | `WdLen[1:0]` | 그대로 전달 | `00=byte`, `01=half`, `10=word`, `11=none` |
| `WE` | `MemRW[2:0]`에서 파생 | `MemRW in {MEM_SB, MEM_SH, MEM_SW}` | 실제 memory write enable은 store 계열에서만 1 |
| store lane select | `MemRW[2:0]` + `Addr[1:0]` | `MEM_SB/SH/SW` decode | byte/half/word store 종류와 lane 결정 |
| load enable | `MemRW[2:0]`에서 파생 | `MemRW == MEM_LOAD` | read data를 WB selector로 전달 |
| `Extension` | `LoadEx` | 그대로 전달 | `0=sign`, `1=zero`; `lw`는 don't care |

따라서 그림의 `WE`를 Control Unit에서 직접 1-bit로 만들지 말고, Data Memory 내부 adapter가 `MemRW`를 decode해 생성하게 둡니다. `Byte Sel`은 접근 폭(`WdLen`)이고, address 기반 byte lane 선택은 `Addr[1:0]`와 store/load width로 별도 라벨링합니다.

## 검증 포인트

- `lw`는 32-bit 전체를 읽습니다.
- `lb/lh`는 sign-extend합니다.
- `lbu/lhu`는 zero-extend합니다.
- `sb/sh/sw`는 지정 width만 memory에 씁니다.
- non-memory instruction에서 memory write가 발생하지 않습니다.

## 흔한 실수

- `MemRW`를 1-bit write enable로 축소해 `sb/sh/sw` 구분을 잃는 실수.
- byte lane endian을 instruction/test vector와 다르게 해석하는 실수.
- load extension을 WB selector 뒤에서 처리해 data path를 흐리게 만드는 실수. 이 guide에서는 Data Memory output을 이미 32-bit 확장 결과로 둡니다.

## Caveat / 주의사항

Logisim memory component 설정에 따라 address가 byte index인지 word index인지 다릅니다. 회로에서는 `Addr[31:2]`와 `Addr[1:0]`의 역할을 주석으로 남겨야 합니다.

## 파이프라인 확장 시 메모

단일 사이클에서 load read/extension 경로는 조합으로 관찰할 수 있지만, store write는 clock edge에서 확정됩니다. 파이프라인으로 확장할 때는 MEM stage control(`WdLen`, `MemRW`, `LoadEx`)과 store data forwarding을 함께 전달해야 합니다.
