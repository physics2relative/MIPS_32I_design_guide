# 09. Branch Comp

## 역할

`beq`, `bne`의 비교 조건을 ALU zero flag와 분리해서 계산합니다. 현재 구현은 1-bit `BrSel`만 사용합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
| --- | ---: | --- | --- |
| `Data_rs` | 32 | Register File / forwarding mux | rs 값 |
| `Data_rt` | 32 | Register File / forwarding mux | rt 값 |
| `BrSel` | 1 | Control Unit | `0=EQ`, `1=NE` |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
| --- | ---: | --- | --- |
| `BranchTaken` | 1 | Jump Branch / PCControl | BranchComp 조건 결과. `Branch` enable은 이 블록 밖에서 gating합니다. |

## Logisim 설계 가이드

1. `EQ = (Data_rs == Data_rt)` comparator를 만듭니다.
2. `BrSel=0`이면 `EQ`, `BrSel=1`이면 `!EQ`를 mux로 선택합니다.
3. 이 블록에는 `Branch` 입력을 넣지 않습니다. non-branch 여부는 PCControl에서 `Branch && BranchTaken`으로 처리합니다.
4. ALU `Zero`/`ALUResult` 입력 없이 `Data_rs`, `Data_rt`, `BrSel`만으로 조건을 계산합니다.

## Caveat

- 현재 하드웨어 직접 구현 branch는 `beq`, `bne`뿐입니다.
- `blt`, `bge`, `bltu`, `bgeu`는 `slt/sltu + beq/bne` pseudo sequence로 처리합니다.
- 파이프라인에서는 forwarding 이후의 `FwdRsData`, `FwdRtData`를 이 블록에 넣어야 합니다.
