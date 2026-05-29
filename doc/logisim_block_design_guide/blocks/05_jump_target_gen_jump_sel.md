# Jump Target Gen / Jump Sel

## 역할

Jump Target Gen은 `{PC+4[31:28], target26, 2'b00}` 32-bit immediate jump target 생성의 단일 owner입니다. Jump Sel은 이 immediate target과 register jump target 중 하나를 선택합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `PCPlus4` | 32 | PC+4 | J-type target 상위 4-bit |
| `target26` | 26 | Inst Split | J-type target field 원본. Imm Generator를 거치지 않고 직접 연결 |
| `Data_rs` | 32 | Register | `jr/jalr` register target |
| `JumpSel` | 1 | Control Unit | 단일 사이클: `0=JUMP_IMM26`, `1=JUMP_REG` |
| `Jump` | 1 | Control Unit | jump instruction 여부 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `JumpImmTarget` | 32 | Jump Sel | 이 block이 생성하는 `{PC+4[31:28], target26, 2'b00}` |
| `SelectedJumpTarget` | 32 | PC Selector / PCControl | 최종 jump target |

## Logisim 설계 가이드

1. raw `target26`에 2-bit zero를 붙여 word-aligned 주소로 만듭니다.
2. 상위 4-bit는 `PCPlus4[31:28]`을 사용합니다.
3. Jump Sel mux의 입력 0은 이 block이 만든 `JumpImmTarget`, 입력 1은 `Data_rs`로 둡니다.
4. `Jump=0`일 때 `JumpSel` 값은 무시되지만, 디버깅을 위해 기본값은 `0`으로 둡니다.
5. `SelectedJumpTarget`은 PC Selector의 jump input으로 보냅니다.

## 검증 포인트

- `j/jal`에서 `SelectedJumpTarget`이 immediate target입니다.
- `jr/jalr`에서 `SelectedJumpTarget`이 `Data_rs`입니다.
- `jal/jalr`의 link write-back은 Jump Sel이 아니라 WB selector의 `PC+4` 경로로 처리됩니다.

## 흔한 실수

- `jr/jalr`를 위해 PC Selector에 별도 `PC_REG` 입력을 추가하는 실수. 명세서에서는 Jump Sel 결과를 `PC_JUMP` 하나로 보냅니다.
- immediate target 상위 4-bit를 `PCPlus4`가 아니라 `PC`에서 가져오는 실수.
- 단일 사이클 1-bit `JumpSel`과 파이프라인 2-bit `JumpSel`을 섞는 실수.

## Caveat / 주의사항

파이프라인 명세의 `JumpSel[1:0]`은 `00=JUMP_NONE`, `01=JUMP_IMM26`, `10=JUMP_REG`입니다. 단일 사이클 diagram의 `Jump Sel`은 2-input mux이므로 1-bit selector로 문서화합니다. Imm Generator가 32-bit jump target을 다시 만들지 않도록 block 경계를 유지하고, `target26`은 Inst Split에서 직접 받습니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
