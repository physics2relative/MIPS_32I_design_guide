# WB selector

## 역할

WB selector는 register file에 쓸 데이터를 고릅니다. write-back source는 memory load 결과, ALU 결과, `PC+4` link value입니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Data_RD` | 32 | Data Memory | load result |
| `ALUResult` | 32 | ALU | ALU result / address / `lui` result |
| `PCPlus4` | 32 | PC+4 | `jal/jalr` link value |
| optional `0` | 32 | constant | `WB_NONE` 안정화 |
| `WBSel` | 2 | Control Unit | write-back source 선택 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `Data_WR` | 32 | Register | register write data |

## Logisim 설계 가이드

Selector 입력 순서:

| `WBSel` | 이름 | 입력 |
|---|---|---|
| `00` | `WB_MEM` | `Data_RD` |
| `01` | `WB_ALU` | `ALUResult` |
| `10` | `WB_PC4` | `PCPlus4` |
| `11` | `WB_NONE` | constant 0 권장 |

`RegWEn=0`이면 `Data_WR` 값은 관찰만 될 뿐 write되지 않습니다. 그래도 `WB_NONE` 경로를 0으로 안정화하면 디버깅이 쉽습니다.

## 검증 포인트

- R-type/I-type/lui는 `WB_ALU`를 사용합니다.
- load는 `WB_MEM`을 사용합니다.
- `jal/jalr`은 `WB_PC4`를 사용합니다.
- store/branch/jump register-write 없는 명령어는 `RegWEn=0`입니다.

## 흔한 실수

- WB selector 입력 0/1을 바꿔 load가 ALU address를 write하는 실수.
- `jal` link value를 jump target으로 착각하는 실수.
- `WB_NONE`일 때 floating input을 두는 실수.

## Caveat / 주의사항

WB selector 자체는 write enable을 판단하지 않습니다. 실제 write 여부는 Register block의 `RegWEn`이 결정합니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
