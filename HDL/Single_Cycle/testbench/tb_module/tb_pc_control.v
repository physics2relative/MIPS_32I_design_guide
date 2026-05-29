`timescale 1ns/1ps

module tb_pc_control;
    parameter VECTOR_WIDTH = 5;
    parameter MAX_VECTORS  = 1024;

    reg [VECTOR_WIDTH-1:0] vectors [0:MAX_VECTORS-1];

    reg Branch;
    reg Jump;
    reg BranchTaken;
    wire [1:0] PCSel;

    reg [1:0] expected_pcsel;
    integer num_vectors;
    integer vector_index;
    integer error_count;
    reg [1023:0] vector_file;

    reg [8*16-1:0] case_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*32-1:0] status_ascii;

    pc_control dut (
        .Branch(Branch),
        .Jump(Jump),
        .BranchTaken(BranchTaken),
        .PCSel(PCSel)
    );

    function [8*16-1:0] decode_pcsel;
        input [1:0] sel;
        begin
            case (sel)
                2'b00: decode_pcsel = "PC_PLUS4        ";
                2'b01: decode_pcsel = "PC_BRANCH       ";
                2'b10: decode_pcsel = "PC_JUMP         ";
                default: decode_pcsel = "RESERVED        ";
            endcase
        end
    endfunction

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_pc_control, "ACMTF");

        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) begin
            vector_file = "../../../../../test_vectors/generated/pc_control/vectors.mem";
        end
        if (!$value$plusargs("NUM_VECTORS=%d", num_vectors)) begin
            num_vectors = 8;
        end

        $display("=======================================================");
        $display(" MIPS pc_control golden-vector test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");

        $readmemh(vector_file, vectors);
        Branch = 1'b0;
        Jump = 1'b0;
        BranchTaken = 1'b0;
        expected_pcsel = 2'b00;
        case_ascii = "IDLE            ";
        result_ascii = "IDLE            ";
        status_ascii = "IDLE";
        error_count = 0;
        #5;

        for (vector_index = 0; vector_index < num_vectors; vector_index = vector_index + 1) begin
            {Branch, Jump, BranchTaken, expected_pcsel} = vectors[vector_index];
            case_ascii = decode_pcsel(expected_pcsel);
            result_ascii = "RUN             ";
            status_ascii = {"CHECK ", case_ascii};
            #1;

            if (PCSel !== expected_pcsel) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            ";
                status_ascii = {"MISMATCH ", case_ascii};
                $display("PC_CONTROL_MISMATCH index=%0d Branch=%0b Jump=%0b BranchTaken=%0b got_pcsel=%02b exp_pcsel=%02b",
                         vector_index, Branch, Jump, BranchTaken, PCSel, expected_pcsel);
            end else begin
                result_ascii = "PASS            ";
                status_ascii = {"MATCH ", case_ascii};
                $display("PC_CONTROL_MATCH index=%0d Branch=%0b Jump=%0b BranchTaken=%0b PCSel=%0s",
                         vector_index, Branch, Jump, BranchTaken, decode_pcsel(PCSel));
            end
            #4;
        end

        $display("=======================================================");
        if (error_count == 0) begin
            status_ascii = "PASS";
            $display("PC_CONTROL_TEST_PASS vectors=%0d", num_vectors);
        end else begin
            status_ascii = "FAIL";
            $display("PC_CONTROL_TEST_FAIL vectors=%0d errors=%0d", num_vectors, error_count);
        end
        $display("=======================================================");
        $finish;
    end
endmodule
