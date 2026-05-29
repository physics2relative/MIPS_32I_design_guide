`timescale 1ns/1ps

module tb_immediate_generator;
    parameter VECTOR_WIDTH = 50;
    parameter MAX_VECTORS  = 1024;

    reg [VECTOR_WIDTH-1:0] vectors [0:MAX_VECTORS-1];

    reg  [1:0]  ImmSel;
    reg  [15:0] imm16;
    wire [31:0] ImmVal;

    reg [31:0] expected_imm;

    integer num_vectors;
    integer vector_index;
    integer error_count;
    reg [1023:0] vector_file;

    reg [8*16-1:0] imm_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*32-1:0] status_ascii;

    immediate_generator dut (
        .ImmSel(ImmSel),
        .imm16(imm16),
        .ImmVal(ImmVal)
    );

    function [8*16-1:0] decode_immsel;
        input [1:0] sel;
        begin
            case (sel)
                2'b00: decode_immsel = "SIGN16          ";
                2'b01: decode_immsel = "ZERO16          ";
                2'b10: decode_immsel = "LUI16           ";
                2'b11: decode_immsel = "BRANCH16        ";
                default: decode_immsel = "UNKNOWN         ";
            endcase
        end
    endfunction

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_immediate_generator, "ACMTF");
        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) vector_file = "../../../../../test_vectors/generated/imm_generator/vectors.mem";
        if (!$value$plusargs("NUM_VECTORS=%d", num_vectors)) num_vectors = 16;
        $display("=======================================================");
        $display(" MIPS immediate_generator imm16-only test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");
        $readmemh(vector_file, vectors);
        ImmSel = 2'b00; imm16 = 16'h0000;
        expected_imm = 32'h0;
        imm_ascii = "IDLE            "; result_ascii = "IDLE            "; status_ascii = "IDLE"; error_count = 0;
        #5;
        for (vector_index = 0; vector_index < num_vectors; vector_index = vector_index + 1) begin
            {ImmSel, imm16, expected_imm} = vectors[vector_index];
            imm_ascii = decode_immsel(ImmSel);
            result_ascii = "RUN             "; status_ascii = {"CHECK ", imm_ascii};
            #1;
            if (ImmVal !== expected_imm) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            "; status_ascii = {"MISMATCH ", imm_ascii};
                $display("IMM_MISMATCH index=%0d sel=%0s imm16=0x%04h", vector_index, imm_ascii, imm16);
                $display("  got: ImmVal=0x%08h", ImmVal);
                $display("  exp: ImmVal=0x%08h", expected_imm);
            end else begin
                result_ascii = "PASS            "; status_ascii = {"MATCH ", imm_ascii};
                $display("IMM_MATCH index=%0d sel=%0s imm16=0x%04h ImmVal=0x%08h", vector_index, imm_ascii, imm16, ImmVal);
            end
            #4;
        end
        $display("=======================================================");
        if (error_count == 0) begin status_ascii = "PASS"; $display("IMMEDIATE_GENERATOR_TEST_PASS vectors=%0d", num_vectors); end
        else begin status_ascii = "FAIL"; $display("IMMEDIATE_GENERATOR_TEST_FAIL vectors=%0d errors=%0d", num_vectors, error_count); end
        $display("=======================================================");
        $finish;
    end
endmodule
