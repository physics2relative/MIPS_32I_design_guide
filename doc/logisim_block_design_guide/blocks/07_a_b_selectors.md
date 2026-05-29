# A Selector / B Selector

## 역할

A Selector와 B Selector는 ALU의 두 입력을 명령어 종류에 맞게 고릅니다. R-type, I-type, branch target 계산, shift 명령어가 모두 이 selector encoding에 의존합니다. branch offset은 Imm Generator의 `ImmVal`로 들어오므로 별도 branch-offset 입력은 두지 않습니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Data_rs` | 32 | Register | 일반 A 입력, variable shift amount source |
| `Data_rt` | 32 | Register | 일반 B 입력, shift 대상 |
| `PCPlus4` | 32 | PC+4 | branch target 계산 A 입력 |
| `ImmVal` | 32 | Imm Generator | immediate ALU 입력 |
| `shamt` | 5 | Inst Split | immediate shift amount |
| `0` | 32 | constant | `lui`, NOP, unused path |
| `ASel` | 2 | Control Unit | A mux select |
| `BSel` | 3 | Control Unit | B mux select |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `ALU_A` | 32 | ALU | selected A operand |
| `ALU_B` | 32 | ALU | selected B operand |

## Logisim 설계 가이드

A Selector 입력 순서:

| `ASel` | 이름 | 입력 |
|---|---|---|
| `00` | `A_RS` | `Data_rs` |
| `01` | `A_PC4` | `PCPlus4` |
| `10` | `A_ZERO` | constant 0 |
| `11` | `A_RT` | `Data_rt` |

B Selector 입력 순서:

| `BSel` | 이름 | 입력 |
|---|---|---|
| `000` | `B_RT` | `Data_rt` |
| `001` | `B_IMM` | `ImmVal` |
| `010` | `B_SHAMT` | zero-extended `shamt` |
| `011` | `B_RS_LOW5` | zero-extended `Data_rs[4:0]` |
| `100` | `B_ZERO` | constant 0 |
| `101` | 예약 | constant 0 권장 |
| `110` | 예약 | constant 0 권장 |
| `111` | `B_NONE` | constant 0 권장 |

## 검증 포인트

- R-type `add`는 `A_RS`, `B_RT`를 사용합니다.
- `addi/lw/sw`는 `A_RS`, `B_IMM`을 사용합니다.
- `lui`는 `A_ZERO`, `B_IMM`을 사용합니다.
- `beq/bne` branch target 계산은 `A_PC4`, `B_IMM`을 사용합니다. 이때 Imm Generator는 `ImmSel=IMM_BRANCH16`으로 `ImmVal=sign_ext(imm16)<<2`를 출력합니다.
- `sll/srl/sra`는 `A_RT`, `B_SHAMT`를 사용합니다.
- `sllv/srlv/srav`는 `A_RT`, `B_RS_LOW5`를 사용합니다.

## 흔한 실수

- shift 대상과 shift amount를 반대로 넣는 실수.
- `B_SHAMT`를 5-bit 그대로 ALU에 넣어 width mismatch가 생기는 실수. 32-bit로 zero-extend합니다.
- branch target 계산에 현재 `PC`를 넣고 `PCPlus4`를 넣지 않는 실수.

## Caveat / 주의사항

block diagram의 B Selector 입력 라벨은 `000..100`이 실제 입력입니다. 명세서는 `101/110` 예약, `111=B_NONE`까지 정의합니다. Logisim mux 입력 수를 맞추기 위해 예약/NONE 입력은 0에 묶고 control이 실수로 선택하지 않도록 검증합니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
