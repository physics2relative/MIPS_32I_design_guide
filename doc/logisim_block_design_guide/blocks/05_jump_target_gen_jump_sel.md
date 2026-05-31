# Jump Target Gen / Jump Sel

## 역할

Jump Target Gen은 `{PC+4[31:28], target26, 2'b00}` 32-bit immediate jump target 생성만 담당합니다. Jump Sel은 이 immediate target과 register jump target 중 하나를 고르는 별도 2-input mux입니다.

> 용어 주의: 이 문서에서 `Jump`는 PC redirect enable이고, `JumpSel`은 immediate target과 register target을 고르는 mux selector입니다. 두 신호를 같은 의미로 쓰지 않습니다.

## 입력

### Jump Target Gen 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `PCPlus4` | 32 | PC+4 | J-type target 상위 4-bit 제공 |
| `target26` | 26 | Inst Split | J-type target field 원본. Imm Generator를 거치지 않고 직접 연결 |

### Jump Sel mux 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `JumpImmTarget` | 32 | Jump Target Gen | `{PC+4[31:28], target26, 2'b00}` |
| `Data_rs` | 32 | Register File / forwarding | `jr/jalr` register target |
| `JumpSel` | 1 | Control Unit | `0=JUMP_IMM26`, `1=JUMP_REG` |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `JumpImmTarget` | 32 | Jump Sel | Jump Target Gen이 생성하는 immediate jump target |
| `SelectedJumpTarget` | 32 | PC Selector / PCControl | Jump Sel mux가 고른 최종 jump target |

## Logisim 설계 가이드

1. Jump Target Gen에는 `PCPlus4`와 raw `target26`만 넣습니다.
2. raw `target26` 뒤에 2-bit zero를 붙여 word-aligned 주소로 만듭니다.
3. 상위 4-bit는 `PCPlus4[31:28]`을 사용합니다.
4. Jump Sel mux의 입력 0은 `JumpImmTarget`, 입력 1은 `Data_rs`로 둡니다.
5. Jump Sel mux의 selector는 `JumpSel`입니다. `Jump`는 PCControl에서 PC를 jump path로 보낼지 결정하는 enable로 남깁니다.
6. `SelectedJumpTarget`은 PC Selector의 jump input으로 보냅니다.

## 검증 포인트

- `j/jal`에서 `JumpSel=0`, `SelectedJumpTarget=JumpImmTarget`입니다.
- `jr/jalr`에서 `JumpSel=1`, `SelectedJumpTarget=Data_rs`입니다.
- `Jump=0`이면 PCControl이 jump path를 선택하지 않으므로 `JumpSel`과 `SelectedJumpTarget`은 무시됩니다.
- `jal/jalr`의 link write-back은 Jump Sel이 아니라 WB selector의 `PC+4` 경로로 처리됩니다.

## 흔한 실수

- `Jump`를 Jump Sel mux selector로 쓰는 실수. `Jump`는 모든 `j/jal/jr/jalr`에서 1이므로 immediate jump와 register jump를 구분할 수 없습니다.
- `jr/jalr`를 위해 PC Selector에 별도 `PC_REG` 입력을 추가하는 실수. 명세서에서는 Jump Sel 결과를 `PC_JUMP` 하나로 보냅니다.
- immediate target 상위 4-bit를 `PCPlus4`가 아니라 `PC`에서 가져오는 실수.
- Imm Generator 안에서 J-type target을 또 만드는 실수. J-type target은 Jump Target Gen의 책임입니다.

## Caveat / 주의사항

단일 사이클과 파이프라인 모두 `JumpSel`은 1-bit target-source selector입니다. 파이프라인에서는 `JumpImmTarget`을 ID에서 만들고, register target 선택은 EX에서 forwarded `rs` 값을 사용해 수행합니다.
