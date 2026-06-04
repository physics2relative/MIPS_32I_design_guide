`timescale 1ns/1ps

module tb_control_unit;
    parameter VECTOR_WIDTH = 37;
    parameter MAX_VECTORS  = 1024;

    reg [VECTOR_WIDTH-1:0] vectors [0:MAX_VECTORS-1];

    reg [5:0] opcode;
    reg [5:0] funct;

    wire       RegWEn;
    wire [1:0] DestSel;
    wire [1:0] ASel;
    wire [2:0] BSel;
    wire [1:0] ImmSel;
    wire       BrSel;
    wire [3:0] ALUSel;
    wire [1:0] WBSel;
    wire [1:0] WdLen;
    wire [1:0] MemRW;
    wire       LoadEx;
    wire       Branch;
    wire       Jump;
    wire       JumpSel;

    reg       exp_RegWEn;
    reg [1:0] exp_DestSel;
    reg [1:0] exp_ASel;
    reg [2:0] exp_BSel;
    reg [1:0] exp_ImmSel;
    reg       exp_BrSel;
    reg [3:0] exp_ALUSel;
    reg [1:0] exp_WBSel;
    reg [1:0] exp_WdLen;
    reg [1:0] exp_MemRW;
    reg       exp_LoadEx;
    reg       exp_Branch;
    reg       exp_Jump;
    reg       exp_JumpSel;

    integer num_vectors;
    integer vector_index;
    integer error_count;
    reg [1023:0] vector_file;

    reg [8*16-1:0] instr_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*32-1:0] status_ascii;

    control_unit dut (
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

    function [8*16-1:0] decode_instr;
        input [5:0] op;
        input [5:0] fn;
        begin
            case (op)
                6'b000000: begin
                    case (fn)
                        6'b100000: decode_instr = "ADD             ";
                        6'b100001: decode_instr = "ADDU            ";
                        6'b100010: decode_instr = "SUB             ";
                        6'b100011: decode_instr = "SUBU            ";
                        6'b100100: decode_instr = "AND             ";
                        6'b100101: decode_instr = "OR              ";
                        6'b100110: decode_instr = "XOR             ";
                        6'b100111: decode_instr = "NOR             ";
                        6'b101010: decode_instr = "SLT             ";
                        6'b101011: decode_instr = "SLTU            ";
                        6'b101100: decode_instr = "ABS             ";
                        6'b000000: decode_instr = "SLL             ";
                        6'b000010: decode_instr = "SRL             ";
                        6'b000011: decode_instr = "SRA             ";
                        6'b000100: decode_instr = "SLLV            ";
                        6'b000110: decode_instr = "SRLV            ";
                        6'b000111: decode_instr = "SRAV            ";
                        6'b001000: decode_instr = "JR              ";
                        6'b001001: decode_instr = "JALR            ";
                        default:   decode_instr = "RTYPE_UNKNOWN   ";
                    endcase
                end
                6'b001000: decode_instr = "ADDI            ";
                6'b001001: decode_instr = "ADDIU           ";
                6'b001100: decode_instr = "ANDI            ";
                6'b001101: decode_instr = "ORI             ";
                6'b001110: decode_instr = "XORI            ";
                6'b001010: decode_instr = "SLTI            ";
                6'b001011: decode_instr = "SLTIU           ";
                6'b001111: decode_instr = "LUI             ";
                6'b100000: decode_instr = "LB              ";
                6'b100100: decode_instr = "LBU             ";
                6'b100001: decode_instr = "LH              ";
                6'b100101: decode_instr = "LHU             ";
                6'b100011: decode_instr = "LW              ";
                6'b101000: decode_instr = "SB              ";
                6'b101001: decode_instr = "SH              ";
                6'b101011: decode_instr = "SW              ";
                6'b000100: decode_instr = "BEQ             ";
                6'b000101: decode_instr = "BNE             ";
                6'b000010: decode_instr = "J               ";
                6'b000011: decode_instr = "JAL             ";
                default:   decode_instr = "UNKNOWN_NOP     ";
            endcase
        end
    endfunction

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_control_unit, "ACMTF");

        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) begin
            vector_file = "../../../../../test_vectors/generated/control_unit/vectors.mem";
        end
        if (!$value$plusargs("NUM_VECTORS=%d", num_vectors)) begin
            num_vectors = 40;
        end

        $display("=======================================================");
        $display(" MIPS control_unit golden-vector test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");

        $readmemh(vector_file, vectors);

        opcode = 6'd0;
        funct = 6'd0;
        instr_ascii = "IDLE            ";
        result_ascii = "IDLE            ";
        status_ascii = "IDLE";
        error_count = 0;
        #5;

        for (vector_index = 0; vector_index < num_vectors; vector_index = vector_index + 1) begin
            {opcode, funct, exp_RegWEn, exp_DestSel, exp_ASel, exp_BSel, exp_ImmSel,
             exp_BrSel, exp_ALUSel, exp_WBSel, exp_WdLen, exp_MemRW, exp_LoadEx,
             exp_Branch, exp_Jump, exp_JumpSel} = vectors[vector_index];

            instr_ascii = decode_instr(opcode, funct);
            result_ascii = "RUN             ";
            status_ascii = {"CHECK ", instr_ascii};
            #1;

            if ((RegWEn !== exp_RegWEn) || (DestSel !== exp_DestSel) ||
                (ASel !== exp_ASel) || (BSel !== exp_BSel) || (ImmSel !== exp_ImmSel) ||
                (BrSel !== exp_BrSel) || (ALUSel !== exp_ALUSel) || (WBSel !== exp_WBSel) ||
                (WdLen !== exp_WdLen) || (MemRW !== exp_MemRW) || (LoadEx !== exp_LoadEx) ||
                (Branch !== exp_Branch) || (Jump !== exp_Jump) || (JumpSel !== exp_JumpSel)) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            ";
                status_ascii = {"MISMATCH ", instr_ascii};
                $display("CONTROL_MISMATCH index=%0d instr=%0s opcode=%06b funct=%06b", vector_index, instr_ascii, opcode, funct);
                $display("  got: RegWEn=%0b DestSel=%02b ASel=%02b BSel=%03b ImmSel=%02b BrSel=%0b ALUSel=%04b WBSel=%02b WdLen=%02b MemRW=%02b LoadEx=%0b Branch=%0b Jump=%0b JumpSel=%0b",
                         RegWEn, DestSel, ASel, BSel, ImmSel, BrSel, ALUSel, WBSel, WdLen, MemRW, LoadEx, Branch, Jump, JumpSel);
                $display("  exp: RegWEn=%0b DestSel=%02b ASel=%02b BSel=%03b ImmSel=%02b BrSel=%0b ALUSel=%04b WBSel=%02b WdLen=%02b MemRW=%02b LoadEx=%0b Branch=%0b Jump=%0b JumpSel=%0b",
                         exp_RegWEn, exp_DestSel, exp_ASel, exp_BSel, exp_ImmSel, exp_BrSel, exp_ALUSel, exp_WBSel, exp_WdLen, exp_MemRW, exp_LoadEx, exp_Branch, exp_Jump, exp_JumpSel);
            end else begin
                result_ascii = "PASS            ";
                status_ascii = {"MATCH ", instr_ascii};
                $display("CONTROL_MATCH index=%0d instr=%0s opcode=%06b funct=%06b", vector_index, instr_ascii, opcode, funct);
            end
            #4;
        end

        $display("=======================================================");
        if (error_count == 0) begin
            status_ascii = "PASS";
            $display("CONTROL_UNIT_TEST_PASS vectors=%0d", num_vectors);
        end else begin
            status_ascii = "FAIL";
            $display("CONTROL_UNIT_TEST_FAIL vectors=%0d errors=%0d", num_vectors, error_count);
        end
        $display("=======================================================");
        $finish;
    end
endmodule
