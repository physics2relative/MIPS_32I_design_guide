`timescale 1ns/1ps

// =============================================================
// MIPS 5-stage pipeline top
// -------------------------------------------------------------
// Code is intentionally ordered like the block diagram:
//   PC register -> IF stage blocks -> IF/ID register -> ID blocks
//   -> ID/EX register -> EX blocks -> EX/MEM register -> MEM blocks
//   -> MEM/WB register -> WB blocks -> hazard/forwarding controls
//
// Instruction memory and data memory use synchronous BRAM read/write for
// FPGA-oriented implementation.  Their wrappers absorb the BRAM read latency
// where noted, matching the Logisim pipeline block diagram intent.
// =============================================================

module mips_pipeline_top #(
    parameter IMEM_AW = 9,
    parameter DMEM_AW = 10,
    parameter IMEM_INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rst,

    output wire        dbg_wb_valid,
    output wire [31:0] dbg_wb_pc,
    output wire [31:0] dbg_wb_inst,
    output wire        dbg_wb_reg_wen,
    output wire [4:0]  dbg_wb_write_reg,
    output wire [31:0] dbg_wb_wdata,

    output wire [31:0] dbg_if_pc,
    output wire [31:0] dbg_id_inst,
    output wire [31:0] dbg_ex_alu_result,
    output wire [31:0] dbg_next_pc
);
    localparam [1:0] DEST_RT   = 2'b00;
    localparam [1:0] DEST_RD   = 2'b01;
    localparam [1:0] DEST_RA   = 2'b10;
    localparam [1:0] DEST_NONE = 2'b11;

    localparam [1:0] WB_MEM  = 2'b00;
    localparam [1:0] WB_ALU  = 2'b01;
    localparam [1:0] WB_PC4  = 2'b10;
    localparam [1:0] WB_NONE = 2'b11;

    localparam [1:0] A_RS   = 2'b00;
    localparam [1:0] A_PC4  = 2'b01;
    localparam [1:0] A_ZERO = 2'b10;
    localparam [1:0] A_RT   = 2'b11;

    localparam [2:0] B_RT      = 3'b000;
    localparam [2:0] B_IMM     = 3'b001;
    localparam [2:0] B_SHAMT   = 3'b010;
    localparam [2:0] B_RS_LOW5 = 3'b011;
    localparam [2:0] B_ZERO    = 3'b100;

    localparam [1:0] PC_PLUS4  = 2'b00;
    localparam [1:0] PC_BRANCH = 2'b01;
    localparam [1:0] PC_JUMP   = 2'b10;

    localparam [1:0] MEM_IDLE = 2'b00;
    localparam [1:0] MEM_LOAD = 2'b01;

    localparam [1:0] FWD_REG = 2'b00;
    localparam [1:0] FWD_WB  = 2'b01;
    localparam [1:0] FWD_MEM = 2'b10;
    localparam [1:0] FWD_EX  = 2'b11;

    // =========================================================
    // PC register
    // =========================================================
    reg  [31:0] PC_IF;
    wire [31:0] PCPlus4_IF;
    wire [31:0] NextPC;
    wire        Stall_PC;

    assign PCPlus4_IF = PC_IF + 32'd4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC_IF <= 32'h0000_0000;
        end else if (!Stall_PC) begin
            PC_IF <= NextPC;
        end
    end

    // =========================================================
    // IF stage blocks
    // =========================================================
    wire        Stall_IF_ID;
    wire        Flush_IF_ID;
    wire [31:0] Inst_ID;

    instruction_memory #(
        .INIT_FILE(IMEM_INIT_FILE),
        .MEM_AW(IMEM_AW)
    ) u_imem (
        .clk(clk),
        .rst(rst),
        .Addr(PC_IF),
        .Stall_IF_ID(Stall_IF_ID),
        .Flush_IF_ID(Flush_IF_ID),
        .Inst(Inst_ID)
    );

    // =========================================================
    // IF / ID register
    // Instruction bits are registered inside instruction_memory because
    // synchronous BRAM read already creates the instruction pipeline stage.
    // =========================================================
    reg [31:0] PC_ID;
    reg [31:0] PCPlus4_ID;
    reg        valid_ID;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC_ID      <= 32'h0000_0000;
            PCPlus4_ID <= 32'h0000_0000;
            valid_ID   <= 1'b0;
        end else if (!Stall_IF_ID) begin
            if (Flush_IF_ID) begin
                PC_ID      <= 32'h0000_0000;
                PCPlus4_ID <= 32'h0000_0000;
                valid_ID   <= 1'b0;
            end else begin
                PC_ID      <= PC_IF;
                PCPlus4_ID <= PCPlus4_IF;
                valid_ID   <= 1'b1;
            end
        end
    end

    // =========================================================
    // ID stage blocks
    // =========================================================
    wire [5:0]  opcode_ID;
    wire [4:0]  rs_ID;
    wire [4:0]  rt_ID;
    wire [4:0]  rd_ID;
    wire [4:0]  shamt_ID;
    wire [5:0]  funct_ID;
    wire [15:0] imm16_ID;
    wire [25:0] target26_ID;

    instruction_splitter u_inst_splitter (
        .Inst(Inst_ID),
        .opcode(opcode_ID),
        .rs(rs_ID),
        .rt(rt_ID),
        .rd(rd_ID),
        .shamt(shamt_ID),
        .funct(funct_ID),
        .imm16(imm16_ID),
        .target26(target26_ID)
    );

    wire       RegWEn_ID;
    wire [1:0] DestSel_ID;
    wire [1:0] ASel_ID;
    wire [2:0] BSel_ID;
    wire [1:0] ImmSel_ID;
    wire       BrSel_ID;
    wire [3:0] ALUSel_ID;
    wire [1:0] WBSel_ID;
    wire [1:0] WdLen_ID;
    wire [1:0] MemRW_ID;
    wire       LoadEx_ID;
    wire       Branch_ID;
    wire       Jump_ID;
    wire       JumpSel_ID;
    wire       RsUsed_ID;
    wire       RtUsed_ID;

    control_unit u_control (
        .opcode(opcode_ID),
        .funct(funct_ID),
        .RegWEn(RegWEn_ID),
        .DestSel(DestSel_ID),
        .ASel(ASel_ID),
        .BSel(BSel_ID),
        .ImmSel(ImmSel_ID),
        .BrSel(BrSel_ID),
        .ALUSel(ALUSel_ID),
        .WBSel(WBSel_ID),
        .WdLen(WdLen_ID),
        .MemRW(MemRW_ID),
        .LoadEx(LoadEx_ID),
        .Branch(Branch_ID),
        .Jump(Jump_ID),
        .JumpSel(JumpSel_ID),
        .RsUsed(RsUsed_ID),
        .RtUsed(RtUsed_ID)
    );

    reg [4:0] DestReg_ID;
    always @(*) begin
        case (DestSel_ID)
            DEST_RT:   DestReg_ID = rt_ID;
            DEST_RD:   DestReg_ID = rd_ID;
            DEST_RA:   DestReg_ID = 5'd31;
            DEST_NONE: DestReg_ID = 5'd0;
            default:   DestReg_ID = 5'd0;
        endcase
    end

    wire [31:0] Data_rs_ID_raw;
    wire [31:0] Data_rt_ID_raw;
    wire [31:0] WData_WB;
    wire [4:0]  DestReg_WB;
    wire        RegWEn_WB;

    register_file u_regfile (
        .clk(clk),
        .rst(rst),
        .RegWEn(RegWEn_WB),
        .Addr_Rs(rs_ID),
        .Addr_Rt(rt_ID),
        .Addr_WR(DestReg_WB),
        .WData(WData_WB),
        .Data_Rs(Data_rs_ID_raw),
        .Data_Rt(Data_rt_ID_raw)
    );

    wire [31:0] ImmVal_ID;
    immediate_generator u_immgen (
        .ImmSel(ImmSel_ID),
        .imm16(imm16_ID),
        .ImmVal(ImmVal_ID)
    );

    wire [31:0] ForwardData_MEM_to_ID;
    wire [31:0] Data_rs_ID;
    wire [31:0] Data_rt_ID;

    // Branch/jump operands are resolved in EX, so ID keeps raw register-file
    // read values and relies on normal EX-stage forwarding after ID/EX.
    assign Data_rs_ID = Data_rs_ID_raw;
    assign Data_rt_ID = Data_rt_ID_raw;

    // Jump immediate target generation stays in ID because it only needs
    // target26 and PC+4.  JumpSel/register target selection is performed in EX
    // after normal forwarding can supply the latest rs value.
    wire [31:0] JumpImmTarget_ID;
    jump_target_generator u_jump_target (
        .PCPlus4(PCPlus4_ID),
        .target26(target26_ID),
        .JumpImmTarget(JumpImmTarget_ID)
    );

    // =========================================================
    // ID / EX register
    // =========================================================
    wire Flush_ID_EX;

    reg        valid_EX;
    reg [31:0] Inst_EX;
    reg [31:0] PC_EX;
    reg [31:0] PCPlus4_EX;
    reg [31:0] Data_rs_EX;
    reg [31:0] Data_rt_EX;
    reg [31:0] ImmVal_EX;
    reg [31:0] JumpImmTarget_EX;
    reg [4:0]  rs_EX;
    reg [4:0]  rt_EX;
    reg [4:0]  shamt_EX;
    reg [4:0]  DestReg_EX;
    reg [1:0]  ASel_EX;
    reg [2:0]  BSel_EX;
    reg [3:0]  ALUSel_EX;
    reg [1:0]  WBSel_EX;
    reg [1:0]  WdLen_EX;
    reg [1:0]  MemRW_EX;
    reg        LoadEx_EX;
    reg        Branch_EX;
    reg        Jump_EX;
    reg        JumpSel_EX;
    reg        BrSel_EX;
    reg        RegWEn_EX;

    always @(posedge clk or posedge rst) begin
        if (rst || Flush_ID_EX) begin
            valid_EX     <= 1'b0;
            Inst_EX      <= 32'h0000_0000;
            PC_EX        <= 32'h0000_0000;
            PCPlus4_EX   <= 32'h0000_0000;
            Data_rs_EX   <= 32'h0000_0000;
            Data_rt_EX   <= 32'h0000_0000;
            ImmVal_EX        <= 32'h0000_0000;
            JumpImmTarget_EX <= 32'h0000_0000;
            rs_EX        <= 5'd0;
            rt_EX        <= 5'd0;
            shamt_EX     <= 5'd0;
            DestReg_EX   <= 5'd0;
            ASel_EX      <= A_ZERO;
            BSel_EX      <= B_ZERO;
            ALUSel_EX    <= 4'hF;
            WBSel_EX     <= WB_NONE;
            WdLen_EX     <= 2'b11;
            MemRW_EX     <= MEM_IDLE;
            LoadEx_EX    <= 1'b0;
            Branch_EX    <= 1'b0;
            Jump_EX      <= 1'b0;
            JumpSel_EX   <= 1'b0;
            BrSel_EX     <= 1'b0;
            RegWEn_EX    <= 1'b0;
        end else begin
            valid_EX     <= valid_ID;
            Inst_EX      <= Inst_ID;
            PC_EX        <= PC_ID;
            PCPlus4_EX   <= PCPlus4_ID;
            Data_rs_EX   <= Data_rs_ID;
            Data_rt_EX   <= Data_rt_ID;
            ImmVal_EX        <= ImmVal_ID;
            JumpImmTarget_EX <= JumpImmTarget_ID;
            rs_EX        <= rs_ID;
            rt_EX        <= rt_ID;
            shamt_EX     <= shamt_ID;
            DestReg_EX   <= DestReg_ID;
            ASel_EX      <= ASel_ID;
            BSel_EX      <= BSel_ID;
            ALUSel_EX    <= ALUSel_ID;
            WBSel_EX     <= WBSel_ID;
            WdLen_EX     <= WdLen_ID;
            MemRW_EX     <= MemRW_ID;
            LoadEx_EX    <= LoadEx_ID;
            Branch_EX    <= valid_ID ? Branch_ID : 1'b0;
            Jump_EX      <= valid_ID ? Jump_ID : 1'b0;
            JumpSel_EX   <= JumpSel_ID;
            BrSel_EX     <= BrSel_ID;
            RegWEn_EX    <= valid_ID ? RegWEn_ID : 1'b0;
        end
    end

    // =========================================================
    // EX stage blocks
    // =========================================================
    wire [1:0] ForwardA_EX;
    wire [1:0] ForwardB_EX;
    wire [31:0] Data_rs_EX_fwd;
    wire [31:0] Data_rt_EX_fwd;
    wire [31:0] ALU_a_EX;
    wire [31:0] ALU_b_EX;
    wire [31:0] ALU_Result_EX;

    assign Data_rs_EX_fwd = (ForwardA_EX == FWD_MEM) ? ForwardData_MEM_to_ID :
                            (ForwardA_EX == FWD_WB)  ? WData_WB              :
                                                        Data_rs_EX;

    assign Data_rt_EX_fwd = (ForwardB_EX == FWD_MEM) ? ForwardData_MEM_to_ID :
                            (ForwardB_EX == FWD_WB)  ? WData_WB              :
                                                        Data_rt_EX;

    assign ALU_a_EX = (ASel_EX == A_RS)   ? Data_rs_EX_fwd :
                      (ASel_EX == A_PC4)  ? PCPlus4_EX     :
                      (ASel_EX == A_ZERO) ? 32'h0000_0000  :
                      (ASel_EX == A_RT)   ? Data_rt_EX_fwd :
                                            32'h0000_0000;

    assign ALU_b_EX = (BSel_EX == B_RT)        ? Data_rt_EX_fwd        :
                      (BSel_EX == B_IMM)       ? ImmVal_EX             :
                      (BSel_EX == B_SHAMT)     ? {27'b0, shamt_EX}     :
                      (BSel_EX == B_RS_LOW5)   ? {27'b0, Data_rs_EX_fwd[4:0]} :
                      (BSel_EX == B_ZERO)      ? 32'h0000_0000         :
                                                  32'h0000_0000;

    ALU u_alu (
        .ALU_a(ALU_a_EX),
        .ALU_b(ALU_b_EX),
        .ALUSel(ALUSel_EX),
        .ALU_Result(ALU_Result_EX)
    );

    // Branch compare and jump target selection are resolved in EX.
    // Normal EX forwarding supplies the most recent rs/rt values, including
    // jr/jalr register targets and beq/bne compare operands.
    wire BranchCond_EX;
    branch_comparator u_branch_comp (
        .BrSel(BrSel_EX),
        .Data_rs(Data_rs_EX_fwd),
        .Data_rt(Data_rt_EX_fwd),
        .BranchTaken(BranchCond_EX)
    );
    // Branch target is generated by the main ALU:
    //   ASel=A_PC4, BSel=B_IMM, ImmSel=IMM_BRANCH16 => PCPlus4_EX + (signext(imm16)<<2).

    wire [31:0] SelectedJumpTarget_EX;
    assign SelectedJumpTarget_EX = JumpSel_EX ? Data_rs_EX_fwd : JumpImmTarget_EX;

    wire [1:0] PCSel_EX;
    pc_control u_pc_control (
        .Branch(Branch_EX),
        .Jump(Jump_EX),
        .BranchTaken(BranchCond_EX),
        .PCSel(PCSel_EX)
    );

    wire PCRedirect_EX;
    assign PCRedirect_EX = valid_EX && (PCSel_EX != PC_PLUS4);

    assign NextPC = (PCRedirect_EX && (PCSel_EX == PC_JUMP))   ? SelectedJumpTarget_EX :
                    (PCRedirect_EX && (PCSel_EX == PC_BRANCH)) ? ALU_Result_EX       :
                                                                  PCPlus4_IF;

    // =========================================================
    // EX / MEM register
    // =========================================================
    reg        valid_MEM;
    reg [31:0] Inst_MEM;
    reg [31:0] PC_MEM;
    reg [31:0] PCPlus4_MEM;
    reg [31:0] ALU_Result_MEM;
    reg [31:0] StoreData_MEM;
    reg [4:0]  DestReg_MEM;
    reg [1:0]  WBSel_MEM;
    reg [1:0]  WdLen_MEM;
    reg [1:0]  MemRW_MEM;
    reg        LoadEx_MEM;
    reg        RegWEn_MEM;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_MEM      <= 1'b0;
            Inst_MEM       <= 32'h0000_0000;
            PC_MEM         <= 32'h0000_0000;
            PCPlus4_MEM    <= 32'h0000_0000;
            ALU_Result_MEM <= 32'h0000_0000;
            StoreData_MEM  <= 32'h0000_0000;
            DestReg_MEM    <= 5'd0;
            WBSel_MEM      <= WB_NONE;
            WdLen_MEM      <= 2'b11;
            MemRW_MEM      <= MEM_IDLE;
            LoadEx_MEM     <= 1'b0;
            RegWEn_MEM     <= 1'b0;
        end else begin
            valid_MEM      <= valid_EX;
            Inst_MEM       <= Inst_EX;
            PC_MEM         <= PC_EX;
            PCPlus4_MEM    <= PCPlus4_EX;
            ALU_Result_MEM <= ALU_Result_EX;
            StoreData_MEM  <= Data_rt_EX_fwd;
            DestReg_MEM    <= DestReg_EX;
            WBSel_MEM      <= WBSel_EX;
            WdLen_MEM      <= WdLen_EX;
            MemRW_MEM      <= MemRW_EX;
            LoadEx_MEM     <= LoadEx_EX;
            RegWEn_MEM     <= valid_EX ? RegWEn_EX : 1'b0;
        end
    end

    // =========================================================
    // MEM stage blocks
    // =========================================================
    wire [31:0] Data_RD_WB;
    wire DataMemoryMisalignedAccess_MEM;

    data_memory #(
        .MEM_AW(DMEM_AW)
    ) u_dmem (
        .clk(clk),
        .rst(rst),
        .Addr(ALU_Result_MEM),
        .Data_rt(StoreData_MEM),
        .WdLen(WdLen_MEM),
        .MemRW(MemRW_MEM),
        .LoadEx(LoadEx_MEM),
        .Data_RD(Data_RD_WB),
        .MisalignedAccess(DataMemoryMisalignedAccess_MEM)
    );

    assign ForwardData_MEM_to_ID = (WBSel_MEM == WB_PC4) ? PCPlus4_MEM :
                                   (WBSel_MEM == WB_MEM) ? Data_RD_WB  :
                                                           ALU_Result_MEM;

    // =========================================================
    // MEM / WB register
    // Data_RD_WB is supplied by the synchronous data_memory wrapper already
    // aligned to the WB stage, so the wrapper itself acts as the load-data
    // side of the MEM/WB register.
    // =========================================================
    reg        valid_WB;
    reg [31:0] Inst_WB;
    reg [31:0] PC_WB;
    reg [31:0] PCPlus4_WB;
    reg [31:0] ALU_Result_WB;
    reg [1:0]  WBSel_WB;
    reg [4:0]  DestReg_WB_reg;
    reg        RegWEn_WB_reg;

    assign DestReg_WB = DestReg_WB_reg;
    assign RegWEn_WB  = RegWEn_WB_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_WB       <= 1'b0;
            Inst_WB        <= 32'h0000_0000;
            PC_WB          <= 32'h0000_0000;
            PCPlus4_WB     <= 32'h0000_0000;
            ALU_Result_WB  <= 32'h0000_0000;
            WBSel_WB       <= WB_NONE;
            DestReg_WB_reg <= 5'd0;
            RegWEn_WB_reg  <= 1'b0;
        end else begin
            valid_WB       <= valid_MEM;
            Inst_WB        <= Inst_MEM;
            PC_WB          <= PC_MEM;
            PCPlus4_WB     <= PCPlus4_MEM;
            ALU_Result_WB  <= ALU_Result_MEM;
            WBSel_WB       <= WBSel_MEM;
            DestReg_WB_reg <= DestReg_MEM;
            RegWEn_WB_reg  <= valid_MEM ? RegWEn_MEM : 1'b0;
        end
    end

    // =========================================================
    // WB stage blocks
    // =========================================================
    assign WData_WB = (WBSel_WB == WB_MEM) ? Data_RD_WB     :
                      (WBSel_WB == WB_ALU) ? ALU_Result_WB  :
                      (WBSel_WB == WB_PC4) ? PCPlus4_WB     :
                                             32'h0000_0000;

    // =========================================================
    // Hazard / forwarding controls
    // =========================================================
    wire MemRead_EX;
    assign MemRead_EX = (MemRW_EX == MEM_LOAD);

    hazard_unit u_hazard (
        .RsUsed_ID(RsUsed_ID),
        .RtUsed_ID(RtUsed_ID),
        .rs_ID(rs_ID),
        .rt_ID(rt_ID),
        .rs_EX(rs_EX),
        .rt_EX(rt_EX),
        .DestReg_EX(DestReg_EX),
        .DestReg_MEM(DestReg_MEM),
        .DestReg_WB(DestReg_WB),
        .RegWEn_EX(RegWEn_EX),
        .RegWEn_MEM(RegWEn_MEM),
        .RegWEn_WB(RegWEn_WB),
        .MemRead_EX(MemRead_EX),
        .PCRedirect_EX(PCRedirect_EX),
        .ForwardA_EX(ForwardA_EX),
        .ForwardB_EX(ForwardB_EX),
        .Stall_PC(Stall_PC),
        .Stall_IF_ID(Stall_IF_ID),
        .Flush_IF_ID(Flush_IF_ID),
        .Flush_ID_EX(Flush_ID_EX)
    );

    // =========================================================
    // Debug / CRT retire contract
    // =========================================================
    assign dbg_wb_valid     = valid_WB;
    assign dbg_wb_pc        = PC_WB;
    assign dbg_wb_inst      = Inst_WB;
    assign dbg_wb_reg_wen   = RegWEn_WB;
    assign dbg_wb_write_reg = DestReg_WB;
    assign dbg_wb_wdata     = WData_WB;
    assign dbg_if_pc        = PC_IF;
    assign dbg_id_inst      = Inst_ID;
    assign dbg_ex_alu_result = ALU_Result_EX;
    assign dbg_next_pc      = NextPC;
endmodule
