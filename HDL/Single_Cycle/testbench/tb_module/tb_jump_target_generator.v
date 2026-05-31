`timescale 1ns/1ps

module tb_jump_target_generator;
    parameter VECTOR_WIDTH = 90;
    parameter MAX_VECTORS  = 1024;

    reg [VECTOR_WIDTH-1:0] vectors [0:MAX_VECTORS-1];

    reg  [31:0] PCPlus4;
    reg  [25:0] target26;
    wire [31:0] JumpImmTarget;

    reg [31:0] expected_jump_imm;
    integer num_vectors;
    integer vector_index;
    integer error_count;
    reg [1023:0] vector_file;

    reg [8*16-1:0] result_ascii;
    reg [8*32-1:0] status_ascii;

    jump_target_generator dut (
        .PCPlus4(PCPlus4),
        .target26(target26),
        .JumpImmTarget(JumpImmTarget)
    );

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_jump_target_generator, "ACMTF");
        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) vector_file = "../../../../../test_vectors/generated/jump_target/vectors.mem";
        if (!$value$plusargs("NUM_VECTORS=%d", num_vectors)) num_vectors = 4;
        $display("=======================================================");
        $display(" MIPS jump_target_generator golden-vector test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");
        $readmemh(vector_file, vectors);
        PCPlus4 = 32'h0; target26 = 26'h0; expected_jump_imm = 32'h0;
        result_ascii = "IDLE            "; status_ascii = "IDLE"; error_count = 0;
        #5;
        for (vector_index = 0; vector_index < num_vectors; vector_index = vector_index + 1) begin
            {PCPlus4, target26, expected_jump_imm} = vectors[vector_index];
            result_ascii = "RUN             "; status_ascii = "CHECK JTARGET";
            #1;
            if (JumpImmTarget !== expected_jump_imm) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            "; status_ascii = "MISMATCH JTARGET";
                $display("JUMP_TARGET_MISMATCH index=%0d PCPlus4=0x%08h target26=0x%07h", vector_index, PCPlus4, target26);
                $display("  got: JumpImmTarget=0x%08h", JumpImmTarget);
                $display("  exp: JumpImmTarget=0x%08h", expected_jump_imm);
            end else begin
                result_ascii = "PASS            "; status_ascii = "MATCH JTARGET";
                $display("JUMP_TARGET_MATCH index=%0d PCPlus4=0x%08h target26=0x%07h JumpImmTarget=0x%08h", vector_index, PCPlus4, target26, JumpImmTarget);
            end
            #4;
        end
        $display("=======================================================");
        if (error_count == 0) begin status_ascii = "PASS"; $display("JUMP_TARGET_GENERATOR_TEST_PASS vectors=%0d", num_vectors); end
        else begin status_ascii = "FAIL"; $display("JUMP_TARGET_GENERATOR_TEST_FAIL vectors=%0d errors=%0d", num_vectors, error_count); end
        $display("=======================================================");
        $finish;
    end
endmodule
