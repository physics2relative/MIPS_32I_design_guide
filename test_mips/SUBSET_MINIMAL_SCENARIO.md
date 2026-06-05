# `subset_minimal_chain.rom.hex` 테스트 시나리오

이 ROM은 이미 큰 chain에서 대부분 검증한 뒤, 아래 instruction만 짧게 재확인하기 위한 최소 테스트입니다.

```text
lw, sw, beq, addi, j, sub, or, slt, bne, ori, abs
```

## 실행 조건

```text
PC reset = 0x00000000
Delay slot = 없음
Data memory = little-endian
custom abs = opcode 0x00, funct 0x2C
```

## 흐름 요약

1. `addi`, `ori`로 기본 operand를 만듭니다.
2. `abs`, `sub`, `or`, `slt`로 ALU subset을 확인합니다.
3. `sw`로 `$7 = 0x1234`를 memory[0]에 저장하고, `lw`로 `$8`에 다시 읽습니다.
4. `beq $8,$7`가 taken되어 `$9 = 0xBAD` poison을 건너뛰어야 합니다.
5. `bne $6,$5`가 taken되어 `$10 = 0xBAD` poison을 건너뛰어야 합니다.
6. `j DONE`이 `$11 = 0xBAD` poison을 건너뛰어야 합니다.
7. 마지막에 `$30`에 핵심 결과를 OR 누적합니다.

## 핵심 기대값

```text
$3  = 0x00000008   // sub: 5 - (-3)
$4  = 0x00000007   // or: 5 | 3
$5  = 0x00000001   // slt: -3 < 5
$6  = 0x00000003   // abs(-3)
$7  = 0x00001234   // ori result
$8  = 0x00001234   // lw result
$9  = 0x00000000   // beq poison skipped
$10 = 0x00000000   // bne poison skipped
$11 = 0x00000000   // j poison skipped
$30 = 0x0000123F
```

## 빠른 디버깅

- `$8 != 0x1234`이면 `sw/lw` 경로를 먼저 봅니다.
- `$9 = 0xBAD`이면 `beq`가 taken되지 않은 것입니다.
- `$10 = 0xBAD`이면 `bne`가 taken되지 않은 것입니다.
- `$11 = 0xBAD`이면 `j` target 또는 PC control이 잘못된 것입니다.
- `$30 != 0x123F`이면 위 레지스터 중 하나가 다릅니다.
