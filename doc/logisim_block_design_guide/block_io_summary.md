# Block I/O 요약표

| Block | 주요 입력 | 주요 출력 | 연결 control | 설계 메모 |
|---|---|---|---|---|
| PC Selector / PC / PC+4 | `PCSel`, `PC+4`, `BranchTarget`, `SelectedJumpTarget`, clock/reset | `PC`, `PC+4`, `NextPC` | `PCSel` | `PC+4`, branch, `SelectedJumpTarget`의 3-way mux를 PC 앞에 둡니다. |
| Instruction Memory / Inst Split | `PC` | `Inst`, `opcode`, `rs`, `rt`, `rd`, `shamt`, `funct`, `imm16`, `target26` | 없음 | MIPS field split은 명세서 bit range를 따릅니다. |
| Register / Dest Sel | `Addr_rs`, `Addr_rt`, `Addr_WR`, `Data_WR`, `RegWEn` | `Data_rs`, `Data_rt`, `WriteReg` | `RegWEn`, `DestSel` | `$zero` write 무시는 register file 내부 책임입니다. |
| Imm Generator | `Inst[25:0]`, `ImmSel` | `ImmVal`, `BranchOff`, raw `target26` | `ImmSel` | sign/zero/lui/branch 즉시값을 만들고, 32-bit jump target 생성은 Jump Target Gen에 위임합니다. |
| Jump Target Gen / Jump Sel | `PC+4`, raw `target26`, `Data_rs`, `JumpSel` | `JumpImmTarget`, `SelectedJumpTarget` | `JumpSel`, `Jump` | Jump Target Gen이 `{PC+4[31:28], target26, 2'b00}` 생성의 단일 owner입니다. |
| Control Unit | `opcode[5:0]`, `funct[5:0]` | 모든 datapath control | 전체 control | 기본값을 안전한 NOP로 두고 opcode/funct별 override합니다. |
| A Selector / B Selector | `Data_rs`, `Data_rt`, `PC+4`, `ImmVal`, `BranchOff`, `shamt`, constants | `ALU_A`, `ALU_B` | `ASel`, `BSel` | selector input order는 명세서 encoding과 1:1로 맞춥니다. |
| ALU | `ALU_A`, `ALU_B`, `ALUSel` | `ALUResult` | `ALUSel` | add/sub/logic/slt/sltu/shift/nor를 구현합니다. |
| Branch Comp | `Data_rs`, `Data_rt`, `BrSel` | `BranchTakenRaw` | `BrSel`, `Branch` | 실제 구현 branch는 `beq`, `bne`입니다. |
| Data Memory | `ALUResult`, `Data_rt`, `WdLen`, `MemRW`, `LoadEx` | `Data_RD` | `WdLen`, `MemRW`, `LoadEx` | diagram label은 `Byte Sel=WdLen`, `WE=store(MemRW)`, `Extension=LoadEx` adapter로 해석합니다. |
| WB selector | `Data_RD`, `ALUResult`, `PC+4`, `WBSel` | `Data_WR` | `WBSel` | register write-back source를 선택합니다. |
| Jump Branch / PCControl | `Branch`, `Jump`, `BranchTakenRaw`, `SelectedJumpTarget`, `BranchTarget` | `PCSel` | `Branch`, `Jump`, `PCSel` | 우선순위는 `Jump` > taken branch > `PC+4`입니다. |
