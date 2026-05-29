`timescale 1ns/1ps

// =============================================================
// MIPS single-cycle top
// -------------------------------------------------------------
// Integrates the verified single-cycle blocks:
//   PC register, instruction memory, control unit, register file,
//   immediate generator, branch comparator, jump target generator,
//   ALU, data memory, and top-level selector muxes.
//
// Small selectors are intentionally kept in this top module because
// the Logisim block diagram treats them as wiring/mux glue rather than
// standalone reusable blocks.
// =============================================================

module mips_single_cycle_top #(
    parameter IMEM_AW = 9,
    parameter DMEM_AW = 10,
    parameter IMEM_INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rst,

    // Debug/verification observability ports.
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_next_pc,
    output wire [31:0] dbg_pc_plus4,
    output wire [31:0] dbg_inst,
    output wire [31:0] dbg_data_rs,
    output wire [31:0] dbg_data_rt,
    output wire [31:0] dbg_imm_val,
    output wire [31:0] dbg_branch_off,
    output wire [31:0] dbg_alu_a,
    output wire [31:0] dbg_alu_b,
    output wire [31:0] dbg_alu_result,
    output wire [31:0] dbg_data_rd,
    output wire [31:0] dbg_wdata,
    output wire [31:0] dbg_jump_imm_target,
    output wire [31:0] dbg_selected_jump_target,
    output wire [4:0]  dbg_addr_rs,
    output wire [4:0]  dbg_addr_rt,
    output wire [4:0]  dbg_addr_rd,
    output wire [4:0]  dbg_write_reg,
    output wire        dbg_reg_wen,
    output wire        dbg_branch,
    output wire        dbg_jump,
    output wire        dbg_branch_taken,
    output wire [1:0]  dbg_pcsel
);
    // Top-level selector encodings.  These match control_unit.v.
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

    localparam [1:0] PC_BRANCH = 2'b01;
    localparam [1:0] PC_JUMP   = 2'b10;

    // PC path.
    reg [31:0] PC;
    wire [31:0] PCPlus4;
    wire [31:0] NextPC;

    assign PCPlus4 = PC + 32'd4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 32'h0000_0000;
        end else begin
            PC <= NextPC;
        end
    end

    // Instruction split.
    wire [31:0] Inst;
    wire [5:0]  opcode;
    wire [4:0]  rs;
    wire [4:0]  rt;
    wire [4:0]  rd;
    wire [4:0]  shamt;
    wire [5:0]  funct;
    wire [15:0] imm16;
    wire [25:0] target26;

    instruction_memory #(
        .INIT_FILE(IMEM_INIT_FILE),
        .MEM_AW(IMEM_AW)
    ) u_imem (
        .Addr(PC),
        .Inst(Inst)
    );

    instruction_splitter u_inst_splitter (
        .Inst(Inst),
        .opcode(opcode),
        .rs(rs),
        .rt(rt),
        .rd(rd),
        .shamt(shamt),
        .funct(funct),
        .imm16(imm16),
        .target26(target26)
    );

    // Control signals.
    wire       RegWEn;
    wire [1:0] DestSel;
    wire [1:0] ASel;
    wire [2:0] BSel;
    wire [1:0] ImmSel;
    wire       BrSel;
    wire [3:0] ALUSel;
    wire [1:0] WBSel;
    wire [1:0] WdLen;
    wire [2:0] MemRW;
    wire       LoadEx;
    wire       Branch;
    wire       Jump;
    wire       JumpSel;

    control_unit u_control (
        .opcode(opcode),
        .funct(funct),
        .RegWEn(RegWEn),
        .DestSel(DestSel),
        .ASel(ASel),
        .BSel(BSel),
        .ImmSel(ImmSel),
        .BrSel(BrSel),
        .ALUSel(ALUSel),
        .WBSel(WBSel),
        .WdLen(WdLen),
        .MemRW(MemRW),
        .LoadEx(LoadEx),
        .Branch(Branch),
        .Jump(Jump),
        .JumpSel(JumpSel)
    );

    // Register file and writeback path.
    reg [4:0] WriteReg;
    reg [31:0] WData;
    wire [31:0] Data_rs;
    wire [31:0] Data_rt;
    wire [31:0] Data_RD;
    wire [31:0] ALU_Result;

    always @(*) begin
        case (DestSel)
            DEST_RT:   WriteReg = rt;
            DEST_RD:   WriteReg = rd;
            DEST_RA:   WriteReg = 5'd31;
            DEST_NONE: WriteReg = 5'd0;
            default:   WriteReg = 5'd0;
        endcase
    end

    always @(*) begin
        case (WBSel)
            WB_MEM:  WData = Data_RD;
            WB_ALU:  WData = ALU_Result;
            WB_PC4:  WData = PCPlus4;
            WB_NONE: WData = 32'h0000_0000;
            default: WData = 32'h0000_0000;
        endcase
    end

    register_file u_regfile (
        .clk(clk),
        .rst(rst),
        .RegWEn(RegWEn),
        .Addr_Rs(rs),
        .Addr_Rt(rt),
        .Addr_WR(WriteReg),
        .WData(WData),
        .Data_Rs(Data_rs),
        .Data_Rt(Data_rt)
    );

    // Immediate and ALU operands.
    wire [31:0] ImmVal;
    reg  [31:0] ALU_a;
    reg  [31:0] ALU_b;

    immediate_generator u_immgen (
        .ImmSel(ImmSel),
        .imm16(imm16),
        .ImmVal(ImmVal)
    );

    always @(*) begin
        case (ASel)
            A_RS:   ALU_a = Data_rs;
            A_PC4:  ALU_a = PCPlus4;
            A_ZERO: ALU_a = 32'h0000_0000;
            A_RT:   ALU_a = Data_rt;
            default: ALU_a = 32'h0000_0000;
        endcase
    end

    always @(*) begin
        case (BSel)
            B_RT:        ALU_b = Data_rt;
            B_IMM:       ALU_b = ImmVal;
            B_SHAMT:     ALU_b = {27'b0, shamt};
            B_RS_LOW5:   ALU_b = {27'b0, Data_rs[4:0]};
            B_ZERO:      ALU_b = 32'h0000_0000;
            default:     ALU_b = 32'h0000_0000;
        endcase
    end

    ALU u_alu (
        .ALU_a(ALU_a),
        .ALU_b(ALU_b),
        .ALUSel(ALUSel),
        .ALU_Result(ALU_Result)
    );

    // Data memory.
    data_memory #(
        .MEM_AW(DMEM_AW)
    ) u_dmem (
        .clk(clk),
        .Addr(ALU_Result),
        .Data_rt(Data_rt),
        .WdLen(WdLen),
        .MemRW(MemRW),
        .LoadEx(LoadEx),
        .Data_RD(Data_RD)
    );

    // Branch/jump/next-PC path.
    wire BranchTaken;
    wire [1:0] PCSel;
    wire [31:0] JumpImmTarget;
    wire [31:0] SelectedJumpTarget;

    branch_comparator u_branch_comp (
        .BrSel(BrSel),
        .Data_rs(Data_rs),
        .Data_rt(Data_rt),
        .BranchTaken(BranchTaken)
    );

    jump_target_generator u_jump_target (
        .Jump(Jump),
        .JumpSel(JumpSel),
        .PCPlus4(PCPlus4),
        .target26(target26),
        .Data_rs(Data_rs),
        .JumpImmTarget(JumpImmTarget),
        .SelectedJumpTarget(SelectedJumpTarget)
    );

    pc_control u_pc_control (
        .Branch(Branch),
        .Jump(Jump),
        .BranchTaken(BranchTaken),
        .PCSel(PCSel)
    );

    assign NextPC = (PCSel == PC_BRANCH) ? ALU_Result :
                    (PCSel == PC_JUMP)   ? SelectedJumpTarget :
                                           PCPlus4;

    // Debug assignments.
    assign dbg_pc                   = PC;
    assign dbg_next_pc              = NextPC;
    assign dbg_pc_plus4             = PCPlus4;
    assign dbg_inst                 = Inst;
    assign dbg_data_rs              = Data_rs;
    assign dbg_data_rt              = Data_rt;
    assign dbg_imm_val              = ImmVal;
    assign dbg_branch_off           = (ImmSel == 2'b11) ? ImmVal : 32'h0000_0000;
    assign dbg_alu_a                = ALU_a;
    assign dbg_alu_b                = ALU_b;
    assign dbg_alu_result           = ALU_Result;
    assign dbg_data_rd              = Data_RD;
    assign dbg_wdata                = WData;
    assign dbg_jump_imm_target      = JumpImmTarget;
    assign dbg_selected_jump_target = SelectedJumpTarget;
    assign dbg_addr_rs              = rs;
    assign dbg_addr_rt              = rt;
    assign dbg_addr_rd              = rd;
    assign dbg_write_reg            = WriteReg;
    assign dbg_reg_wen              = RegWEn;
    assign dbg_branch               = Branch;
    assign dbg_jump                 = Jump;
    assign dbg_branch_taken         = BranchTaken;
    assign dbg_pcsel                = PCSel;
endmodule
