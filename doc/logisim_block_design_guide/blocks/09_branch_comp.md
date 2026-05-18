# Branch Comp

## 역할

Branch Comp는 register 값 두 개를 비교해 branch가 taken인지 판단합니다. 현재 실제 구현 branch는 `beq`, `bne`뿐입니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Data_rs` | 32 | Register | 비교 operand 1 |
| `Data_rt` | 32 | Register | 비교 operand 2 |
| `BrSel` | 3 | Control Unit | branch 비교 방식 |
| `Branch` | 1 | Control Unit | branch instruction 여부 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `BranchTakenRaw` | 1 | Jump Branch / PCControl | 비교 결과 |
| optional `Equal` | 1 | debug | `Data_rs == Data_rt` |

## Logisim 설계 가이드

1. equality comparator를 만들고 `EQ = (Data_rs == Data_rt)`를 계산합니다.
2. `BR_EQ`일 때 `EQ`, `BR_NE`일 때 `!EQ`를 선택합니다.
3. `BR_NONE` 또는 예약 BrSel 값에서는 0을 출력합니다.
4. 최종 PC 선택에는 `Branch && BranchTakenRaw`를 사용합니다.

## 검증 포인트

- `beq`에서 두 register가 같으면 taken입니다.
- `bne`에서 두 register가 다르면 taken입니다.
- branch가 아닌 instruction에서 comparator 결과와 무관하게 PC branch가 선택되지 않습니다.
- `blt/bge/bltu/bgeu` control row가 없어야 합니다.

## 흔한 실수

- Branch Comp에서 직접 `PCSel`을 만들어 Jump 우선순위를 깨뜨리는 실수.
- 예약된 `BR_LT/BR_GE/BR_LTU/BR_GEU`를 실제 branch로 구현하는 실수.
- branch target 계산을 Branch Comp 안에 섞는 실수. target은 ALU 경로가 만듭니다.

## Caveat / 주의사항

의사 branch는 assembler 수준 시퀀스로만 설명합니다. 하드웨어에 signed/unsigned less-than branch comparator를 추가하면 `no-extra-isa` 요구사항을 어깁니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
