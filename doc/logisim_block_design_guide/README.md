# Logisim Block별 설계 가이드

> 기준 자료: `../../Single_Cycle_block_diagram.png` + `../mips_functional_spec.md`
> 목적: 팀원이 block diagram을 보며 Logisim에서 각 block을 하나씩 만들 수 있도록, 블록 설명·입력·출력·설계 절차·검증 포인트를 한국어로 정리합니다.

## 1. 읽는 순서

1. 이 `README.md`에서 전체 데이터 흐름과 제어 흐름을 확인합니다.
2. `block_io_summary.md`에서 block별 input/output/control 요약을 확인합니다.
3. `blocks/*.md` 문서를 왼쪽 fetch 경로부터 오른쪽 write-back 경로 순서로 구현합니다.
4. block별 검증은 [`testvector_guide.md`](testvector_guide.md)의 ROM/counter/comparator 패턴과 Python golden generator를 함께 사용합니다.
5. 각 block 구현 후 해당 문서의 `검증 포인트`를 통과한 뒤 다음 block으로 넘어갑니다.

## 2. 정본 기준

- 기능/명령어/control의 정본은 `doc/mips_functional_spec.md`입니다.
- block diagram은 배치와 배선 흐름의 기준입니다.
- 둘이 충돌할 경우 명세서를 우선하며, 이미지와 다른 점은 각 block의 `Caveat / 주의사항`에 기록했습니다.
- 회로 파일, 테스트 벡터, raw asset은 이 문서 작업에서 수정하지 않습니다.

## 3. 구현 대상 instruction coverage

구현 대상 38개 명령어:

```text
add, addu, sub, subu, and, or, xor, nor, slt, sltu, sll, srl, sra, sllv, srlv, srav, addi, addiu, andi, ori, xori, slti, sltiu, lui, lw, lh, lhu, lb, lbu, sw, sh, sb, beq, bne, j, jal, jr, jalr
```

제외/의사 명령어 전용 14개:

```text
mult, multu, div, divu, mfhi, mflo, ecall, ebreak, fence, auipc, blt, bge, bltu, bgeu
```

`blt`, `bge`, `bltu`, `bgeu`는 `slt/sltu + beq/bne` 의사 명령어 시퀀스로만 다루며, 실제 하드웨어 decode/control row나 별도 branch comparator 동작으로 추가하지 않습니다.

## 4. 전체 데이터 흐름

```text
PC -> Instruction Memory -> Inst Split -> Register / Imm Generator / Control Unit
   -> A/B Selector -> ALU -> Data Memory -> WB selector -> Register write-back
   -> Branch Comp + Jump Branch/PCControl -> PC Selector -> PC
```

단일 사이클에서는 한 클럭 안에서 instruction fetch, decode, execute, memory, write-back, next-PC 결정이 모두 조합 경로로 연결되고, 클럭 edge에서 `PC`와 register write가 확정됩니다.

## 5. 주요 control signal 위치

| Control | 주 사용 block | 핵심 역할 |
|---|---|---|
| `RegWEn` | Register | write-back enable |
| `DestSel` | Dest Sel | `rt/rd/$31/none` 중 write register 선택 |
| `ASel` | A Selector | ALU A 입력 선택 |
| `BSel` | B Selector | ALU B 입력 선택 |
| `ImmSel` | Imm Generator | 즉시값/branch offset/lui 생성 선택; J-type raw `target26`은 Jump Target Gen으로 전달 |
| `BrSel` | Branch Comp | `beq/bne` 비교 방식 선택 |
| `ALUSel` | ALU | 산술/논리/shift/slt 연산 선택 |
| `WBSel` | WB selector | register write-back data 선택 |
| `WdLen` | Data Memory | byte/half/word 접근 폭 |
| `MemRW` | Data Memory | load/store/idle 동작 선택 |
| `LoadEx` | Data Memory | 부분 word load sign/zero extension |
| `JumpSel` | Jump Sel | immediate jump vs register jump target 선택 |
| `Branch`, `Jump` | Jump Branch / PCControl | next PC 우선순위 결정 |
| `PCSel` | PC Selector | `PC+4/branch/jump` 중 next PC 선택 |

## 6. Block 문서 목록

- [PC Selector / PC / PC+4](blocks/01_pc_selector_pc_pc4.md)
- [Instruction Memory / Inst Split](blocks/02_instruction_memory_inst_split.md)
- [Register / Dest Sel](blocks/03_register_dest_sel.md)
- [Imm Generator](blocks/04_imm_generator.md)
- [Jump Target Gen / Jump Sel](blocks/05_jump_target_gen_jump_sel.md)
- [Control Unit](blocks/06_control_unit.md)
- [A Selector / B Selector](blocks/07_a_b_selectors.md)
- [ALU](blocks/08_alu.md)
- [Branch Comp](blocks/09_branch_comp.md)
- [Data Memory](blocks/10_data_memory.md)
- [WB selector](blocks/11_wb_selector.md)
- [Jump Branch / PCControl](blocks/12_jump_branch_pc_control.md)
- [Block testvector 검증 가이드](testvector_guide.md)

## 7. 구현 권장 순서

1. `PC`, `PC + 4`, `Instruction Memory`, `Inst Split`을 먼저 만들어 instruction field가 안정적으로 나오는지 확인합니다.
2. `Register`, `Dest Sel`, `WB selector`를 붙여 R-type write-back 경로를 검증합니다.
3. `Imm Generator`, `A/B Selector`, `ALU`를 붙여 immediate/shift/load-store 주소 계산을 검증합니다.
4. `Data Memory`를 붙여 `lw/lh/lhu/lb/lbu/sw/sh/sb`를 검증합니다.
5. `Branch Comp`, `Jump Target Gen`, `Jump Sel`, `Jump Branch/PCControl`, `PC Selector`를 붙여 control-flow 명령어를 검증합니다.
6. 마지막으로 control table 기준으로 38개 구현 명령어 smoke test를 수행합니다.

## 8. 공통 Logisim 규칙

- 모든 datapath는 32-bit를 기본으로 합니다. register 번호와 shamt는 5-bit, opcode/funct는 각각 6-bit입니다.
- selector 입력 순서는 명세서 encoding과 동일하게 유지합니다. 입력 순서가 바뀌면 control table 전체가 틀어집니다.
- unused input은 floating으로 두지 말고 `0` 또는 명세서의 `NONE/IDLE` 값에 맞춰 고정합니다.
- `$zero` register write는 register file 내부에서 무시합니다.
- memory 주소는 byte address 기준으로 설명하되, Logisim memory component가 word index를 요구하면 하위 2-bit 처리 방식을 명확히 분리합니다.

## 9. Diagram anomalies / 명세 우선 해석

block diagram은 배선 흐름을 보여 주는 그림이고, 최종 의미는 `doc/mips_functional_spec.md`를 우선합니다. 구현자는 아래 차이를 먼저 확인해야 합니다.

| 그림에서 보이는 항목 | 명세 기준 해석 | 구현 가이드 결정 |
|---|---|---|
| Control Unit 근처 `Inst[10:6] funct`처럼 보이는 라벨 | MIPS `funct`는 `Inst[5:0]`, `Inst[10:6]`은 `shamt` | Inst Split은 반드시 `funct[5:0]`과 `shamt[10:6]`을 분리합니다. |
| Imm Generator의 `target26` 출력과 Jump Target Gen | jump target 공식은 `{PC+4[31:28], target26, 2'b00}` | **Jump Target Gen이 32-bit jump target 생성의 단일 owner**입니다. Imm Generator는 raw `target26`을 전달하거나 sign/zero/branch/lui immediate만 생성합니다. |
| Data Memory 하단 `Byte Sel`, `WE`, `Extension` | 명세 control은 `WdLen[1:0]`, `MemRW[2:0]`, `LoadEx` | Data Memory 내부에서 `Byte Sel=WdLen`, `WE=(MemRW in store ops)`, `Extension=LoadEx`로 adapter를 둡니다. |
| B Selector의 일부 입력만 그림에 표시 | 명세는 `BSel[2:0]` 전체 encoding을 정의 | 예약/NONE 입력은 0에 묶고 control이 선택하지 않게 검증합니다. |

## 10. Block testvector 검증 가이드

각 block은 손계산한 golden 값 대신 `tools/testvector_generators/`의 Python reference/generator가 산출한 값을 기준으로 검증합니다. 기본 흐름은 입력 vector를 ROM에 저장하고 counter로 주소를 증가시키며 모든 vector를 투입한 뒤, HEX decoder와 comparator/error counter로 결과를 확인하는 방식입니다. 자세한 절차와 block별 산출물 위치는 [`testvector_guide.md`](testvector_guide.md)를 따릅니다.

## 11. 파이프라인 확장 메모

이 guide는 단일 사이클 block diagram을 기준으로 합니다. 파이프라인 구현으로 확장할 때는 `ID/EX`, `EX/MEM`, `MEM/WB` register를 추가하고, `RsUsed/RtUsed`, forwarding, stall, flush를 별도 hazard block으로 분리합니다. 단일 사이클의 `PCSel`과 파이프라인 EX-stage redirect는 같은 산출물로 취급하지 않습니다.
