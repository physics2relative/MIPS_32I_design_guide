# MIPS Logisim CPU 기능 명세서

> **정본 대상 문서:** 이 문서는 MIPS Logisim CPU 프로젝트의 1차 정본 기능 명세서입니다. 사람과 AI 에이전트가 모두 읽고 사용할 수 있도록 한국어 설명을 기본으로 작성했습니다. 기존 원천 문서는 추적 가능한 입력 자료로 보존되며, 이 문서는 회로 파일, 테스트 벡터, 원시 구현 자산을 이동·삭제·폐기하지 않습니다.

- 생성 시각: 2026-05-18T04:59:57Z
- 대상 프로젝트: `eda-centos7:/user/choi.jw/PROJECT/MIPS_logisim`
- 필수 산출 경로: `doc/mips_functional_spec.md`
- 선택 산출 경로: `doc/archive_candidates/MANIFEST.md`
- 작업 경계: 문서 전용 작업입니다. 회로, 테스트 벡터, 원시 자산은 이동하거나 수정하지 않습니다.

## 1. 출처 우선순위와 범위

출처 간 충돌이 있으면 아래 순서로 해석하고, 조용히 섞지 말고 주의사항에 기록합니다.

1. 요구사항: `/home/choi/.omx/specs/deep-interview-mips-functional-spec.md`
2. 승인된 실행 계획: `/home/choi/.omx/plans/mips-functional-spec-consolidation-ralplan.md`, PRD, 테스트 명세
3. 명령어/제어 문서:
   - `doc/mips_rv32i_instruction_reference.md`
   - `doc/mips_control_signals.md`
   - `doc/mips_control_signals_single_cycle.md`
   - `doc/mips_control_signals_pipelined.md`
4. 구현 가이드: `guide/README.md`

이 명세서는 프로젝트의 RV32I 대응 학습 목표에 맞춰 확정된 MIPS subset만 다룹니다. 새 ISA 지원을 추가하지 않습니다.

## 2. 한 장 요약

### 구현 대상 하드웨어 명령어 집합

```text
add, addu, sub, subu,
and, or, xor, nor,
slt, sltu,
sll, srl, sra,
sllv, srlv, srav,
addi, addiu,
andi, ori, xori,
slti, sltiu,
lui,
lb, lbu, lh, lhu, lw,
sb, sh, sw,
beq, bne,
j, jal, jr, jalr
```

### 제외 / 의사 명령어 전용 명령어 집합

```text
mult, multu, div, divu,
mfhi, mflo,
ecall, ebreak, fence,
auipc,
blt, bge, bltu, bgeu as 실제 하드웨어 명령어
```

`blt`, `bge`, `bltu`, `bgeu`는 `slt`/`sltu`와 `beq`/`bne`를 조합한 pseudo 전용 sequence로만 문서화합니다. 이 네 명령어를 실제 하드웨어 decode row로 추가하지 않습니다.

### 단계별 제어 의미

- **단일 사이클 `JumpSel`:** 1-bit selector입니다. `0=JUMP_IMM26`, `1=JUMP_REG`이며, `Jump=1`일 때만 의미가 있습니다.
- **단일 사이클 `PCSel`:** 단일 사이클 `PCControl` 경로가 생성하는 2-bit 값입니다. `PC_PLUS4`, `PC_BRANCH`, `PC_JUMP`를 구분합니다.
- **파이프라인 `JumpSel`:** 2-bit selector입니다. `00=JUMP_NONE`, `01=JUMP_IMM26`, `10=JUMP_REG`, `11=예약`입니다.
- **파이프라인 `PCSel`:** 분기/점프 결과에서 나온 EX 단계 재지정 결정입니다. 단일 사이클 `PCControl` 출력과 동일 산출물로 취급하지 않습니다.
- **`RsUsed`/`RtUsed`:** 파이프라인 해저드/dependency 판단을 위한 보조 제어입니다. 로드-사용, 포워딩, 스톨 판단에 사용하며, 원천 문서가 명시하지 않는 한 단일 사이클 필수 제어로 역이식하지 않습니다.

## 3. 필수 커버리지 매트릭스

| 명령어 / 그룹 | 요구 상태 | 출처 섹션/문서 | 단일 사이클 표 포함 여부 | 파이프라인 표 포함 여부 | 비고 |
|---|---|---|---|---|---|
| `add` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `addu` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sub` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `subu` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `and` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `or` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `xor` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `nor` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `slt` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sltu` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sll` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `srl` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sra` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sllv` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `srlv` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `srav` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `addi` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `addiu` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `andi` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `ori` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `xori` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `slti` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sltiu` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `lui` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `lb` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `lbu` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `lh` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `lhu` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `lw` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sb` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sh` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `sw` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `beq` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `bne` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `j` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `jal` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `jr` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `jalr` | 구현 대상 하드웨어 명령어 | 요구사항 명세; 명령어 reference; 단일 사이클/파이프라인 제어 문서 | decode/제어 행 또는 동등 그룹으로 포함 | decode/제어 행 또는 동등 그룹으로 포함 | 확인된 subset 밖 ISA 추가 없음 |
| `mult` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | RV32M 계열 multiply/divide에 가깝고 HI/LO 및 multi-cycle/긴 critical path 이슈가 있어 제외합니다. |
| `multu` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | RV32M 계열 multiply/divide에 가깝고 HI/LO 및 multi-cycle/긴 critical path 이슈가 있어 제외합니다. |
| `div` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | RV32M 계열 multiply/divide에 가깝고 HI/LO 및 multi-cycle/긴 critical path 이슈가 있어 제외합니다. |
| `divu` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | RV32M 계열 multiply/divide에 가깝고 HI/LO 및 multi-cycle/긴 critical path 이슈가 있어 제외합니다. |
| `mfhi` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | HI/LO datapath가 범위 밖이므로 제외합니다. |
| `mflo` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | HI/LO datapath가 범위 밖이므로 제외합니다. |
| `ecall` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | system/fence 계열로 과제 CPU 검증 범위 밖입니다. |
| `ebreak` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | system/fence 계열로 과제 CPU 검증 범위 밖입니다. |
| `fence` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | system/fence 계열로 과제 CPU 검증 범위 밖입니다. |
| `auipc` | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | 이 프로젝트 범위의 classic MIPS에는 직접 대응되는 PC-relative upper-immediate 명령이 없습니다. |
| blt | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | slt/sltu와 beq/bne 조합의 pseudo 전용 sequence입니다. 실제 하드웨어 decode/제어 행으로 만들지 않습니다. |
| bge | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | slt/sltu와 beq/bne 조합의 pseudo 전용 sequence입니다. 실제 하드웨어 decode/제어 행으로 만들지 않습니다. |
| bltu | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | slt/sltu와 beq/bne 조합의 pseudo 전용 sequence입니다. 실제 하드웨어 decode/제어 행으로 만들지 않습니다. |
| bgeu | 제외 / 하드웨어 미구현 | 요구사항 명세; 명령어 reference 제외 표 | 미구현 | 미구현 | slt/sltu와 beq/bne 조합의 pseudo 전용 sequence입니다. 실제 하드웨어 decode/제어 행으로 만들지 않습니다. |

## 4. 명령어 형식, 인코딩, 동작, 의사 명령어 시퀀스

프로젝트는 32-bit 고정 MIPS 인코딩을 사용합니다. 기본 field는 `opcode[31:26]`, `rs[25:21]`, `rt[20:16]`, `rd[15:11]`, `shamt[10:6]`, `funct[5:0]`, `imm[15:0]`, `target[25:0]`입니다. Immediate 의미는 source table을 따릅니다. arithmetic/load/store/branch offset은 별도 명시가 없으면 sign extension을 사용하고, logical immediate는 zero extension을 사용합니다. `lui`는 16-bit immediate를 상위 halfword에 배치하며, jump target은 `{PC+4[31:28], target26, 2'b00}`입니다.

### 2. MIPS 기계어 기본 구조

#### R-type

```text
31      26 25   21 20   16 15   11 10    6 5      0
+---------+-------+-------+-------+--------+--------+
| opcode  |  rs   |  rt   |  rd   | shamt  | funct  |
+---------+-------+-------+-------+--------+--------+
   6 bits   5 bits  5 bits  5 bits  5 bits   6 bits
```

R-type의 `opcode`는 항상 `000000`입니다. 실제 연산은 `funct`로 구분합니다.

#### I-type

```text
31      26 25   21 20   16 15                         0
+---------+-------+-------+-----------------------------+
| opcode  |  rs   |  rt   |        immediate            |
+---------+-------+-------+-----------------------------+
   6 bits   5 bits  5 bits          16 bits
```

I-type은 `rt`가 destination인 경우와 source인 경우가 모두 있으므로 control logic에서 구분해야 합니다.

#### J-type

```text
31      26 25                                            0
+---------+------------------------------------------------+
| opcode  |                 target                         |
+---------+------------------------------------------------+
   6 bits                    26 bits
```

Jump target은 다음처럼 계산합니다.

```text
JumpTarget = { PC+4[31:28], target[25:0], 2'b00 }
```

### 3. R-type ALU 명령어

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| add rd, rs, rt | ADD | op=000000 rs rt rd shamt=00000 funct=100000 | R[rd] <- R[rs] + R[rt] | add $t0, $t1, $t2 |
| addu rd, rs, rt | ADD에 더 가까움 | op=000000 rs rt rd shamt=00000 funct=100001 | R[rd] <- R[rs] + R[rt] without overflow trap | addu $t0, $t1, $t2 |
| sub rd, rs, rt | SUB | op=000000 rs rt rd shamt=00000 funct=100010 | R[rd] <- R[rs] - R[rt] | sub $t0, $t1, $t2 |
| subu rd, rs, rt | SUB에 더 가까움 | op=000000 rs rt rd shamt=00000 funct=100011 | R[rd] <- R[rs] - R[rt] without overflow trap | subu $t0, $t1, $t2 |
| and rd, rs, rt | AND | op=000000 rs rt rd shamt=00000 funct=100100 | R[rd] <- R[rs] & R[rt] | and $t0, $t1, $t2 |
| or rd, rs, rt | OR | op=000000 rs rt rd shamt=00000 funct=100101 | R[rd] <- R[rs] &#124; R[rt] | or $t0, $t1, $t2 |
| xor rd, rs, rt | XOR | op=000000 rs rt rd shamt=00000 funct=100110 | R[rd] <- R[rs] ^ R[rt] | xor $t0, $t1, $t2 |
| nor rd, rs, rt | MIPS 추가 | op=000000 rs rt rd shamt=00000 funct=100111 | R[rd] <- ~(R[rs] &#124; R[rt]) | nor $t0, $t1, $t2 |
| slt rd, rs, rt | SLT | op=000000 rs rt rd shamt=00000 funct=101010 | R[rd] <- signed(R[rs]) < signed(R[rt]) ? 1 : 0 | slt $t0, $t1, $t2 |
| sltu rd, rs, rt | SLTU | op=000000 rs rt rd shamt=00000 funct=101011 | R[rd] <- unsigned(R[rs]) < unsigned(R[rt]) ? 1 : 0 | sltu $t0, $t1, $t2 |

구현 팁:

- RV32I는 arithmetic overflow exception을 발생시키지 않으므로, 의미상으로는 `addu/subu`가 더 가깝습니다.
- 과제에서 MIPS instruction 이름을 기대할 가능성이 있으므로 `add/sub`도 같이 decode하되 overflow exception은 생략한다고 문서화하는 방향이 안전합니다.
- `nor`는 RV32I 직접 대응은 아니지만 MIPS 실제 instruction이며 구현 대상에 포함합니다.

### 4. Shift 명령어

#### 즉시값 shift

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| sll rd, rt, shamt | SLLI | op=000000 rs=00000 rt rd shamt funct=000000 | R[rd] <- R[rt] << shamt | sll $t0, $t1, 4 |
| srl rd, rt, shamt | SRLI | op=000000 rs=00000 rt rd shamt funct=000010 | R[rd] <- R[rt] >> shamt, zero-fill | srl $t0, $t1, 4 |
| sra rd, rt, shamt | SRAI | op=000000 rs=00000 rt rd shamt funct=000011 | R[rd] <- signed(R[rt]) >>> shamt, sign-fill | sra $t0, $t1, 4 |

#### 가변 shift

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| sllv rd, rt, rs | SLL | op=000000 rs rt rd shamt=00000 funct=000100 | R[rd] <- R[rt] << R[rs][4:0] | sllv $t0, $t1, $t2 |
| srlv rd, rt, rs | SRL | op=000000 rs rt rd shamt=00000 funct=000110 | R[rd] <- R[rt] >> R[rs][4:0], zero-fill | srlv $t0, $t1, $t2 |
| srav rd, rt, rs | SRA | op=000000 rs rt rd shamt=00000 funct=000111 | R[rd] <- signed(R[rt]) >>> R[rs][4:0] | srav $t0, $t1, $t2 |

구현 팁:

- immediate shift는 `shamt` field를 사용합니다.
- variable shift는 `rs`의 하위 5비트를 shift amount로 사용합니다.
- shift instruction은 ALU 내부에 shifter path를 추가하면 구현할 수 있어 가산점 대비 효율이 좋습니다.

### 5. I-type ALU / Immediate 명령어

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| addi rt, rs, imm | ADDI | op=001000 rs rt imm | R[rt] <- R[rs] + sign_ext(imm) | addi $t0, $t1, -4 |
| addiu rt, rs, imm | ADDI에 더 가까움 | op=001001 rs rt imm | R[rt] <- R[rs] + sign_ext(imm) without overflow trap | addiu $t0, $t1, 16 |
| andi rt, rs, imm | ANDI | op=001100 rs rt imm | R[rt] <- R[rs] & zero_ext(imm) | andi $t0, $t1, 0x00ff |
| ori rt, rs, imm | ORI | op=001101 rs rt imm | R[rt] <- R[rs] &#124; zero_ext(imm) | ori $t0, $t1, 0x0100 |
| xori rt, rs, imm | XORI | op=001110 rs rt imm | R[rt] <- R[rs] ^ zero_ext(imm) | xori $t0, $t1, 0xffff |
| slti rt, rs, imm | SLTI | op=001010 rs rt imm | R[rt] <- signed(R[rs]) < signed(sign_ext(imm)) ? 1 : 0 | slti $t0, $t1, 10 |
| sltiu rt, rs, imm | SLTIU | op=001011 rs rt imm | R[rt] <- unsigned(R[rs]) < unsigned(sign_ext(imm)) ? 1 : 0 | sltiu $t0, $t1, 10 |
| lui rt, imm | LUI | op=001111 rs=00000 rt imm | R[rt] <- {imm, 16'b0} | lui $t0, 0x1234 |

구현 팁:

- `andi`, `ori`, `xori`는 zero extend입니다.
- `addi`, `addiu`, `slti`, `sltiu`는 sign extend입니다.
- `lui`는 ALU를 거치지 않고 immediate path에서 `imm << 16`을 쓰기 되돌림 mux에 넣어도 됩니다.

### 6. Load 명령어

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| lb rt, offset(rs) | LB | op=100000 rs rt offset | R[rt] <- sign_ext(Mem8[R[rs] + sign_ext(offset)]) | lb $t0, 3($s0) |
| lbu rt, offset(rs) | LBU | op=100100 rs rt offset | R[rt] <- zero_ext(Mem8[R[rs] + sign_ext(offset)]) | lbu $t0, 3($s0) |
| lh rt, offset(rs) | LH | op=100001 rs rt offset | R[rt] <- sign_ext(Mem16[R[rs] + sign_ext(offset)]) | lh $t0, 2($s0) |
| lhu rt, offset(rs) | LHU | op=100101 rs rt offset | R[rt] <- zero_ext(Mem16[R[rs] + sign_ext(offset)]) | lhu $t0, 2($s0) |
| lw rt, offset(rs) | LW | op=100011 rs rt offset | R[rt] <- Mem32[R[rs] + sign_ext(offset)] | lw $t0, 0($s0) |

구현 팁:

- effective address는 `R[rs] + sign_ext(offset)`입니다.
- `lb/lbu/lh/lhu`를 지원하려면 memory read data에서 byte/halfword를 선택하고 sign/zero extend하는 logic이 필요합니다.
- byte address 하위 비트 `addr[1:0]`를 사용해 어떤 byte/halfword를 선택할지 결정해야 합니다.
- 처음에는 aligned access만 테스트하는 것이 좋습니다.

### 7. Store 명령어

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| sb rt, offset(rs) | SB | op=101000 rs rt offset | Mem8[R[rs] + sign_ext(offset)] <- R[rt][7:0] | sb $t0, 3($s0) |
| sh rt, offset(rs) | SH | op=101001 rs rt offset | Mem16[R[rs] + sign_ext(offset)] <- R[rt][15:0] | sh $t0, 2($s0) |
| sw rt, offset(rs) | SW | op=101011 rs rt offset | Mem32[R[rs] + sign_ext(offset)] <- R[rt] | sw $t0, 0($s0) |

구현 팁:

- `sw`만 있으면 word 쓰기 enable 하나로 충분합니다.
- `sb/sh`까지 지원하려면 byte enable 또는 read-modify-write 방식이 필요합니다.
- Logisim memory component를 어떻게 구성하느냐에 따라 `sb/sh` 난이도가 크게 달라집니다.

### 8. Branch 명령어

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| beq rs, rt, label | BEQ | op=000100 rs rt offset | if R[rs] == R[rt], PC <- PC+4 + (sign_ext(offset) << 2) | beq $t0, $t1, done |
| bne rs, rt, label | BNE | op=000101 rs rt offset | if R[rs] != R[rt], PC <- PC+4 + (sign_ext(offset) << 2) | bne $t0, $t1, loop |

Branch offset 인코딩:

```text
offset = (label_address - (PC + 4)) >> 2
```

구현 팁:

- 이 설계의 branch taken 판정은 ALU zero flag를 사용하지 않고 별도 `BranchComp`가 수행합니다.
- `beq`는 `BranchComp` 내부 equality comparator의 `EQ = (Data_rs == Data_rt)` 결과를 사용합니다.
- `bne`는 같은 `EQ` 결과를 invert한 `!EQ`를 사용합니다.
- ALU는 branch 조건 비교가 아니라 branch target `PC+4 + (sign_ext(offset) << 2)` 계산만 담당합니다.
- RV32I의 `blt/bge/bltu/bgeu`는 MIPS real instruction으로 직접 넣지 않고 다음 의사 명령어 시퀀스로 처리합니다.

```asm
## blt rs, rt, label pseudo
slt  $at, rs, rt
bne  $at, $zero, label

## bge rs, rt, label pseudo
slt  $at, rs, rt
beq  $at, $zero, label

## bltu rs, rt, label pseudo
sltu $at, rs, rt
bne  $at, $zero, label

## bgeu rs, rt, label pseudo
sltu $at, rs, rt
beq  $at, $zero, label
```

### 9. Jump / Link 명령어

| 명령어 | RV32I 대응 | 기계어 형식 | 동작 | 어셈블리 예시 |
| --- | --- | --- | --- | --- |
| j target | JAL x0, target에 해당 | op=000010 target | PC <- {PC+4[31:28], target, 2'b00} | j main |
| jal target | JAL | op=000011 target | R[31] <- PC+4; PC <- {PC+4[31:28], target, 2'b00} | jal func |
| jr rs | JALR x0, rs, 0에 해당 | op=000000 rs rt=00000 rd=00000 shamt=00000 funct=001000 | PC <- R[rs] | jr $ra |
| jalr rd, rs | JALR에 유사 | op=000000 rs rt=00000 rd shamt=00000 funct=001001 | R[rd] <- PC+4; PC <- R[rs] | jalr $ra, $t0 |

구현 팁:

- 본 과제에서는 delay slot을 구현하지 않으므로 link 값은 `PC+4`로 둡니다.
- 실제 MIPS delay slot 기준과는 다를 수 있으므로 보고서에 명시합니다.
- `jal`을 구현하려면 쓰기 되돌림 mux에 `PC+4` 입력이 추가되어야 합니다.
- `jal` destination은 `$31`입니다.
- `jr/jalr`는 레지스터 값을 PC로 보내는 path가 필요합니다.
- `jr` 직전 instruction이 target register를 쓰는 경우 해저드가 생길 수 있으므로, 포워딩 또는 스톨 정책을 정해야 합니다.

### 11. 최종 구현/제외 요약

#### 확정 구현 대상

```text
add, addu, sub, subu,
and, or, xor, nor,
slt, sltu,
sll, srl, sra,
sllv, srlv, srav,
addi, addiu,
andi, ori, xori,
slti, sltiu,
lui,
lb, lbu, lh, lhu, lw,
sb, sh, sw,
beq, bne,
j, jal, jr, jalr
```

#### 제외 대상

```text
mult, multu, div, divu,
mfhi, mflo,
ecall, ebreak, fence,
auipc,
blt, bge, bltu, bgeu as 실제 하드웨어 명령어
```

`blt/bge/bltu/bgeu`는 CPU 명령어으로 직접 구현하지 않고 `slt/sltu + beq/bne` 의사 명령어 시퀀스로 처리합니다.

## 5. 제어 신호 정의와 인코딩

제어 모델은 설계별로 유지해야 합니다. 단일 사이클과 파이프라인 제어은 이름이 같아도 폭, 생성 단계, 해저드 역할이 다를 수 있습니다.

### 5.1 제어 문서 분리 기준

### MIPS 제어 신호 문서

기준 명령어 문서: `doc/mips_rv32i_instruction_reference.md`

제어 신호 정의를 CPU 구현 단계별로 분리했습니다.

| 문서 | 용도 |
| --- | --- |
| mips_control_signals_single_cycle.md | MIPS 32 단일 사이클 CPU 구현용 제어 신호 정의입니다. PCSel까지 포함하고, 파이프라인 해저드/포워딩 신호는 제외합니다. |
| mips_control_signals_pipelined.md | 5단계 파이프라인 CPU 구현용 제어 신호 정의입니다. 파이프라인 레지스터 전달 기준, 포워딩, 스톨, 플러시, RsUsed/RtUsed까지 포함합니다. |

권장 진행은 단일 사이클 문서 기준으로 먼저 Logisim 회로를 만들고, 기능 검증이 끝난 뒤 파이프라인 문서 기준으로 파이프라인 레지스터와 해저드 로직을 추가하는 것입니다.

공통으로 유지하는 제어 추상화는 다음입니다.

```text
RegWEn
DestSel
ASel
BSel
ImmSel
BrSel
ALUSel
WBSel
WdLen
MemRW
LoadEx
JumpSel
```

단일 사이클과 파이프라인의 가장 큰 차이는 다음입니다.

| 구분 | 단일 사이클 | 파이프라인 |
| --- | --- | --- |
| PCSel | 같은 사이클에서 분기 비교 결과까지 보고 바로 결정합니다. | EX 단계에서 PCSel_EX 또는 재지정 신호로 결정합니다. |
| 해저드 | 필요 없습니다. | 포워딩, 스톨, 플러시가 필요합니다. |
| `RsUsed/RtUsed` | 필수는 아닙니다. | 로드-사용 해저드 판단에 필요합니다. |
| 제어 전달 | 파이프라인 레지스터가 없습니다. | `ID/EX`, `EX/MEM`, `MEM/WB`로 단계별 제어를 전달합니다. |
| 디버그 초점 | 명령어별 데이터패스와 제어 정확성입니다. | 사이클별 단계 이동, 버블, 플러시, 포워딩 정확성입니다. |

### 5.2 단일 사이클 제어 정의, 인코딩, 전체 표

#### 3. 단일 사이클 데이터패스 제어 목록

| 신호 | 폭 | 설명 |
| --- | ---: | --- |
| RegWEn | 1 | 레지스터 파일 쓰기 enable입니다. $zero write는 레지스터 파일 내부에서 무시합니다. |
| DestSel | 2 | 쓰기 대상 레지스터 선택입니다. rt, rd, $31, none을 구분합니다. |
| `WBSel` | 2 | 레지스터 파일 쓰기 데이터 선택입니다. |
| `ASel` | 2 | ALU 입력 A 선택입니다. |
| `BSel` | 3 | ALU 입력 B 선택입니다. shift, branch target 계산까지 고려해 3-bit로 둡니다. |
| `ImmSel` | 3 | 즉시값 생성 방식 선택입니다. |
| BrSel | 3 | 분기 비교 종류 선택입니다. 현재 직접 구현 분기는 beq, bne입니다. |
| `ALUSel` | 4 | ALU operation 선택입니다. |
| `WdLen` | 2 | load/store 접근 폭입니다. |
| `MemRW` | 3 | 데이터 메모리 operation 종류입니다. |
| LoadEx | 1 | load result extension 방식입니다. 0은 sign-extend, 1은 zero-extend입니다. |
| `Branch` | 1 | 분기 명령어 여부입니다. |
| Jump | 1 | 점프 명령어 여부입니다. j/jal/jr/jalr에서 1입니다. |
| JumpSel | 1 | jump일 때 target source를 고릅니다. 0은 immediate target, 1은 register target입니다. Jump=0이면 무시됩니다. |
| PCSel | 2 | 다음 PC 선택입니다. PCControl 블록이 생성합니다. |

#### 4. 인코딩 정의

##### `RegWEn`, `Branch`, `Jump`, `LoadEx`

| 신호 | 값 | 의미 |
| --- | --- | --- |
| RegWEn | 0 | register 쓰기 없음 |
| RegWEn | 1 | register 쓰기 수행 |
| Branch | 0 | 분기 명령어 아님 |
| Branch | 1 | 분기 명령어 |
| Jump | 0 | 점프 명령어 아님 |
| Jump | 1 | 점프 명령어 |
| LoadEx | 0 | load result sign-extend. lb, lh에서 사용 |
| LoadEx | 1 | load result zero-extend. lbu, lhu에서 사용 |

##### `DestSel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | DEST_RT | rt에 write합니다. I-type ALU, load, lui에서 사용합니다. |
| 01 | DEST_RD | rd에 write합니다. R-type과 jalr에서 사용합니다. |
| 10 | DEST_RA | $31에 write합니다. jal에서 사용합니다. |
| 11 | DEST_NONE | 쓰기 대상이 없습니다. |

##### `WBSel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | WB_MEM | 데이터 메모리 load result를 쓰기 되돌림합니다. |
| 01 | WB_ALU | ALU result를 쓰기 되돌림합니다. |
| 10 | WB_PC4 | PC + 4를 쓰기 되돌림합니다. jal/jalr에서 사용합니다. |
| 11 | WB_NONE | write-back 데이터가 없습니다. |

##### `ASel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | A_RS | 레지스터 파일 Data_rs를 ALU A로 사용합니다. |
| 01 | A_PC4 | PC + 4를 ALU A로 사용합니다. branch target 계산에 사용합니다. |
| 10 | A_ZERO | constant zero를 ALU A로 사용합니다. lui에 사용합니다. |
| 11 | A_RT | 레지스터 파일 Data_rt를 ALU A로 사용합니다. shift operand에 사용합니다. |

##### `BSel[2:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 000 | B_RT | 레지스터 파일 Data_rt를 ALU B로 사용합니다. |
| 001 | B_IMM | immediate generator 출력을 ALU B로 사용합니다. |
| 010 | B_BR_OFFSET | sign_ext(imm16) << 2를 ALU B로 사용합니다. |
| 011 | B_SHAMT | shamt를 ALU B로 사용합니다. immediate shift에 사용합니다. |
| 100 | B_RS_LOW5 | Data_rs[4:0]을 ALU B로 사용합니다. variable shift에 사용합니다. |
| 101 | B_ZERO | constant zero입니다. |
| `110` | 예약 | 예약입니다. |
| 111 | B_NONE | 사용하지 않습니다. |

##### `ImmSel[2:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 000 | IMM_SIGN16 | sign_ext(inst[15:0]) |
| 001 | IMM_ZERO16 | zero_ext(inst[15:0]) |
| 010 | IMM_LUI16 | {inst[15:0], 16'b0} |
| 011 | IMM_BRANCH16 | sign_ext(inst[15:0]) << 2 |
| 100 | IMM_J26 | {PC+4[31:28], inst[25:0], 2'b00} |
| 111 | IMM_NONE | immediate를 사용하지 않습니다. |

##### `BrSel[2:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 000 | BR_NONE | branch가 아닙니다. |
| 001 | BR_EQ | Data_rs == Data_rt이면 branch taken입니다. |
| 010 | BR_NE | Data_rs != Data_rt이면 branch taken입니다. |
| 011 | BR_LT | 예약입니다. |
| 100 | BR_GE | 예약입니다. |
| 101 | BR_LTU | 예약입니다. |
| 110 | BR_GEU | 예약입니다. |
| `111` | 예약 | 예약입니다. |

현재 설계에서는 `beq`, `bne`만 직접 구현하므로 `BrSel`을 1-bit `BrNE`로 줄여도 됩니다. 다만 이 문서에서는 파이프라인 확장과 pseudo branch 검증 여지를 위해 3-bit를 유지합니다.

##### `ALUSel[3:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 0000 | ALU_ADD | A + B |
| 0001 | ALU_SUB | A - B |
| 0010 | ALU_AND | A & B |
| 0011 | ALU_OR | A &#124; B |
| 0100 | ALU_XOR | A ^ B |
| 0101 | ALU_SLT | signed A < B |
| 0110 | ALU_SLTU | unsigned A < B |
| 0111 | ALU_SLL | A << B[4:0] |
| 1000 | ALU_SRL | A >> B[4:0], zero-fill |
| 1001 | ALU_SRA | signed A >>> B[4:0], sign-fill |
| 1010 | ALU_NOR | ~(A &#124; B) |
| 1111 | ALU_NONE | ALU result를 사용하지 않습니다. |

##### `WdLen[1:0]`, `MemRW[2:0]`

| 신호 | 값 | 이름 | 의미 |
| --- | --- | --- | --- |
| WdLen | 00 | MEM_BYTE | byte access |
| WdLen | 01 | MEM_HALF | halfword access |
| WdLen | 10 | MEM_WORD | word access |
| WdLen | 11 | MEM_NONE | memory access 없음 |
| MemRW | 000 | MEM_SB | byte store |
| MemRW | 001 | MEM_SH | halfword store |
| MemRW | 010 | MEM_SW | word store |
| MemRW | 011 | MEM_LOAD | load |
| MemRW | 100 | MEM_IDLE | memory access 없음 |

##### `JumpSel`

`JumpSel`은 1-bit입니다. `Jump=0`이면 `JumpSel`은 무시됩니다.

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 0 | JUMP_IMM26 | j, jal용 32-bit jump target을 선택합니다. JumpTarget = {PC+4[31:28], target26, 2'b00} |
| 1 | JUMP_REG | jr, jalr용 register target을 선택합니다. RegJumpTarget = Data_rs |

`JumpSelector`는 다음처럼 단순한 2-input mux로 둡니다.

```text
SelectedJumpTarget = (JumpSel == 0) ? JumpTarget : Data_rs
```

##### `PCSel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | PC_PLUS4 | PC + 4 |
| 01 | PC_BRANCH | branch target입니다. 이 설계에서는 분기 명령어일 때 ALUResult = PC+4 + (sign_ext(imm16) << 2)이며, taken 여부는 별도 `BranchComp`가 결정합니다. |
| 10 | PC_JUMP | JumpSelector가 고른 SelectedJumpTarget입니다. j/jal/jr/jalr 모두 이 입력을 사용합니다. |
| `11` | 예약 | 예약입니다. |

`PCControl`은 다음처럼 `PCSel`을 만듭니다.

```text
BranchTaken = Branch && BranchComp(Data_rs, Data_rt, BrSel)  // ALU flag가 아니라 별도 comparator 결과

if Jump:
    PCSel = PC_JUMP
else if BranchTaken:
    PCSel = PC_BRANCH
else:
    PCSel = PC_PLUS4
```

#### 5. 단일 사이클 NOP 기본값

```text
RegWEn=0, DestSel=DEST_NONE(11), WBSel=WB_NONE(11),
ASel=A_ZERO(10), BSel=B_ZERO(101), ImmSel=IMM_NONE(111),
BrSel=BR_NONE(000), ALUSel=ALU_NONE(1111),
WdLen=MEM_NONE(11), MemRW=MEM_IDLE(100), LoadEx=0,
Branch=0, Jump=0, JumpSel=0, PCSel=PC_PLUS4(00)
```

#### 6. 명령어별 단일 사이클 제어 표

표의 각 항목은 `이름(숫자)` 형식입니다. `X`는 don't care입니다. Logisim 구현에서는 `X`도 가능하면 NOP에 가까운 안전한 값으로 둡니다.

##### 6.1 R-type ALU

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | Branch | Jump | JumpSel | PCSel |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| add, addu | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_ADD(0000) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| sub, subu | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_SUB(0001) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| and | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_AND(0010) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| or | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_OR(0011) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| xor | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_XOR(0100) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| nor | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_NOR(1010) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| slt | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_SLT(0101) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| sltu | 1 | DEST_RD(01) | A_RS(00) | B_RT(000) | IMM_NONE(111) | BR_NONE(000) | ALU_SLTU(0110) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |

##### 6.2 Shift

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | Branch | Jump | JumpSel | PCSel |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| sll | 1 | DEST_RD(01) | A_RT(11) | B_SHAMT(011) | IMM_NONE(111) | BR_NONE(000) | ALU_SLL(0111) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| srl | 1 | DEST_RD(01) | A_RT(11) | B_SHAMT(011) | IMM_NONE(111) | BR_NONE(000) | ALU_SRL(1000) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| sra | 1 | DEST_RD(01) | A_RT(11) | B_SHAMT(011) | IMM_NONE(111) | BR_NONE(000) | ALU_SRA(1001) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| sllv | 1 | DEST_RD(01) | A_RT(11) | B_RS_LOW5(100) | IMM_NONE(111) | BR_NONE(000) | ALU_SLL(0111) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| srlv | 1 | DEST_RD(01) | A_RT(11) | B_RS_LOW5(100) | IMM_NONE(111) | BR_NONE(000) | ALU_SRL(1000) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| srav | 1 | DEST_RD(01) | A_RT(11) | B_RS_LOW5(100) | IMM_NONE(111) | BR_NONE(000) | ALU_SRA(1001) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |

##### 6.3 I-type ALU / Immediate

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | Branch | Jump | JumpSel | PCSel |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| addi, addiu | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| andi | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_ZERO16(001) | BR_NONE(000) | ALU_AND(0010) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| ori | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_ZERO16(001) | BR_NONE(000) | ALU_OR(0011) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| xori | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_ZERO16(001) | BR_NONE(000) | ALU_XOR(0100) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| slti | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_SLT(0101) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| sltiu | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_SLTU(0110) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |
| lui | 1 | DEST_RT(00) | A_ZERO(10) | B_IMM(001) | IMM_LUI16(010) | BR_NONE(000) | ALU_ADD(0000) | WB_ALU(01) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 0 | X | PC_PLUS4(00) |

##### 6.4 Load

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | Branch | Jump | JumpSel | PCSel |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| lb | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_MEM(00) | MEM_BYTE(00) | MEM_LOAD(011) | 0 | 0 | 0 | X | PC_PLUS4(00) |
| lbu | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_MEM(00) | MEM_BYTE(00) | MEM_LOAD(011) | 1 | 0 | 0 | X | PC_PLUS4(00) |
| lh | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_MEM(00) | MEM_HALF(01) | MEM_LOAD(011) | 0 | 0 | 0 | X | PC_PLUS4(00) |
| lhu | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_MEM(00) | MEM_HALF(01) | MEM_LOAD(011) | 1 | 0 | 0 | X | PC_PLUS4(00) |
| lw | 1 | DEST_RT(00) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_MEM(00) | MEM_WORD(10) | MEM_LOAD(011) | X | 0 | 0 | X | PC_PLUS4(00) |

##### 6.5 Store

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | Branch | Jump | JumpSel | PCSel |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| sb | 0 | DEST_NONE(11) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_NONE(11) | MEM_BYTE(00) | MEM_SB(000) | X | 0 | 0 | X | PC_PLUS4(00) |
| sh | 0 | DEST_NONE(11) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_NONE(11) | MEM_HALF(01) | MEM_SH(001) | X | 0 | 0 | X | PC_PLUS4(00) |
| sw | 0 | DEST_NONE(11) | A_RS(00) | B_IMM(001) | IMM_SIGN16(000) | BR_NONE(000) | ALU_ADD(0000) | WB_NONE(11) | MEM_WORD(10) | MEM_SW(010) | X | 0 | 0 | X | PC_PLUS4(00) |

##### 6.6 Branch

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | Branch | Jump | JumpSel | PCSel |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| beq | 0 | DEST_NONE(11) | A_PC4(01) | B_BR_OFFSET(010) | IMM_BRANCH16(011) | BR_EQ(001) | ALU_ADD(0000) | WB_NONE(11) | MEM_NONE(11) | MEM_IDLE(100) | X | 1 | 0 | X | BrTaken ? PC_BRANCH(01) : PC_PLUS4(00) |
| bne | 0 | DEST_NONE(11) | A_PC4(01) | B_BR_OFFSET(010) | IMM_BRANCH16(011) | BR_NE(010) | ALU_ADD(0000) | WB_NONE(11) | MEM_NONE(11) | MEM_IDLE(100) | X | 1 | 0 | X | BrTaken ? PC_BRANCH(01) : PC_PLUS4(00) |

Branch 명령어에서 ALU는 branch target만 계산합니다.

```text
ALUResult = PC+4 + (sign_ext(imm16) << 2)
```

Branch compare는 ALU result/zero flag와 분리된 별도 `BranchComp`가 수행합니다. 따라서 `beq/bne` 때문에 ALU flag output을 필수로 만들 필요가 없습니다.

##### 6.7 Jump / Link

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | Branch | Jump | JumpSel | PCSel |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| j | 0 | DEST_NONE(11) | A_ZERO(10) | B_NONE(111) | IMM_J26(100) | BR_NONE(000) | ALU_NONE(1111) | WB_NONE(11) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 1 | JUMP_IMM26(0) | PC_JUMP(10) |
| jal | 1 | DEST_RA(10) | A_ZERO(10) | B_NONE(111) | IMM_J26(100) | BR_NONE(000) | ALU_NONE(1111) | WB_PC4(10) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 1 | JUMP_IMM26(0) | PC_JUMP(10) |
| jr | 0 | DEST_NONE(11) | A_RS(00) | B_NONE(111) | IMM_NONE(111) | BR_NONE(000) | ALU_NONE(1111) | WB_NONE(11) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 1 | JUMP_REG(1) | PC_JUMP(10) |
| jalr | 1 | DEST_RD(01) | A_RS(00) | B_NONE(111) | IMM_NONE(111) | BR_NONE(000) | ALU_NONE(1111) | WB_PC4(10) | MEM_NONE(11) | MEM_IDLE(100) | X | 0 | 1 | JUMP_REG(1) | PC_JUMP(10) |

`PC_JUMP(10)`는 `JumpSelector`의 출력인 `SelectedJumpTarget`을 PC로 보냅니다. 따라서 `jr/jalr`도 `PCSel=PC_JUMP(10)`이며, 별도의 `PC_REG` 값은 필요 없습니다.

### 5.3 파이프라인 제어 정의, 인코딩, 전체 표

#### 3. 제어 신호 목록

##### WB 단계 제어

| 신호 | 폭 | 설명 |
| --- | ---: | --- |
| RegWEn | 1 | 레지스터 파일 쓰기 enable입니다. $zero write는 레지스터 파일 내부에서 무시합니다. |
| `DestSel` | 2 | 쓰기 대상 레지스터 선택입니다. MIPS에서는 R-type, I-type, 링크 명령어의 대상이 다릅니다. |
| `WBSel` | 2 | write-back 데이터 선택입니다. |

##### EX 단계 제어

| 신호 | 폭 | 설명 |
| --- | ---: | --- |
| `ASel` | 2 | ALU 입력 A 선택입니다. |
| `BSel` | 3 | ALU 입력 B 선택입니다. shift와 branch target 계산 때문에 multi-bit가 필요합니다. |
| `ImmSel` | 3 | 즉시값 생성 방식 선택입니다. |
| `BrSel` | 3 | 분기 비교 종류 선택입니다. |
| `ALUSel` | 4 | ALU operation 선택입니다. |
| `JumpSel` | 2 | 점프 대상 source 선택입니다. |
| Branch | 1 | 분기 명령어 여부입니다. BrSel != NONE에서 파생해도 됩니다. |
| Jump | 1 | 점프 명령어 여부입니다. JumpSel != NONE에서 파생해도 됩니다. |

##### MEM 단계 제어

| 신호 | 폭 | 설명 |
| --- | ---: | --- |
| `WdLen` | 2 | load/store 접근 폭입니다. |
| `MemRW` | 3 | 메모리 동작 종류입니다. idle, load, byte/half/word store를 구분합니다. |
| LoadEx | 1 | 부분 워드 load 결과 확장 방식입니다. 0은 sign-extend, 1은 zero-extend입니다. |

##### 해저드 검출 보조 제어

| 신호 | 폭 | 설명 |
| --- | ---: | --- |
| RsUsed | 1 | 현재 명령어가 rs 레지스터 값을 source로 실제 사용하는지 표시합니다. |
| RtUsed | 1 | 현재 명령어가 rt 레지스터 값을 source로 실제 사용하는지 표시합니다. |

`RsUsed`, `RtUsed`는 로드-사용 스톨과 포워딩 판단에 필요합니다. 특히 MIPS에서는 `rt`가 source일 때도 있고 대상일 때도 있으므로 반드시 구분해야 합니다.

#### 4. 인코딩 정의

##### `DestSel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | DEST_RT | rt에 write합니다. I-type ALU, load, lui에서 사용합니다. |
| 01 | DEST_RD | rd에 write합니다. R-type과 jalr에서 사용합니다. |
| 10 | DEST_RA | $31에 write합니다. jal에서 사용합니다. |
| 11 | DEST_NONE | 쓰기 대상이 없습니다. |

##### `WBSel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | WB_MEM | 데이터 메모리 load result를 쓰기 되돌림합니다. |
| 01 | WB_ALU | ALU result를 쓰기 되돌림합니다. |
| 10 | WB_PC4 | PC + 4를 쓰기 되돌림합니다. jal/jalr에서 사용합니다. |
| 11 | WB_NONE | write-back 데이터가 없습니다. |

`lui`는 `ASel=ZERO`, `BSel=IMM`, `ImmSel=LUI16`, `ALUSel=ADD`, `WBSel=WB_ALU`로 처리합니다.

##### `ASel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | A_RS | forwarded rs data를 ALU A로 사용합니다. |
| 01 | A_PC4 | PC + 4를 ALU A로 사용합니다. branch target 계산에 사용합니다. |
| 10 | A_ZERO | constant zero를 ALU A로 사용합니다. lui에 사용합니다. |
| 11 | A_RT | forwarded rt data를 ALU A로 사용합니다. shift operand에 사용합니다. |

##### `BSel[2:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 000 | B_RT | forwarded rt data를 ALU B로 사용합니다. |
| 001 | B_IMM | immediate generator 출력을 ALU B로 사용합니다. |
| 010 | B_BR_OFFSET | sign_ext(imm16) << 2를 ALU B로 사용합니다. |
| 011 | B_SHAMT | shamt를 ALU B로 사용합니다. immediate shift에 사용합니다. |
| 100 | B_RS_LOW5 | forwarded rs[4:0]을 ALU B로 사용합니다. variable shift에 사용합니다. |
| 101 | B_ZERO | constant zero입니다. |
| `110` | 예약 | 예약입니다. |
| 111 | B_NONE | 사용하지 않습니다. |

Shift ALU는 `A`를 shift 대상 value, `B[4:0]`을 shift amount로 해석합니다.

##### `ImmSel[2:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 000 | IMM_SIGN16 | sign_ext(inst[15:0]) |
| 001 | IMM_ZERO16 | zero_ext(inst[15:0]) |
| 010 | IMM_LUI16 | {inst[15:0], 16'b0} |
| 011 | IMM_BRANCH16 | sign_ext(inst[15:0]) << 2 |
| 100 | IMM_J26 | {PC+4[31:28], inst[25:0], 2'b00} |
| `101` | 예약 | 예약입니다. |
| `110` | 예약 | 예약입니다. |
| 111 | IMM_NONE | immediate를 사용하지 않습니다. |

`IMM_BRANCH16`은 `BSel=B_BR_OFFSET`과 함께 branch target 계산에 사용합니다. `IMM_J26`은 ALU 입력보다는 Next PC unit에서 사용합니다.

##### `BrSel[2:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 000 | BR_NONE | branch가 아닙니다. |
| 001 | BR_EQ | rs == rt이면 branch taken입니다. |
| 010 | BR_NE | rs != rt이면 branch taken입니다. |
| 011 | BR_LT | 예약입니다. pseudo blt 검증용으로 확장 가능합니다. |
| 100 | BR_GE | 예약입니다. pseudo bge 검증용으로 확장 가능합니다. |
| 101 | BR_LTU | 예약입니다. |
| 110 | BR_GEU | 예약입니다. |
| `111` | 예약 | 예약입니다. |

Classic MIPS instruction으로는 `beq`, `bne`만 직접 구현합니다. `blt/bge/bltu/bgeu`는 `slt/sltu + beq/bne` 의사 명령어 시퀀스로 처리합니다.

##### `ALUSel[3:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 0000 | ALU_ADD | A + B |
| 0001 | ALU_SUB | A - B |
| 0010 | ALU_AND | A & B |
| 0011 | ALU_OR | A &#124; B |
| 0100 | ALU_XOR | A ^ B |
| 0101 | ALU_SLT | signed A < B |
| 0110 | ALU_SLTU | unsigned A < B |
| 0111 | ALU_SLL | A << B[4:0] |
| 1000 | ALU_SRL | A >> B[4:0], zero-fill |
| 1001 | ALU_SRA | signed A >>> B[4:0], sign-fill |
| 1010 | ALU_NOR | ~(A &#124; B) |
| 1011 | ALU_PASS_B | B를 그대로 출력합니다. 선택 사항입니다. |
| `1100` | 예약 | 예약입니다. |
| `1101` | 예약 | 예약입니다. |
| 1110 | ALU_INVALID | invalid decode 표시용입니다. |
| 1111 | ALU_NONE | ALU result를 사용하지 않습니다. |

##### `WdLen[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | MEM_BYTE | byte access |
| 01 | MEM_HALF | halfword access |
| 10 | MEM_WORD | word access |
| 11 | MEM_NONE | memory access 없음 |

##### `MemRW[2:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 000 | MEM_SB | byte store |
| 001 | MEM_SH | halfword store |
| 010 | MEM_SW | word store |
| 011 | MEM_LOAD | load |
| 100 | MEM_IDLE | memory access 없음 |
| `101` | 예약 | 예약입니다. |
| `110` | 예약 | 예약입니다. |
| `111` | 예약 | 예약입니다. |

##### `LoadEx`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 0 | LOAD_SIGN | 부분 워드 load 결과를 sign-extend합니다. lb, lh에서 사용합니다. |
| 1 | LOAD_ZERO | 부분 워드 load 결과를 zero-extend합니다. lbu, lhu에서 사용합니다. |

`lw`에서는 32-bit 전체를 읽으므로 `LoadEx`는 don't care입니다.

##### `JumpSel[1:0]`

| 값 | 이름 | 의미 |
| --- | --- | --- |
| 00 | JUMP_NONE | jump가 아닙니다. |
| 01 | JUMP_IMM26 | {PC+4[31:28], inst[25:0], 2'b00}로 jump합니다. j, jal에서 사용합니다. |
| 10 | JUMP_REG | forwarded rs 값을 다음 PC로 사용합니다. jr, jalr에서 사용합니다. |
| `11` | 예약 | 예약입니다. |

#### 5. 파이프라인 전달 기준

ID 단계에서 생성한 control은 단계별로 나누어 파이프라인 레지스터에 저장합니다.

| Pipeline register | 전달할 control |
| --- | --- |
| ID/EX | RegWEn, DestSel, WBSel, ASel, BSel, ImmSel, BrSel, ALUSel, JumpSel, Branch, Jump, WdLen, MemRW, LoadEx |
| EX/MEM | RegWEn, WBSel, WdLen, MemRW, LoadEx, 확정된 WriteReg |
| MEM/WB | RegWEn, WBSel, 확정된 WriteReg |

`RsUsed`, `RtUsed`는 ID 단계 해저드 검출에 사용하고, 필요하면 포워딩 debug를 위해 `ID/EX`에도 저장합니다.

#### 6. Forwarding 관련 주의점

Shift instruction 때문에 ALU 입력 A가 항상 `rs`라는 가정은 깨집니다.

권장 구조는 다음입니다.

```text
RegisterFile read data
    -> ForwardRs mux -> FwdRsData
    -> ForwardRt mux -> FwdRtData
    -> ASel/BSel mux
    -> ALU 입력 A/B
```

이렇게 하면 `sll`처럼 `rt`를 ALU A로 쓰는 instruction도 포워딩 처리가 단순해집니다.

- `ForwardRs`는 `ID/EX.rs` 기준으로 EX/MEM, MEM/WB destination과 비교합니다.
- `ForwardRt`는 `ID/EX.rt` 기준으로 EX/MEM, MEM/WB destination과 비교합니다.
- `ASel=A_RT`이면 ALU A에는 `FwdRtData`가 들어갑니다.
- `BSel=B_RS_LOW5`이면 ALU B에는 `FwdRsData[4:0]`가 들어갑니다.
- `sw/sb/sh` store data도 `FwdRtData`를 사용하면 store data 포워딩을 자연스럽게 처리할 수 있습니다.

#### 7. 명령어별 제어 신호

표에서 `X`는 don't care입니다. 실제 Logisim 구현에서는 버블 또는 invalid instruction 처리를 쉽게 하기 위해 don't care도 안전한 기본값으로 묶는 것이 좋습니다.

안전한 NOP control은 다음입니다.

```text
RegWEn=0, DestSel=DEST_NONE, WBSel=WB_NONE,
ASel=A_ZERO, BSel=B_ZERO, ImmSel=IMM_NONE,
BrSel=BR_NONE, ALUSel=ALU_NONE,
WdLen=MEM_NONE, MemRW=MEM_IDLE, LoadEx=0,
JumpSel=JUMP_NONE, Branch=0, Jump=0,
RsUsed=0, RtUsed=0
```

##### 7.1 R-type ALU

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | JumpSel | Branch | Jump | RsUsed | RtUsed |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| add | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_ADD | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| addu | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_ADD | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| sub | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_SUB | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| subu | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_SUB | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| and | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_AND | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| or | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_OR | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| xor | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_XOR | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| nor | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_NOR | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| slt | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_SLT | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| sltu | 1 | DEST_RD | A_RS | B_RT | IMM_NONE | BR_NONE | ALU_SLTU | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |

##### 7.2 Shift

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | JumpSel | Branch | Jump | RsUsed | RtUsed |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| sll | 1 | DEST_RD | A_RT | B_SHAMT | IMM_NONE | BR_NONE | ALU_SLL | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 0 | 1 |
| srl | 1 | DEST_RD | A_RT | B_SHAMT | IMM_NONE | BR_NONE | ALU_SRL | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 0 | 1 |
| sra | 1 | DEST_RD | A_RT | B_SHAMT | IMM_NONE | BR_NONE | ALU_SRA | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 0 | 1 |
| sllv | 1 | DEST_RD | A_RT | B_RS_LOW5 | IMM_NONE | BR_NONE | ALU_SLL | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| srlv | 1 | DEST_RD | A_RT | B_RS_LOW5 | IMM_NONE | BR_NONE | ALU_SRL | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| srav | 1 | DEST_RD | A_RT | B_RS_LOW5 | IMM_NONE | BR_NONE | ALU_SRA | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 1 |

##### 7.3 I-type ALU / Immediate

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | JumpSel | Branch | Jump | RsUsed | RtUsed |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| addi | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 0 |
| addiu | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 0 |
| andi | 1 | DEST_RT | A_RS | B_IMM | IMM_ZERO16 | BR_NONE | ALU_AND | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 0 |
| ori | 1 | DEST_RT | A_RS | B_IMM | IMM_ZERO16 | BR_NONE | ALU_OR | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 0 |
| xori | 1 | DEST_RT | A_RS | B_IMM | IMM_ZERO16 | BR_NONE | ALU_XOR | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 0 |
| slti | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_SLT | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 0 |
| sltiu | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_SLTU | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 1 | 0 |
| lui | 1 | DEST_RT | A_ZERO | B_IMM | IMM_LUI16 | BR_NONE | ALU_ADD | WB_ALU | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 0 | 0 | 0 | 0 |

##### 7.4 Load

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | JumpSel | Branch | Jump | RsUsed | RtUsed |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| lb | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_MEM | MEM_BYTE | MEM_LOAD | 0 | JUMP_NONE | 0 | 0 | 1 | 0 |
| lbu | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_MEM | MEM_BYTE | MEM_LOAD | 1 | JUMP_NONE | 0 | 0 | 1 | 0 |
| lh | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_MEM | MEM_HALF | MEM_LOAD | 0 | JUMP_NONE | 0 | 0 | 1 | 0 |
| lhu | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_MEM | MEM_HALF | MEM_LOAD | 1 | JUMP_NONE | 0 | 0 | 1 | 0 |
| lw | 1 | DEST_RT | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_MEM | MEM_WORD | MEM_LOAD | X | JUMP_NONE | 0 | 0 | 1 | 0 |

##### 7.5 Store

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | JumpSel | Branch | Jump | RsUsed | RtUsed |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| sb | 0 | DEST_NONE | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_NONE | MEM_BYTE | MEM_SB | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| sh | 0 | DEST_NONE | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_NONE | MEM_HALF | MEM_SH | X | JUMP_NONE | 0 | 0 | 1 | 1 |
| sw | 0 | DEST_NONE | A_RS | B_IMM | IMM_SIGN16 | BR_NONE | ALU_ADD | WB_NONE | MEM_WORD | MEM_SW | X | JUMP_NONE | 0 | 0 | 1 | 1 |

`rt`는 store data source이므로 `RtUsed=1`입니다. store data는 `FwdRtData`를 MEM 단계까지 전달하는 구조가 좋습니다.

##### 7.6 Branch

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | JumpSel | Branch | Jump | RsUsed | RtUsed |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| beq | 0 | DEST_NONE | A_PC4 | B_BR_OFFSET | IMM_BRANCH16 | BR_EQ | ALU_ADD | WB_NONE | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 1 | 0 | 1 | 1 |
| bne | 0 | DEST_NONE | A_PC4 | B_BR_OFFSET | IMM_BRANCH16 | BR_NE | ALU_ADD | WB_NONE | MEM_NONE | MEM_IDLE | X | JUMP_NONE | 1 | 0 | 1 | 1 |

Branch target은 EX 단계에서 `PC+4 + (sign_ext(imm16) << 2)`로 계산합니다. Branch compare는 ALU result/zero flag 대신 별도 `BranchComp`가 `FwdRsData`, `FwdRtData`, `BrSel`을 보고 판단합니다. 이 분리 때문에 branch용 ALU flag forwarding을 추가하지 않아도 되고, branch operand forwarding은 `BranchComp` 입력으로 직접 들어갑니다.

##### 7.7 Jump / Link

| 명령어 | RegWEn | DestSel | ASel | BSel | ImmSel | BrSel | ALUSel | WBSel | WdLen | MemRW | LoadEx | JumpSel | Branch | Jump | RsUsed | RtUsed |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| j | 0 | DEST_NONE | A_ZERO | B_NONE | IMM_J26 | BR_NONE | ALU_NONE | WB_NONE | MEM_NONE | MEM_IDLE | X | JUMP_IMM26 | 0 | 1 | 0 | 0 |
| jal | 1 | DEST_RA | A_ZERO | B_NONE | IMM_J26 | BR_NONE | ALU_NONE | WB_PC4 | MEM_NONE | MEM_IDLE | X | JUMP_IMM26 | 0 | 1 | 0 | 0 |
| jr | 0 | DEST_NONE | A_RS | B_NONE | IMM_NONE | BR_NONE | ALU_NONE | WB_NONE | MEM_NONE | MEM_IDLE | X | JUMP_REG | 0 | 1 | 1 | 0 |
| jalr | 1 | DEST_RD | A_RS | B_NONE | IMM_NONE | BR_NONE | ALU_NONE | WB_PC4 | MEM_NONE | MEM_IDLE | X | JUMP_REG | 0 | 1 | 1 | 0 |

`jr/jalr` target register는 `rs`입니다. 직전 instruction이 `rs`를 write하는 경우 jump target에도 포워딩 또는 스톨 처리가 필요합니다.

#### 8. EX 단계 PCSel 생성 예시

ID 단계 제어 유닛은 `PCSel`을 직접 만들지 않습니다. EX 단계에서 다음처럼 결정합니다.

```text
BranchTaken = Branch && BranchComp(FwdRsData, FwdRtData, BrSel)  // ALU flag가 아니라 별도 comparator 결과

if JumpSel == JUMP_REG:
    PCSel = PC_REG_TARGET
else if JumpSel == JUMP_IMM26:
    PCSel = PC_JUMP_TARGET
else if BranchTaken:
    PCSel = PC_BRANCH_TARGET
else:
    PCSel = PC_PLUS4
```

우선순위는 구현 선택에 따라 조정할 수 있지만, 정상 instruction stream에서는 branch와 jump가 동시에 참이 되지 않아야 합니다.

#### 9. Decode 기본값

control unit의 기본값은 NOP로 두는 것이 좋습니다. invalid instruction이나 플러시 버블이 들어왔을 때 side effect가 없어야 합니다.

```verilog
RegWEn  = 1'b0;
DestSel = DEST_NONE;
WBSel   = WB_NONE;
ASel    = A_ZERO;
BSel    = B_ZERO;
ImmSel  = IMM_NONE;
BrSel   = BR_NONE;
ALUSel  = ALU_NONE;
WdLen   = MEM_NONE;
MemRW   = MEM_IDLE;
LoadEx  = 1'b0;
JumpSel = JUMP_NONE;
RsUsed  = 1'b0;
RtUsed  = 1'b0;
```

`Branch`와 `Jump`는 각각 `BrSel != BR_NONE`, `JumpSel != JUMP_NONE`으로 assign해도 됩니다.

## 6. 추적성, 주의사항, 충돌 기록

| 주제 | 정리 |
|---|---|
| 출처 우선순위 | 요구사항과 승인된 계획이 원천 문서보다 우선합니다. 원천 문서는 상세 인코딩/제어 표 근거입니다. |
| 원격 문서 차이 확인 | 이 문서를 작성하기 전 원격 원천 문서 해시가 로컬 스냅샷과 일치함을 확인했습니다. |
| 기존 정본 명세 | 원격 대상 경로에는 첫 작성 전 `doc/mips_functional_spec.md`가 없었습니다. |
| `JumpSel` 폭 충돌 위험 | 단일 사이클 1-bit와 파이프라인 2-bit를 각각 유지합니다. |
| PCSel 단계 충돌 위험 | 단일 사이클 PCControl 출력과 파이프라인 EX 재지정을 구분합니다. |
| `RsUsed`/`RtUsed` | 파이프라인 해저드 보조 제어로만 정의합니다. |
| 의사 분기 | `blt/bge/bltu/bgeu`는 의사 명령어 전용이며 실제 하드웨어 제어 행에서 제외합니다. |
| 중복 문서 | 기존 문서는 원천 입력으로 보존합니다. 보관 후보 목록 문서가 있더라도 비권위적 목록일 뿐입니다. |

## 7. 관리자 / 후속 에이전트 검증 체크리스트

- [ ] 원격 필수 원천 문서가 존재합니다.
- [ ] 변경 파일이 `doc/mips_functional_spec.md`와 선택 경로 `doc/archive_candidates/MANIFEST.md`로 제한됩니다.
- [ ] 보호 경로가 변경되지 않았습니다: `Project/Subcircuit/*.circ`, `Project/Subcircuit/ALU_testvector/*`, `test_vectors/**`.
- [ ] 섹션 2의 모든 구현 대상 명령어가 커버리지 매트릭스에 있습니다.
- [ ] 섹션 2의 모든 제외/의사 명령어 전용 명령어가 커버리지 매트릭스에 있습니다.
- [ ] 명령어 인코딩에는 opcode/funct, 필드 위치, 즉시값 의미, 대상 의미가 포함됩니다.
- [ ] 단일 사이클과 파이프라인 제어 표가 모두 존재하고 서로 분리되어 있습니다.
- [ ] `blt`, `bge`, `bltu`, `bgeu`는 실제 하드웨어 decode/제어 행으로 존재하지 않습니다.
