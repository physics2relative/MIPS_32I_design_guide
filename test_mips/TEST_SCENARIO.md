# `instruction_chain_abs_all.rom.hex` 테스트 시나리오

이 문서는 `test_mips/instruction_chain_abs_all.rom.hex`를 Logisim Instruction Memory/ROM에 로드했을 때, 어떤 기능을 어떤 순서로 검증하는지 설명합니다.

## 1. 테스트 목적

이 ROM은 MIPS single-cycle Logisim 회로가 구현 대상 instruction을 한 번씩 통과하는지 확인하기 위한 **instruction chain 테스트**입니다. 각 instruction의 결과가 특정 레지스터 또는 메모리에 남고, 마지막에는 주요 레지스터 값을 모두 더해 `$30`에 checksum 형태로 저장합니다.

정상 종료 기준은 다음입니다.

```text
$30 = 0x246E10BA
```

하나의 instruction이라도 잘못 동작하면 중간 레지스터 값이 달라지고, 최종 `$30` 값도 달라지도록 구성되어 있습니다.

## 2. 실행 조건

```text
PC reset      = 0x00000000
Instruction  = 32-bit word 단위
Delay slot   = 없음
Data memory  = little-endian
HALT         = 마지막 instruction에서 자기 자신으로 jump
```

custom `abs` instruction은 프로젝트 정의를 따릅니다.

```text
abs rd, rs
opcode = 0x00
funct  = 0x2C
rt     = 0 권장 / 미사용
동작   = rd <- rs[31] ? (~rs + 1) : rs
```

## 3. 파일 구성

| 파일 | 용도 |
|---|---|
| `instruction_chain_abs_all.rom.hex` | Logisim `v2.0 raw` 형식 ROM 이미지 |
| `instruction_chain_abs_all.mem` | Verilog `$readmemh`용 header 없는 instruction word 목록 |
| `instruction_chain_abs_all.asm` | 사람이 읽는 assembly와 machine code 주석 |
| `instruction_chain_abs_all_listing.csv` | word index, byte PC, machine code, assembly CSV |
| `expected_result.txt` | 최종 기대값 요약 |

## 4. 시나리오 구간별 설명

### 4.1 초기화 및 즉시값 생성

```asm
addi $30, $0, 0
lui  $1, $0, 0x1234
ori  $1, $1, 0x5678
addi $2, $0, -5
addiu $3, $0, 10
```

검증 내용:

- `addi`, `addiu` sign-extended immediate 처리
- `lui` 상위 16비트 배치
- `ori` zero-extended immediate 처리
- `$1 = 0x12345678`, `$2 = 0xFFFFFFFB`, `$3 = 0x0000000A` 생성

### 4.2 R-type ALU 연산

```asm
add, addu, sub, subu, and, or, xor, nor, slt, sltu, abs
```

검증 내용:

- 산술 연산 결과
- bitwise 연산 결과
- signed 비교 `slt`
- unsigned 비교 `sltu`
- custom `abs` instruction

주요 기대값:

```text
$4  = 0x00000014
$5  = 0x0000001E   // 이후 memory test에서 0x0A로 갱신됨
$6  = 0x00000014   // 이후 memory test에서 0x00000005로 갱신됨
$7  = 0xFFFFFFEC   // 이후 memory test에서 0x00050A78로 갱신됨
$14 = 0x00000005
```

### 4.3 Shift 연산

```asm
sll, srl, sra, sllv, srlv, srav
```

검증 내용:

- shamt 기반 shift
- register lower 5-bit 기반 variable shift
- arithmetic right shift의 sign extension

주요 기대값:

```text
$15 = 0x00000014
$16 = 0x0000000A
$17 = 0xFFFFFFFD
$19 = 0x00000028
$20 = 0x00000005
$21 = 0xFFFFFFFF
```

### 4.4 I-type 논리/비교 연산

```asm
andi, xori, slti, sltiu
```

검증 내용:

- `andi`, `xori` zero extension
- `slti` signed 비교
- `sltiu` unsigned 비교

주요 기대값:

```text
$22 = 0x00000078
$23 = 0x00000088
$24 = 0x00000001   // 이후 jal 이후 addi로 0x00000002가 됨
$25 = 0x00000000
```

### 4.5 Data Memory load/store 및 byte lane 검증

초기 word store:

```asm
sw  $1, 0($0)      // memory[0] = 0x12345678
lw  $26, 0($0)
lb  $27, 0($0)
lbu $28, 1($0)
lh  $29, 0($0)
```

little-endian 기준 byte lane은 다음입니다.

```text
memory[0] = 0x78
memory[1] = 0x56
memory[2] = 0x34
memory[3] = 0x12
```

따라서 기대값은 다음입니다.

```text
$26 = 0x12345678
$27 = 0x00000078
$28 = 0x00000056
$29 = 0x00005678
```

byte/half store 이후:

```asm
sb  $3, 1($0)      // memory[1] = 0x0A
lbu $5, 1($0)      // $5 = 0x0A
sh  $14, 2($0)     // memory[2] = 0x05, memory[3] = 0x00
lhu $6, 2($0)      // $6 = 0x0005
lw  $7, 0($0)      // $7 = 0x00050A78
```

최종 memory word는 다음이어야 합니다.

```text
memory[0..3] = 0x00050A78
```

이 구간은 Data Memory의 핵심 검증 구간입니다.

- `lbu addr=1`은 `word[15:8]`을 읽어야 합니다.
- `sb addr=1`은 `word[15:8]`만 갱신해야 합니다.
- `sh addr=2`는 `word[31:16]`을 갱신해야 합니다.
- byte 접근은 misaligned가 아니어야 합니다.

### 4.6 Branch 검증

```asm
beq $5, $3, BEQ_OK
addi $13, $0, 0x0BAD
BEQ_OK:
bne $6, $3, BNE_OK
addi $25, $0, 0x0BAD
BNE_OK:
```

정상 흐름:

```text
$5 = 0x0000000A
$3 = 0x0000000A
beq taken -> $13 poison instruction skip

$6 = 0x00000005
$3 = 0x0000000A
bne taken -> $25 poison instruction skip
```

기대값:

```text
$13 = 0x00000000
$25 = 0x00000000
```

만약 `$13 = 0x00000BAD`라면 보통 branch comparator 자체보다 `$5`가 잘못 만들어졌는지 먼저 확인해야 합니다. 이 ROM에서는 `$5`가 Data Memory `sb/lbu addr=1` 결과에 의해 결정됩니다.

### 4.7 Jump / link 검증

```asm
j    CALL_START
jal  SUB
jalr $11, $31
jr   $11
j    CONTROL_DONE
```

정상 PC 흐름:

```text
0x000000A4 -> 0x000000C0   // j CALL_START
0x000000C0 -> 0x000000AC   // jal SUB, $31 = 0x000000C4
0x000000B0 -> 0x000000C4   // jalr $11,$31, $11 = 0x000000B4
0x000000C8 -> 0x000000B4   // jr $11
0x000000B8 -> 0x000000D0   // j CONTROL_DONE
```

기대 link 값:

```text
$31 = 0x000000C4
$11 = 0x000000B4
```

주의:

- `j`, `jal`은 immediate jump target을 사용합니다.
- `jr`, `jalr`은 `rs` register target을 사용합니다.
- `JumpSel`은 target 종류 선택용이고, 최종 PC가 jump target을 선택할지는 `Jump` 신호가 결정해야 합니다.

### 4.8 Checksum 누적

`CONTROL_DONE`부터 `$30`에 주요 레지스터 값을 순서대로 누적합니다.

```asm
addu $30, $0, $1
addu $30, $30, $2
...
addu $30, $30, $29
```

누적 대상은 `$1~$10`, `$12~$29`입니다. `$11`은 jump link 검증용으로 사용되지만 checksum에는 포함하지 않습니다.

최종 기대값:

```text
$30 = 0x246E10BA
```

## 5. 최종 레지스터 기대값

```text
$1  = 0x12345678
$2  = 0xFFFFFFFB
$3  = 0x0000000A
$4  = 0x00000014
$5  = 0x0000000A
$6  = 0x00000005
$7  = 0x00050A78
$8  = 0x00000018
$9  = 0x00000033
$10 = 0x00000004
$11 = 0x000000B4
$12 = 0x00000044
$13 = 0x00000000
$14 = 0x00000005
$15 = 0x00000014
$16 = 0x0000000A
$17 = 0xFFFFFFFD
$18 = 0x00000003
$19 = 0x00000028
$20 = 0x00000005
$21 = 0xFFFFFFFF
$22 = 0x00000078
$23 = 0x00000088
$24 = 0x00000002
$25 = 0x00000000
$26 = 0x12345678
$27 = 0x00000078
$28 = 0x00000056
$29 = 0x00005678
$30 = 0x246E10BA
$31 = 0x000000C4
```

## 6. 디버깅 우선순위

최종 `$30`이 틀리면 다음 순서로 확인하는 것을 권장합니다.

1. PC가 `CONTROL_DONE` `0x000000D0`에 도달하는지 확인합니다.
2. `$5`, `$7`, `$13`, `$28`을 먼저 확인합니다.
3. `$28 != 0x56`이면 `lbu addr=1` byte lane 선택 문제입니다.
4. `$5 != 0x0A`이면 `sb addr=1` 또는 `lbu addr=1` 문제입니다.
5. `$13 = 0xBAD`이면 보통 `$5 != $3` 때문에 `beq`가 실패한 후속 증상입니다.
6. PC가 이상 주소로 튀면 `PCSel`, `Jump`, `JumpSel`, `BranchTaken`, `JumpTargetGen`을 확인합니다.

Data Memory byte lane 기준:

```text
Addr[1:0] = 00 -> ReadWord[7:0]
Addr[1:0] = 01 -> ReadWord[15:8]
Addr[1:0] = 10 -> ReadWord[23:16]
Addr[1:0] = 11 -> ReadWord[31:24]
```

Misaligned 조건:

```text
byte 접근  -> 항상 aligned
half 접근  -> Addr[0] == 1이면 misaligned
word 접근  -> Addr[1:0] != 00이면 misaligned
```
