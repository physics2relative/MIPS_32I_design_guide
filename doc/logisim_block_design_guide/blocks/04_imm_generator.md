# Imm Generator

## 역할

Imm Generator는 instruction immediate field를 명세서의 `ImmSel`에 따라 32-bit 값으로 확장합니다. ALU immediate, branch offset, `lui` 생성의 근거가 되며, J-type의 raw `target26`은 Jump Target Gen으로 전달합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Inst[25:0]` | 26 | Inst Split | immediate/jump field 묶음 |
| `imm16` | 16 | Inst Split | I-type immediate |
| `target26` | 26 | Inst Split | J-type target |
| `ImmSel` | 3 | Control Unit | immediate 생성 방식 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `ImmVal` | 32 | B Selector | sign/zero/lui immediate |
| `BranchOff` | 32 | B Selector / ALU | `sign_ext(imm16) << 2` |
| raw `target26` | 26 | Jump Target Gen | J-type target field 원본. 32-bit jump target 생성은 Jump Target Gen이 담당 |

## Logisim 설계 가이드

1. `IMM_SIGN16`: `imm16[15]`를 상위 16-bit에 복제합니다.
2. `IMM_ZERO16`: 상위 16-bit를 0으로 채웁니다.
3. `IMM_LUI16`: `{imm16, 16'b0}`를 만듭니다.
4. `IMM_BRANCH16`: sign-extend 후 왼쪽 2-bit shift합니다.
5. `target26`은 별도 확장하지 말고 Jump Target Gen으로 전달합니다. `IMM_J26` 공식은 명세에 남아 있지만, 이 block guide에서는 Jump Target Gen이 32-bit target 생성의 단일 owner입니다.
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

block diagram에는 `ImmVal`, `BranchOff`, `target26` 출력이 보입니다. 이 guide에서는 그림에 맞춰 Imm Generator가 raw `target26`만 내보내고, 32-bit `JumpImmTarget`은 Jump Target Gen에서만 만듭니다. 명세서의 `IMM_J26`은 공식의 의미로만 참조합니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
