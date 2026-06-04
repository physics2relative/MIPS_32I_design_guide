`timescale 1ns/1ps

// =============================================================
// MIPS single-cycle Control Unit
// -------------------------------------------------------------
// Decode opcode/funct into the control signals defined in
// doc/mips_functional_spec.md single-cycle control table.
// Invalid/unsupported encodings produce a side-effect-free NOP.
// =============================================================

module control_unit (
    input  [5:0] opcode,
    input  [5:0] funct,

    output reg       RegWEn,
    output reg [1:0] DestSel,
    output reg [1:0] ASel,
    output reg [2:0] BSel,
    output reg [1:0] ImmSel,
    output reg       BrSel,
    output reg [3:0] ALUSel,
    output reg [1:0] WBSel,
    output reg [1:0] WdLen,
    output reg [1:0] MemRW,
    output reg       LoadEx,
    output reg       Branch,
    output reg       Jump,
    output reg       JumpSel,
    output reg       RsUsed,
    output reg       RtUsed
);
    // opcode
    localparam [5:0] OP_RTYPE = 6'b000000;
    localparam [5:0] OP_J     = 6'b000010;
    localparam [5:0] OP_JAL   = 6'b000011;
    localparam [5:0] OP_BEQ   = 6'b000100;
    localparam [5:0] OP_BNE   = 6'b000101;
    localparam [5:0] OP_ADDI  = 6'b001000;
    localparam [5:0] OP_ADDIU = 6'b001001;
    localparam [5:0] OP_SLTI  = 6'b001010;
    localparam [5:0] OP_SLTIU = 6'b001011;
    localparam [5:0] OP_ANDI  = 6'b001100;
    localparam [5:0] OP_ORI   = 6'b001101;
    localparam [5:0] OP_XORI  = 6'b001110;
    localparam [5:0] OP_LUI   = 6'b001111;
    localparam [5:0] OP_LB    = 6'b100000;
    localparam [5:0] OP_LH    = 6'b100001;
    localparam [5:0] OP_LW    = 6'b100011;
    localparam [5:0] OP_LBU   = 6'b100100;
    localparam [5:0] OP_LHU   = 6'b100101;
    localparam [5:0] OP_SB    = 6'b101000;
    localparam [5:0] OP_SH    = 6'b101001;
    localparam [5:0] OP_SW    = 6'b101011;

    // funct
    localparam [5:0] FN_SLL   = 6'b000000;
    localparam [5:0] FN_SRL   = 6'b000010;
    localparam [5:0] FN_SRA   = 6'b000011;
    localparam [5:0] FN_SLLV  = 6'b000100;
    localparam [5:0] FN_SRLV  = 6'b000110;
    localparam [5:0] FN_SRAV  = 6'b000111;
    localparam [5:0] FN_JR    = 6'b001000;
    localparam [5:0] FN_JALR  = 6'b001001;
    localparam [5:0] FN_ADD   = 6'b100000;
    localparam [5:0] FN_ADDU  = 6'b100001;
    localparam [5:0] FN_SUB   = 6'b100010;
    localparam [5:0] FN_SUBU  = 6'b100011;
    localparam [5:0] FN_AND   = 6'b100100;
    localparam [5:0] FN_OR    = 6'b100101;
    localparam [5:0] FN_XOR   = 6'b100110;
    localparam [5:0] FN_NOR   = 6'b100111;
    localparam [5:0] FN_SLT   = 6'b101010;
    localparam [5:0] FN_SLTU  = 6'b101011;
    // Project custom integer ABS: abs rd, rs. Not a standard MIPS integer instruction.
    localparam [5:0] FN_ABS   = 6'b101100;

    // DestSel
    localparam [1:0] DEST_RT   = 2'b00;
    localparam [1:0] DEST_RD   = 2'b01;
    localparam [1:0] DEST_RA   = 2'b10;
    localparam [1:0] DEST_NONE = 2'b11;

    // WBSel
    localparam [1:0] WB_MEM  = 2'b00;
    localparam [1:0] WB_ALU  = 2'b01;
    localparam [1:0] WB_PC4  = 2'b10;
    localparam [1:0] WB_NONE = 2'b11;

    // ASel
    localparam [1:0] A_RS   = 2'b00;
    localparam [1:0] A_PC4  = 2'b01;
    localparam [1:0] A_ZERO = 2'b10;
    localparam [1:0] A_RT   = 2'b11;

    // BSel
    localparam [2:0] B_RT      = 3'b000;
    localparam [2:0] B_IMM     = 3'b001;
    localparam [2:0] B_SHAMT   = 3'b010;
    localparam [2:0] B_RS_LOW5 = 3'b011;
    localparam [2:0] B_ZERO    = 3'b100;
    localparam [2:0] B_NONE    = 3'b111;

    // ImmSel: 16-bit immediate format only. Jump target26 bypasses ImmGen.
    localparam [1:0] IMM_SIGN16   = 2'b00;
    localparam [1:0] IMM_ZERO16   = 2'b01;
    localparam [1:0] IMM_LUI16    = 2'b10;
    localparam [1:0] IMM_BRANCH16 = 2'b11;

    // ALUSel
    localparam [3:0] ALU_ADD  = 4'b0000;
    localparam [3:0] ALU_SUB  = 4'b0001;
    localparam [3:0] ALU_AND  = 4'b0010;
    localparam [3:0] ALU_OR   = 4'b0011;
    localparam [3:0] ALU_XOR  = 4'b0100;
    localparam [3:0] ALU_SLT  = 4'b0101;
    localparam [3:0] ALU_SLTU = 4'b0110;
    localparam [3:0] ALU_SLL  = 4'b0111;
    localparam [3:0] ALU_SRL  = 4'b1000;
    localparam [3:0] ALU_SRA  = 4'b1001;
    localparam [3:0] ALU_NOR  = 4'b1010;
    localparam [3:0] ALU_ABS  = 4'b1011;
    localparam [3:0] ALU_NONE = 4'b1111;

    // Memory
    localparam [1:0] MEM_BYTE = 2'b00;
    localparam [1:0] MEM_HALF = 2'b01;
    localparam [1:0] MEM_WORD = 2'b10;
    localparam [1:0] MEM_NONE_LEN = 2'b11;

    localparam [1:0] MEM_IDLE  = 2'b00;
    localparam [1:0] MEM_LOAD  = 2'b01;
    localparam [1:0] MEM_STORE = 2'b10;

    task set_nop;
        begin
            RegWEn  = 1'b0;
            DestSel = DEST_NONE;
            ASel    = A_ZERO;
            BSel    = B_ZERO;
            ImmSel  = IMM_SIGN16;
            BrSel   = 1'b0;
            ALUSel  = ALU_NONE;
            WBSel   = WB_NONE;
            WdLen   = MEM_NONE_LEN;
            MemRW   = MEM_IDLE;
            LoadEx  = 1'b0;
            Branch  = 1'b0;
            Jump    = 1'b0;
            JumpSel = 1'b0;
            RsUsed  = 1'b0;
            RtUsed  = 1'b0;
        end
    endtask

    task set_rtype_alu;
        input [3:0] alu_sel;
        begin
            RegWEn  = 1'b1;
            DestSel = DEST_RD;
            ASel    = A_RS;
            BSel    = B_RT;
            ImmSel  = IMM_SIGN16;
            BrSel   = 1'b0;
            ALUSel  = alu_sel;
            WBSel   = WB_ALU;
            WdLen   = MEM_NONE_LEN;
            MemRW   = MEM_IDLE;
            LoadEx  = 1'b0;
            Branch  = 1'b0;
            Jump    = 1'b0;
            JumpSel = 1'b0;
            RsUsed  = 1'b1;
            RtUsed  = 1'b1;
        end
    endtask


    task set_rtype_unary_rs;
        input [3:0] alu_sel;
        begin
            set_rtype_alu(alu_sel);
            BSel = B_ZERO;
            RsUsed = 1'b1;
            RtUsed = 1'b0;
        end
    endtask

    task set_shift;
        input [2:0] b_sel;
        input [3:0] alu_sel;
        begin
            set_rtype_alu(alu_sel);
            ASel = A_RT;
            BSel = b_sel;
        end
    endtask

    task set_itype_alu;
        input [1:0] imm_sel;
        input [3:0] alu_sel;
        begin
            RegWEn  = 1'b1;
            DestSel = DEST_RT;
            ASel    = A_RS;
            BSel    = B_IMM;
            ImmSel  = imm_sel;
            BrSel   = 1'b0;
            ALUSel  = alu_sel;
            WBSel   = WB_ALU;
            WdLen   = MEM_NONE_LEN;
            MemRW   = MEM_IDLE;
            LoadEx  = 1'b0;
            Branch  = 1'b0;
            Jump    = 1'b0;
            JumpSel = 1'b0;
            RsUsed  = 1'b1;
            RtUsed  = 1'b0;
        end
    endtask

    task set_load;
        input [1:0] width_sel;
        input       load_ex_sel;
        begin
            RegWEn  = 1'b1;
            DestSel = DEST_RT;
            ASel    = A_RS;
            BSel    = B_IMM;
            ImmSel  = IMM_SIGN16;
            BrSel   = 1'b0;
            ALUSel  = ALU_ADD;
            WBSel   = WB_MEM;
            WdLen   = width_sel;
            MemRW   = MEM_LOAD;
            LoadEx  = load_ex_sel;
            Branch  = 1'b0;
            Jump    = 1'b0;
            JumpSel = 1'b0;
            RsUsed  = 1'b1;
            RtUsed  = 1'b0;
        end
    endtask

    task set_store;
        input [1:0] width_sel;
        begin
            RegWEn  = 1'b0;
            DestSel = DEST_NONE;
            ASel    = A_RS;
            BSel    = B_IMM;
            ImmSel  = IMM_SIGN16;
            BrSel   = 1'b0;
            ALUSel  = ALU_ADD;
            WBSel   = WB_NONE;
            WdLen   = width_sel;
            MemRW   = MEM_STORE;
            LoadEx  = 1'b0;
            Branch  = 1'b0;
            Jump    = 1'b0;
            JumpSel = 1'b0;
            RsUsed  = 1'b1;
            RtUsed  = 1'b1;
        end
    endtask

    always @(*) begin
        set_nop;
        case (opcode)
            OP_RTYPE: begin
                case (funct)
                    FN_ADD, FN_ADDU: set_rtype_alu(ALU_ADD);
                    FN_SUB, FN_SUBU: set_rtype_alu(ALU_SUB);
                    FN_AND:          set_rtype_alu(ALU_AND);
                    FN_OR:           set_rtype_alu(ALU_OR);
                    FN_XOR:          set_rtype_alu(ALU_XOR);
                    FN_NOR:          set_rtype_alu(ALU_NOR);
                    FN_SLT:          set_rtype_alu(ALU_SLT);
                    FN_SLTU:         set_rtype_alu(ALU_SLTU);
                    FN_ABS:          set_rtype_unary_rs(ALU_ABS);
                    FN_SLL: begin set_shift(B_SHAMT, ALU_SLL); RsUsed = 1'b0; RtUsed = 1'b1; end
                    FN_SRL: begin set_shift(B_SHAMT, ALU_SRL); RsUsed = 1'b0; RtUsed = 1'b1; end
                    FN_SRA: begin set_shift(B_SHAMT, ALU_SRA); RsUsed = 1'b0; RtUsed = 1'b1; end
                    FN_SLLV:         set_shift(B_RS_LOW5, ALU_SLL);
                    FN_SRLV:         set_shift(B_RS_LOW5, ALU_SRL);
                    FN_SRAV:         set_shift(B_RS_LOW5, ALU_SRA);
                    FN_JR: begin
                        RegWEn  = 1'b0;
                        DestSel = DEST_NONE;
                        ASel    = A_RS;
                        BSel    = B_NONE;
                        ImmSel  = IMM_SIGN16;
                        BrSel   = 1'b0;
                        ALUSel  = ALU_NONE;
                        WBSel   = WB_NONE;
                        WdLen   = MEM_NONE_LEN;
                        MemRW   = MEM_IDLE;
                        LoadEx  = 1'b0;
                        Branch  = 1'b0;
                        Jump    = 1'b1;
                        JumpSel = 1'b1;
                        RsUsed  = 1'b1;
                        RtUsed  = 1'b0;
                    end
                    FN_JALR: begin
                        RegWEn  = 1'b1;
                        DestSel = DEST_RD;
                        ASel    = A_RS;
                        BSel    = B_NONE;
                        ImmSel  = IMM_SIGN16;
                        BrSel   = 1'b0;
                        ALUSel  = ALU_NONE;
                        WBSel   = WB_PC4;
                        WdLen   = MEM_NONE_LEN;
                        MemRW   = MEM_IDLE;
                        LoadEx  = 1'b0;
                        Branch  = 1'b0;
                        Jump    = 1'b1;
                        JumpSel = 1'b1;
                        RsUsed  = 1'b1;
                        RtUsed  = 1'b0;
                    end
                    default: set_nop;
                endcase
            end
            OP_ADDI, OP_ADDIU: set_itype_alu(IMM_SIGN16, ALU_ADD);
            OP_ANDI:           set_itype_alu(IMM_ZERO16, ALU_AND);
            OP_ORI:            set_itype_alu(IMM_ZERO16, ALU_OR);
            OP_XORI:           set_itype_alu(IMM_ZERO16, ALU_XOR);
            OP_SLTI:           set_itype_alu(IMM_SIGN16, ALU_SLT);
            OP_SLTIU:          set_itype_alu(IMM_SIGN16, ALU_SLTU);
            OP_LUI: begin
                set_itype_alu(IMM_LUI16, ALU_ADD);
                ASel = A_ZERO;
            end
            OP_LB:  set_load(MEM_BYTE, 1'b0);
            OP_LBU: set_load(MEM_BYTE, 1'b1);
            OP_LH:  set_load(MEM_HALF, 1'b0);
            OP_LHU: set_load(MEM_HALF, 1'b1);
            OP_LW:  set_load(MEM_WORD, 1'b0);
            OP_SB:  set_store(MEM_BYTE);
            OP_SH:  set_store(MEM_HALF);
            OP_SW:  set_store(MEM_WORD);
            OP_BEQ: begin
                RegWEn  = 1'b0;
                DestSel = DEST_NONE;
                ASel    = A_PC4;
                BSel    = B_IMM;
                ImmSel  = IMM_BRANCH16;
                BrSel   = 1'b0;
                ALUSel  = ALU_ADD;
                WBSel   = WB_NONE;
                WdLen   = MEM_NONE_LEN;
                MemRW   = MEM_IDLE;
                LoadEx  = 1'b0;
                Branch  = 1'b1;
                Jump    = 1'b0;
                JumpSel = 1'b0;
                RsUsed  = 1'b1;
                RtUsed  = 1'b1;
            end
            OP_BNE: begin
                RegWEn  = 1'b0;
                DestSel = DEST_NONE;
                ASel    = A_PC4;
                BSel    = B_IMM;
                ImmSel  = IMM_BRANCH16;
                BrSel   = 1'b1;
                ALUSel  = ALU_ADD;
                WBSel   = WB_NONE;
                WdLen   = MEM_NONE_LEN;
                MemRW   = MEM_IDLE;
                LoadEx  = 1'b0;
                Branch  = 1'b1;
                Jump    = 1'b0;
                JumpSel = 1'b0;
                RsUsed  = 1'b1;
                RtUsed  = 1'b1;
            end
            OP_J: begin
                RegWEn  = 1'b0;
                DestSel = DEST_NONE;
                ASel    = A_ZERO;
                BSel    = B_NONE;
                ImmSel  = IMM_SIGN16;
                BrSel   = 1'b0;
                ALUSel  = ALU_NONE;
                WBSel   = WB_NONE;
                WdLen   = MEM_NONE_LEN;
                MemRW   = MEM_IDLE;
                LoadEx  = 1'b0;
                Branch  = 1'b0;
                Jump    = 1'b1;
                JumpSel = 1'b0;
                RsUsed  = 1'b0;
                RtUsed  = 1'b0;
            end
            OP_JAL: begin
                RegWEn  = 1'b1;
                DestSel = DEST_RA;
                ASel    = A_ZERO;
                BSel    = B_NONE;
                ImmSel  = IMM_SIGN16;
                BrSel   = 1'b0;
                ALUSel  = ALU_NONE;
                WBSel   = WB_PC4;
                WdLen   = MEM_NONE_LEN;
                MemRW   = MEM_IDLE;
                LoadEx  = 1'b0;
                Branch  = 1'b0;
                Jump    = 1'b1;
                JumpSel = 1'b0;
                RsUsed  = 1'b0;
                RtUsed  = 1'b0;
            end
            default: set_nop;
        endcase
    end
endmodule
