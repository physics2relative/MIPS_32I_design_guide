`timescale 1ns/1ps

module tb_branch_comparator;
    parameter VECTOR_WIDTH = 66;
    parameter MAX_VECTORS  = 1024;

    reg [VECTOR_WIDTH-1:0] vectors [0:MAX_VECTORS-1];

    reg        BrSel;
    reg [31:0] Data_rs;
    reg [31:0] Data_rt;
    wire       BranchTaken;

    reg        expected_taken;
    integer    num_vectors;
    integer    vector_index;
    integer    error_count;
    reg [1023:0] vector_file;

    // Waveform-readable ASCII state.
    reg [8*16-1:0] brsel_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*16-1:0] status_ascii;

    branch_comparator dut (
        .BrSel       (BrSel),
        .Data_rs     (Data_rs),
        .Data_rt     (Data_rt),
        .BranchTaken (BranchTaken)
    );

    function [8*16-1:0] decode_brsel;
        input sel;
        begin
            case (sel)
                1'b0: decode_brsel = "BR_EQ          ";
                1'b1: decode_brsel = "BR_NE          ";
            endcase
        end
    endfunction

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_branch_comparator, "ACMTF");

        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) begin
            vector_file = "/tmp/mips_branch_comp_1bit_vectors.mem";
        end
        if (!$value$plusargs("NUM_VECTORS=%d", num_vectors)) begin
            num_vectors = 8;
        end

        $display("=======================================================");
        $display(" MIPS branch_comparator 1-bit EQ/NE test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");

        $readmemh(vector_file, vectors);

        BrSel = 1'b0;
        Data_rs = 32'h0000_0000;
        Data_rt = 32'h0000_0000;
        expected_taken = 1'b0;
        brsel_ascii = "IDLE            ";
        result_ascii = "IDLE            ";
        status_ascii = "IDLE            ";
        error_count = 0;
        #5;

        for (vector_index = 0; vector_index < num_vectors; vector_index = vector_index + 1) begin
            {BrSel, Data_rs, Data_rt, expected_taken} = vectors[vector_index];
            brsel_ascii = decode_brsel(BrSel);
            result_ascii = "RUN             ";
            status_ascii = "CHECK           ";
            #1;

            if (BranchTaken !== expected_taken) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            ";
                status_ascii = "MISMATCH        ";
                $display("BRANCH_COMP_MISMATCH index=%0d BrSel=%0s rs=0x%08h rt=0x%08h taken_got=%0b taken_exp=%0b",
                         vector_index, brsel_ascii, Data_rs, Data_rt, BranchTaken, expected_taken);
            end else begin
                result_ascii = "PASS            ";
                status_ascii = "MATCH           ";
                $display("BRANCH_COMP_MATCH index=%0d BrSel=%0s rs=0x%08h rt=0x%08h taken=%0b",
                         vector_index, brsel_ascii, Data_rs, Data_rt, BranchTaken);
            end
            #4;
        end

        $display("=======================================================");
        if (error_count == 0) begin
            status_ascii = "PASS            ";
            $display("BRANCH_COMP_1BIT_TEST_PASS vectors=%0d", num_vectors);
        end else begin
            status_ascii = "FAIL            ";
            $display("BRANCH_COMP_1BIT_TEST_FAIL vectors=%0d errors=%0d", num_vectors, error_count);
        end
        $display("=======================================================");
        $finish;
    end
endmodule
