# PC Selector / PC / PC+4

## 역할

프로그램 카운터 경로입니다. `PC`는 현재 instruction 주소를 보관하고, `PC + 4`는 기본 fall-through 주소를 만듭니다. `PC Selector`는 `PCSel`에 따라 다음 PC를 `PC+4`, branch target, jump target 중에서 선택합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `PCSel` | 2 | Jump Branch / PCControl | `00=PC_PLUS4`, `01=PC_BRANCH`, `10=PC_JUMP`, `11=예약` |
| `PCPlus4` | 32 | `+4` adder | 기본 다음 주소 |
| `BranchTarget` | 32 | ALU | `PC+4 + (sign_ext(imm16) << 2)` |
| `SelectedJumpTarget` | 32 | Jump Sel | `j/jal/jr/jalr` target |
| `clk`, `reset` | 1 | top level | PC register 제어 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `PC` | 32 | Instruction Memory, PC+4, jump/branch 계산 | 현재 instruction 주소 |
| `PCPlus4` | 32 | Register write-back, A Selector, jump target | link value 및 기본 next PC |
| `NextPC` | 32 | PC register 입력 | selector 결과 |

## Logisim 설계 가이드

1. 32-bit register를 `PC`로 배치하고 reset 값은 프로젝트 기준 시작 주소로 둡니다. 별도 요구가 없으면 `0x00000000`을 기본으로 둡니다.
2. `PC` 출력에 32-bit adder를 붙이고 두 번째 입력은 constant `4`로 고정해 `PCPlus4`를 만듭니다.
3. `PC Selector`는 3개 의미 입력을 갖는 mux로 구현합니다. Logisim mux가 4입력을 요구하면 `11` 입력은 `PCPlus4` 또는 `0`에 묶고 사용 금지로 표시합니다.
4. `NextPC`를 PC register 입력에 연결하고, PC write enable이 별도 없다면 항상 enable합니다.
5. 배선 이름은 `PC`, `PCPlus4`, `BranchTarget`, `SelectedJumpTarget`, `NextPC`처럼 의미가 드러나게 라벨링합니다.

## 검증 포인트

- 일반 ALU 명령어에서 `PCSel=00`이면 `PC`가 매 cycle 4씩 증가합니다.
- `beq/bne` taken일 때 `PCSel=01`이고 `PC`가 branch target으로 바뀝니다.
- `j/jal/jr/jalr`에서 `PCSel=10`이고 jump target으로 바뀝니다.
- `jal/jalr`의 write-back 값은 `PCPlus4`입니다.

## 흔한 실수

- `PC+4` 대신 현재 `PC`를 link value로 write-back하는 실수.
- branch target을 `PC + offset`으로 계산해 MIPS 기준인 `PC+4 + offset`과 어긋나는 실수.
- selector 입력 순서와 `PCSel` encoding을 다르게 연결하는 실수.

## Caveat / 주의사항

block diagram의 `PC Selector` 입력 라벨은 `00/01/10`만 보입니다. 실제 encoding은 명세서의 `PCSel[1:0]`을 따릅니다. `11`은 예약이므로 instruction decode가 이 값을 만들지 않아야 합니다.

## 파이프라인 확장 시 메모

단일 사이클에서 `PC Selector`와 `PC+4` adder는 조합 경로이고, `PC` register 값 갱신은 clock edge에서 확정됩니다. 파이프라인으로 확장할 때는 IF stage PC write enable, stall, flush, EX-stage redirect를 별도 control로 추가해야 합니다.
