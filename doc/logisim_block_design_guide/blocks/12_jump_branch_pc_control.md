# Jump Branch / PCControl

## 역할

Jump Branch / PCControl block은 branch/jump 결과를 모아 최종 `PCSel`을 만듭니다. 단일 사이클 next-PC control의 우선순위는 `Jump` > taken branch > fall-through입니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Branch` | 1 | Control Unit | branch instruction 여부 |
| `Jump` | 1 | Control Unit | jump instruction 여부 |
| `BranchTakenRaw` | 1 | Branch Comp | branch compare 결과 |
| `BranchTarget` | 32 | ALU | branch target 주소 |
| `SelectedJumpTarget` | 32 | Jump Sel | jump target 주소 |
| `PCPlus4` | 32 | PC+4 | fall-through 주소 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `PCSel` | 2 | PC Selector | `00=PC+4`, `01=branch`, `10=jump` |
| optional `BranchTaken` | 1 | debug | `Branch && BranchTakenRaw` |

## Logisim 설계 가이드

1. `BranchTaken = Branch && BranchTakenRaw`를 만듭니다.
2. `Jump=1`이면 `PCSel=PC_JUMP(10)`입니다.
3. 그렇지 않고 `BranchTaken=1`이면 `PCSel=PC_BRANCH(01)`입니다.
4. 나머지는 `PCSel=PC_PLUS4(00)`입니다.
5. 이 block은 target 값을 계산하지 않고 어떤 PC path를 선택할지만 결정합니다.

의사식:

```text
if Jump:
    PCSel = PC_JUMP
else if Branch && BranchTakenRaw:
    PCSel = PC_BRANCH
else:
    PCSel = PC_PLUS4
```

## 검증 포인트

- `j/jal/jr/jalr`은 Branch Comp 결과와 무관하게 jump가 우선입니다.
- `beq/bne` not-taken이면 `PCSel=PC_PLUS4`입니다.
- branch가 아닌 ALU/memory 명령어는 `PCSel=PC_PLUS4`입니다.
- 예약 `PCSel=11`이 만들어지지 않습니다.

## 흔한 실수

- BranchTaken이 참일 때 Jump보다 branch를 우선하는 실수.
- `PCSel`과 target 값을 한 mux 안에서 중복 계산해 배선 추적이 어려워지는 실수.
- `Branch` 없이 comparator 결과만으로 branch를 타는 실수.

## Caveat / 주의사항

파이프라인에서는 이 결정이 EX 단계 redirect로 이동하고 flush/stall과 결합됩니다. 단일 사이클의 `PCSel` 신호를 그대로 파이프라인 top-level PC mux에 연결하면 hazard 제어가 빠질 수 있습니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
