`timescale 1ns/1ps

module tb_ALU;
    parameter VECTOR_WIDTH = 100;
    parameter MAX_VECTORS  = 1024;

    reg [VECTOR_WIDTH-1:0] vectors [0:MAX_VECTORS-1];

    reg  [31:0] ALU_a;
    reg  [31:0] ALU_b;
    reg  [3:0]  ALUSel;
    wire [31:0] ALU_Result;

    reg  [31:0] expected;
    integer     num_vectors;
    integer     vector_index;
    integer     error_count;
    reg [1023:0] vector_file;

    // Waveform-readable ASCII state.
    reg [8*16-1:0] op_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*16-1:0] status_ascii;

    ALU dut (
        .ALU_a      (ALU_a),
        .ALU_b      (ALU_b),
        .ALUSel     (ALUSel),
        .ALU_Result (ALU_Result)
    );

    function [8*16-1:0] decode_op;
        input [3:0] sel;
        begin
            case (sel)
                4'h0: decode_op = "ADD             ";
                4'h1: decode_op = "SUB             ";
                4'h2: decode_op = "AND             ";
                4'h3: decode_op = "OR              ";
                4'h4: decode_op = "XOR             ";
                4'h5: decode_op = "SLT             ";
                4'h6: decode_op = "SLTU            ";
                4'h7: decode_op = "SLL             ";
                4'h8: decode_op = "SRL             ";
                4'h9: decode_op = "SRA             ";
                4'hA: decode_op = "NOR             ";
                4'hF: decode_op = "NONE            ";
                default: decode_op = "UNKNOWN         ";
            endcase
        end
    endfunction

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_ALU, "ACMTF");

        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) begin
            vector_file = "../../../../../test_vectors/generated/alu/vectors.mem";
        end
        if (!$value$plusargs("NUM_VECTORS=%d", num_vectors)) begin
            num_vectors = 22;
        end

        $display("=======================================================");
        $display(" MIPS ALU golden-vector test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");

        $readmemh(vector_file, vectors);

        ALU_a = 32'h0000_0000;
        ALU_b = 32'h0000_0000;
        ALUSel = 4'hF;
        expected = 32'h0000_0000;
        op_ascii = "IDLE            ";
        result_ascii = "IDLE            ";
        status_ascii = "IDLE            ";
        error_count = 0;
        #5;

        for (vector_index = 0; vector_index < num_vectors; vector_index = vector_index + 1) begin
            {ALUSel, ALU_a, ALU_b, expected} = vectors[vector_index];
            op_ascii = decode_op(ALUSel);
            result_ascii = "RUN             ";
            status_ascii = "CHECK           ";
            #1;

            if (ALU_Result !== expected) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            ";
                status_ascii = "MISMATCH        ";
                $display("ALU_MISMATCH index=%0d op=%0s sel=0x%0h A=0x%08h B=0x%08h got=0x%08h expected=0x%08h",
                         vector_index, op_ascii, ALUSel, ALU_a, ALU_b, ALU_Result, expected);
            end else begin
                result_ascii = "PASS            ";
                status_ascii = "MATCH           ";
                $display("ALU_MATCH index=%0d op=%0s sel=0x%0h A=0x%08h B=0x%08h result=0x%08h",
                         vector_index, op_ascii, ALUSel, ALU_a, ALU_b, ALU_Result);
            end
            #4;
        end

        $display("=======================================================");
        if (error_count == 0) begin
            status_ascii = "PASS            ";
            $display("ALU_TEST_PASS vectors=%0d", num_vectors);
        end else begin
            status_ascii = "FAIL            ";
            $display("ALU_TEST_FAIL vectors=%0d errors=%0d", num_vectors, error_count);
        end
        $display("=======================================================");
        $finish;
    end
endmodule
