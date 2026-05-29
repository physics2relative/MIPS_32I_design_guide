`timescale 1ns/1ps

// =============================================================
// Pure Verilog testbench for register_file
// -------------------------------------------------------------
// - Consumes Python-generated golden vectors through $readmemh
// - Produces SimVision SHM dump with ACMTF probing
// - Keeps waveform-readable ASCII status/tag/result registers
// - Avoids SystemVerilog-only syntax
// =============================================================

module tb_register_file;
    parameter MAX_VEC = 1024;
    parameter VEC_W   = 121;

    reg clk;
    reg rst;
    reg RegWEn;
    reg [4:0] Addr_Rs;
    reg [4:0] Addr_Rt;
    reg [4:0] Addr_WR;
    reg [31:0] WData;

    wire [31:0] Data_Rs;
    wire [31:0] Data_Rt;

    register_file dut (
        .clk(clk),
        .rst(rst),
        .RegWEn(RegWEn),
        .Addr_Rs(Addr_Rs),
        .Addr_Rt(Addr_Rt),
        .Addr_WR(Addr_WR),
        .WData(WData),
        .Data_Rs(Data_Rs),
        .Data_Rt(Data_Rt)
    );

    reg [VEC_W-1:0] vectors [0:MAX_VEC-1];
    reg [7:0]       tag;
    reg [31:0]      exp_rs;
    reg [31:0]      exp_rt;

    integer num_vectors;
    integer i;
    integer errors;
    integer vector_file_ok;
    integer count_ok;
    reg [1023:0] vector_file;

    // Waveform-friendly debug registers.
    reg [31:0] tb_idx;
    reg [8*16-1:0] tag_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*64-1:0] status_ascii;
    reg [31:0] observed_rs;
    reg [31:0] observed_rt;
    reg        compare_pass;

    always #5 clk = ~clk;

    function [8*16-1:0] tag_name;
        input [7:0] t;
        begin
            case (t)
                8'd0: tag_name = "RESET";
                8'd1: tag_name = "READ";
                8'd2: tag_name = "WRITE";
                8'd3: tag_name = "BYPASS";
                8'd4: tag_name = "ZERO";
                8'd5: tag_name = "RESET_CHECK";
                8'd6: tag_name = "RANDOM";
                default: tag_name = "UNKNOWN";
            endcase
        end
    endfunction

    task set_result;
        input [8*16-1:0] result;
        begin
            result_ascii = result;
        end
    endtask

    task set_status;
        input [8*16-1:0] result;
        input [8*16-1:0] tag_text;
        begin
            // Human-readable enough in waveform: result + tag.
            // Numeric vector fields are kept as separate waveform regs/wires.
            status_ascii = {"RESULT=", result, " TAG=", tag_text};
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        RegWEn = 1'b0;
        Addr_Rs = 5'd0;
        Addr_Rt = 5'd0;
        Addr_WR = 5'd0;
        WData = 32'd0;
        exp_rs = 32'd0;
        exp_rt = 32'd0;
        observed_rs = 32'd0;
        observed_rt = 32'd0;
        compare_pass = 1'b0;
        tb_idx = 32'd0;
        tag = 8'd0;
        tag_ascii = "INIT";
        result_ascii = "INIT";
        status_ascii = "INIT";
        errors = 0;
        num_vectors = 0;
        vector_file = "../../../../../test_vectors/generated/register_file/vectors.mem";

        vector_file_ok = $value$plusargs("VECTOR_FILE=%s", vector_file);
        count_ok = $value$plusargs("NUM_VECTORS=%d", num_vectors);
        if (!count_ok) begin
            $display("ERROR: missing +NUM_VECTORS=<N>");
            $finish;
        end
        if (num_vectors <= 0 || num_vectors > MAX_VEC) begin
            $display("ERROR: invalid NUM_VECTORS=%0d MAX_VEC=%0d", num_vectors, MAX_VEC);
            $finish;
        end

        $shm_open("wave.shm");
        $shm_probe(tb_register_file, "ACMTF");

        $readmemh(vector_file, vectors);

        $display("=======================================================");
        $display(" MIPS register_file golden-vector test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");

        for (i = 0; i < num_vectors; i = i + 1) begin
            @(negedge clk);
            {tag, rst, RegWEn, Addr_Rs, Addr_Rt, Addr_WR, WData, exp_rs, exp_rt} = vectors[i];
            tb_idx = i;
            tag_ascii = tag_name(tag);
            set_result("CHECK");
            set_status("CHECK", tag_ascii);
            #1;

            observed_rs = Data_Rs;
            observed_rt = Data_Rt;
            compare_pass = (Data_Rs === exp_rs) && (Data_Rt === exp_rt);

            if (!compare_pass) begin
                errors = errors + 1;
                set_result("FAIL");
                set_status("FAIL", tag_ascii);
                $display("[FAIL] idx=%0d tag=%0s rst=%0b wen=%0b rs=%0d rt=%0d wr=%0d wd=%08h | rs got=%08h exp=%08h rt got=%08h exp=%08h",
                         i, tag_ascii, rst, RegWEn, Addr_Rs, Addr_Rt, Addr_WR, WData,
                         Data_Rs, exp_rs, Data_Rt, exp_rt);
            end else begin
                set_result("PASS");
                set_status("PASS", tag_ascii);
            end

            @(posedge clk);
            #1;
        end

        $display("=======================================================");
        if (errors == 0) begin
            set_result("ALL_PASS");
            set_status("ALL_PASS", "DONE");
            $display("REGISTER_FILE_TEST_PASS vectors=%0d", num_vectors);
            $display("=======================================================");
            #10;
            $finish;
        end else begin
            set_result("FAIL");
            set_status("FAIL", "DONE");
            $display("REGISTER_FILE_TEST_FAIL errors=%0d vectors=%0d", errors, num_vectors);
            $display("=======================================================");
            #10;
            $finish;
        end
    end

    initial begin
        #1000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
