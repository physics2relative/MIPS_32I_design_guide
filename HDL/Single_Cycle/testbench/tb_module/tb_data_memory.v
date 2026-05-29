`timescale 1ns/1ps

module tb_data_memory;
    parameter VECTOR_WIDTH = 172;
    parameter MAX_VECTORS  = 1024;
    parameter MEM_AW       = 10;

    reg clk;
    reg [31:0] Addr;
    reg [31:0] Data_rt;
    reg [1:0]  WdLen;
    reg [2:0]  MemRW;
    reg        LoadEx;
    wire [31:0] Data_RD;

    reg [VECTOR_WIDTH-1:0] vectors [0:MAX_VECTORS-1];

    reg [31:0] initial_word;
    reg [1:0]  expected_lane;
    reg [3:0]  expected_we;
    reg [31:0] expected_data_rd;
    reg [31:0] expected_new_word;

    integer num_vectors;
    integer vector_index;
    integer error_count;
    reg [1023:0] vector_file;

    reg [8*16-1:0] op_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*64-1:0] status_ascii;
    reg [31:0] observed_word;

    data_memory #(.MEM_AW(MEM_AW)) dut (
        .clk(clk),
        .Addr(Addr),
        .Data_rt(Data_rt),
        .WdLen(WdLen),
        .MemRW(MemRW),
        .LoadEx(LoadEx),
        .Data_RD(Data_RD)
    );

    always #5 clk = ~clk;

    function [8*16-1:0] decode_memrw;
        input [2:0] op;
        begin
            case (op)
                3'b000: decode_memrw = "SB              ";
                3'b001: decode_memrw = "SH              ";
                3'b010: decode_memrw = "SW              ";
                3'b011: decode_memrw = "LOAD            ";
                3'b100: decode_memrw = "IDLE            ";
                default: decode_memrw = "UNKNOWN         ";
            endcase
        end
    endfunction

    task preload_word;
        input [31:0] addr;
        input [31:0] word;
        reg [MEM_AW-3:0] word_index;
        begin
            word_index = addr[MEM_AW-1:2];
            dut.u_bram.mem[word_index] = word;
        end
    endtask

    function [31:0] peek_word;
        input [31:0] addr;
        reg [MEM_AW-3:0] word_index;
        begin
            word_index = addr[MEM_AW-1:2];
            peek_word = dut.u_bram.mem[word_index];
        end
    endfunction

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_data_memory, "ACMTF");

        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) begin
            vector_file = "../../../../../test_vectors/generated/data_memory/vectors.mem";
        end
        if (!$value$plusargs("NUM_VECTORS=%d", num_vectors)) begin
            num_vectors = 36;
        end

        $display("=======================================================");
        $display(" MIPS data_memory golden-vector test (Verilog)");
        $display("   vector_file = %0s", vector_file);
        $display("   num_vectors = %0d", num_vectors);
        $display("=======================================================");

        $readmemh(vector_file, vectors);

        clk = 1'b0;
        Addr = 32'h0000_0000;
        Data_rt = 32'h0000_0000;
        WdLen = 2'b11;
        MemRW = 3'b100;
        LoadEx = 1'b0;
        expected_lane = 2'b00;
        expected_we = 4'h0;
        expected_data_rd = 32'h0000_0000;
        expected_new_word = 32'h0000_0000;
        observed_word = 32'h0000_0000;
        op_ascii = "IDLE            ";
        result_ascii = "IDLE            ";
        status_ascii = "IDLE";
        error_count = 0;
        #2;

        for (vector_index = 0; vector_index < num_vectors; vector_index = vector_index + 1) begin
            @(negedge clk);
            {initial_word, Addr, Data_rt, WdLen, MemRW, LoadEx, expected_lane,
             expected_we, expected_data_rd, expected_new_word} = vectors[vector_index];
            preload_word(Addr, initial_word);
            op_ascii = decode_memrw(MemRW);
            result_ascii = "RUN             ";
            status_ascii = {"CHECK ", op_ascii};
            #1;

            if (Data_RD !== expected_data_rd) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            ";
                status_ascii = {"RD_MISMATCH ", op_ascii};
                $display("DATA_MEMORY_RD_MISMATCH index=%0d op=%0s Addr=0x%08h WdLen=%02b LoadEx=%0b got=0x%08h expected=0x%08h",
                         vector_index, op_ascii, Addr, WdLen, LoadEx, Data_RD, expected_data_rd);
            end

            @(posedge clk);
            #1;
            observed_word = peek_word(Addr);

            if (observed_word !== expected_new_word) begin
                error_count = error_count + 1;
                result_ascii = "FAIL            ";
                status_ascii = {"MEM_MISMATCH ", op_ascii};
                $display("DATA_MEMORY_WORD_MISMATCH index=%0d op=%0s Addr=0x%08h Data_rt=0x%08h got_word=0x%08h expected_word=0x%08h",
                         vector_index, op_ascii, Addr, Data_rt, observed_word, expected_new_word);
            end

            if ((Data_RD === expected_data_rd) && (observed_word === expected_new_word)) begin
                result_ascii = "PASS            ";
                status_ascii = {"MATCH ", op_ascii};
                $display("DATA_MEMORY_MATCH index=%0d op=%0s Addr=0x%08h WdLen=%02b MemRW=%03b LoadEx=%0b RD=0x%08h word=0x%08h",
                         vector_index, op_ascii, Addr, WdLen, MemRW, LoadEx, Data_RD, observed_word);
            end
        end

        $display("=======================================================");
        if (error_count == 0) begin
            status_ascii = "PASS";
            $display("DATA_MEMORY_TEST_PASS vectors=%0d", num_vectors);
        end else begin
            status_ascii = "FAIL";
            $display("DATA_MEMORY_TEST_FAIL vectors=%0d errors=%0d", num_vectors, error_count);
        end
        $display("=======================================================");
        $finish;
    end
endmodule
