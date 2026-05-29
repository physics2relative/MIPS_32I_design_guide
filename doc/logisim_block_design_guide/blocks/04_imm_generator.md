# Imm Generator

## 역할

Imm Generator는 instruction의 `imm16=Inst[15:0]`를 `ImmSel`에 따라 32-bit 값으로 확장합니다. ALU immediate, branch offset(`ImmVal`로 출력), `lui` 생성만 담당하며, J-type `target26=Inst[25:0]`는 Imm Generator를 거치지 않고 Jump Target Gen으로 직접 연결합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `imm16` | 16 | Inst Split | I-type immediate |
| `ImmSel` | 2 | Control Unit | 16-bit immediate 생성 방식 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `ImmVal` | 32 | B Selector | sign/zero/lui immediate 또는 branch offset(`sign_ext(imm16) << 2`) |

## Logisim 설계 가이드

1. `IMM_SIGN16`: `imm16[15]`를 상위 16-bit에 복제합니다.
2. `IMM_ZERO16`: 상위 16-bit를 0으로 채웁니다.
3. `IMM_LUI16`: `{imm16, 16'b0}`를 만듭니다.
4. `IMM_BRANCH16`: sign-extend 후 왼쪽 2-bit shift합니다.
5. `target26`은 이 블록에 입력하지 않습니다. Jump Target Gen이 Inst Split에서 `target26`을 직접 받습니다.
6. 각 결과를 mux로 고르거나, 출력별로 항상 계산한 뒤 downstream selector가 필요한 값을 쓰게 해도 됩니다.

## 검증 포인트

- `addi/slti/lw/sw/beq/bne`의 immediate는 sign-extend됩니다.
- `andi/ori/xori`의 immediate는 zero-extend됩니다.
- `lui`는 하위 16-bit가 0입니다.
- branch offset은 sign-extend 후 2-bit shift됩니다.
- `j/jal` target의 32-bit 결합은 Jump Target Gen 문서에서 검증합니다.

## 흔한 실수

- branch offset을 shift하지 않는 실수.
- zero-extend가 필요한 logical immediate를 sign-extend하는 실수.

## Caveat / 주의사항

block diagram에서는 `imm16`과 `target26`이 모두 Instruction split에서 나옵니다. 이 guide에서는 Imm Generator가 `imm16`만 받고, 32-bit `JumpImmTarget`은 Jump Target Gen에서만 만듭니다. `target26`은 Jump Target Gen으로 직접 연결합니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.


설계 결정: 별도 branch-offset 출력은 두지 않습니다. `ImmSel=11(IMM_BRANCH16)`이면 `ImmVal = sign_ext(imm16) << 2`가 되고, Branch 명령어는 B Selector에서 `B_IMM`을 선택해 이 값을 ALU B로 보냅니다.
