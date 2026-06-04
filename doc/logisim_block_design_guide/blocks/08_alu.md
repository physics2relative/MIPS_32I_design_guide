# ALU

## 역할

ALU는 산술, 논리, `slt/sltu` 비교, shift, 주소 계산, branch target 계산을 수행합니다. 결과는 write-back, data memory address, PC branch target으로 사용됩니다. Branch taken 판정은 ALU flag가 아니라 별도 Branch Comp가 수행합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `ALU_A` | 32 | A Selector | operand A |
| `ALU_B` | 32 | B Selector | operand B 또는 shift amount |
| `ALUSel` | 4 | Control Unit | ALU operation |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `ALUResult` | 32 | Data Memory, WB selector, PC Selector | 연산 결과 |
| optional flags | 1 each | debug only | zero/negative/carry 등은 필수 아님. branch 판정에는 사용하지 않음 |

## Logisim 설계 가이드

구현해야 할 `ALUSel`:

| `ALUSel` | 이름 | 동작 |
|---|---|---|
| 0000 | ALU_ADD | A + B |
| 0001 | ALU_SUB | A - B |
| 0010 | ALU_AND | A & B |
| 0011 | ALU_OR | A &#124; B |
| 0100 | ALU_XOR | A ^ B |
| 0101 | ALU_SLT | signed A < B |
| 0110 | ALU_SLTU | unsigned A < B |
| 0111 | ALU_SLL | A << B[4:0] |
| 1000 | ALU_SRL | logical right shift |
| 1001 | ALU_SRA | arithmetic right shift |
| 1010 | ALU_NOR | ~(A &#124; B) |
| 1011 | ALU_ABS | custom abs: A[31] ? -A : A |
| 1111 | ALU_NONE | 결과 사용 안 함, 0 권장 |

### Custom ABS 설계

`ALU_ABS(1011)`는 B 입력을 사용하지 않는 unary 연산입니다. 구현은 다음 둘 중 하나로 하면 됩니다.

1. 간단한 구현: `A[31]`을 selector로 사용해 `A`와 `~A + 1` 중 선택합니다.
2. 기존 adder 재사용: `~A`와 `1`을 adder에 넣어 `-A`를 만들고, 마지막 MUX에서 `A[31]`에 따라 `A`/`-A`를 선택합니다.

검증 corner case는 `0`, `1`, `0xFFFF_FFFF(-1)`, `0xFFFF_FFFE(-2)`, `0x7FFF_FFFF`, `0x8000_0000`, `0x8000_0001`입니다.

## 검증 포인트

- `add/addu/addi/addiu/lw/sw` 주소 계산이 ADD로 동작합니다.
- `sub/subu`가 SUB로 동작합니다.
- `slt/slti`는 signed 비교, `sltu/sltiu`는 unsigned 비교입니다.
- shift는 `B[4:0]`만 사용합니다.
- branch target 계산 결과가 `PC+4+offset`입니다.
- branch taken 판정은 ALU zero flag가 아니라 Branch Comp의 equality comparator 결과를 사용합니다.

## 흔한 실수

- signed/unsigned 비교를 같은 comparator로 처리하는 실수.
- `sra`를 logical shift로 구현하는 실수.
- overflow exception을 만들려고 시도하는 실수. 이 프로젝트 명세에는 exception 처리가 없습니다.
- `beq/bne`를 위해 ALU zero flag를 필수 출력으로 만들고 PCControl에 직접 연결하는 실수. branch 판정은 Branch Comp에서 분리합니다.
- `ALU_ABS`에서 `0x8000_0000`을 overflow/exception으로 처리하려는 실수. 현재 과제 CPU는 exception path가 없으므로 결과를 `0x8000_0000`으로 유지합니다.
- `ALU_NONE`일 때 floating output을 두는 실수. 0으로 안정화합니다.

## Caveat / 주의사항

MIPS의 `add/sub`와 `addu/subu`는 ISA상 overflow exception 차이가 있지만, 이 Logisim subset은 exception 처리를 명세하지 않습니다. 따라서 control/ALU guide에서는 동일 산술 결과를 생성하고 exception block을 추가하지 않습니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
