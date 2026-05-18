# Instruction Memory / Inst Split

## 역할

Instruction Memory는 `PC` 주소에 있는 32-bit instruction을 읽고, Inst Split은 그 instruction을 MIPS field로 분리합니다. 모든 downstream block은 이 field를 기준으로 동작합니다.

## 입력

| 입력 | 폭 | 출처 | 설명 |
|---|---:|---|---|
| `Addr_Inst` / `PC` | 32 | PC | instruction fetch 주소 |

## 출력

| 출력 | 폭 | 목적지 | 설명 |
|---|---:|---|---|
| `Inst` | 32 | Inst Split, Control Unit | 원본 instruction |
| `opcode` = `Inst[31:26]` | 6 | Control Unit | opcode |
| `rs` = `Inst[25:21]` | 5 | Register | source register 1 |
| `rt` = `Inst[20:16]` | 5 | Register, Dest Sel | source 또는 I-type destination |
| `rd` = `Inst[15:11]` | 5 | Dest Sel | R-type destination |
| `shamt` = `Inst[10:6]` | 5 | B Selector / ALU | immediate shift amount |
| `funct` = `Inst[5:0]` | 6 | Control Unit | R-type function |
| `imm16` = `Inst[15:0]` | 16 | Imm Generator | immediate / branch offset |
| `target26` = `Inst[25:0]` | 26 | Jump Target Gen | J-type target |

## Logisim 설계 가이드

1. Instruction Memory는 32-bit data width로 설정합니다.
2. memory component가 word-address를 요구하면 `PC[31:2]`를 주소로 쓰고, byte-address를 요구하면 `PC`를 그대로 넣습니다. 이 선택은 회로 전체에서 일관되게 유지합니다.
3. Inst Split은 Logisim splitter를 사용해 bit range를 명확히 분리합니다.
4. 각 field 출력에 라벨을 붙이고, `opcode/funct`는 Control Unit으로, register 번호는 Register/Dest Sel로, immediate field는 Imm Generator로 보냅니다.
5. instruction memory 초기화 파일을 쓰는 경우 endian/word order를 테스트 벡터와 맞춥니다.

## 검증 포인트

- 샘플 `add rd, rs, rt` instruction에서 opcode가 `000000`, funct가 `100000`으로 나옵니다.
- `lw`에서 opcode가 `100011`, `rs/rt/imm16`이 기대값으로 나옵니다.
- `j`에서 opcode가 `000010`, `target26`이 기대값으로 나옵니다.

## 흔한 실수

- `funct`를 `Inst[10:6]`으로 잘못 연결하는 실수. `Inst[10:6]`은 `shamt`입니다.
- memory 주소의 하위 2-bit 처리 방식이 instruction load 방식과 맞지 않는 실수.
- splitter bit order를 Logisim UI에서 반대로 설정하는 실수.

## Caveat / 주의사항

block diagram 하단 Control Unit 입력 근처에 `Inst[10:6] funct`처럼 보이는 라벨이 있습니다. 명세서 기준 MIPS `funct`는 반드시 `Inst[5:0]`이고, `Inst[10:6]`은 `shamt`입니다. 이 문서는 명세서를 우선합니다.

## 파이프라인 확장 시 메모

단일 사이클에서는 이 block의 입력과 출력이 같은 cycle 조합 경로에 있습니다. 파이프라인으로 확장할 때는 이 신호가 어느 stage에서 생성되고 어느 pipeline register에 저장되는지 `doc/mips_functional_spec.md`의 파이프라인 전달 기준과 대조해야 합니다.
