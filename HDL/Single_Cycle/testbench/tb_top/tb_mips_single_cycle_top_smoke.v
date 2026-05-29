`timescale 1ns/1ps

// =============================================================
// Pure Verilog top smoke testbench for mips_single_cycle_top
// -------------------------------------------------------------
// - Loads a Python-generated instruction program into instruction memory
// - Runs a bounded number of single-cycle clocks after reset release
// - Checks Python-generated golden register/data-memory end state
// - Produces SimVision SHM dump with ACMTF probing
// - Keeps waveform-readable ASCII phase/instruction/result/status signals
// =============================================================

module tb_mips_single_cycle_top_smoke;
    parameter MAX_CHECKS = 128;
    parameter CHECK_W = 44;

    localparam [3:0] KIND_REG      = 4'd1;
    localparam [3:0] KIND_MEM_WORD = 4'd2;

    reg clk;
    reg rst;

    wire [31:0] dbg_pc;
    wire [31:0] dbg_next_pc;
    wire [31:0] dbg_pc_plus4;
    wire [31:0] dbg_inst;
    wire [31:0] dbg_data_rs;
    wire [31:0] dbg_data_rt;
    wire [31:0] dbg_imm_val;
    wire [31:0] dbg_branch_off;
    wire [31:0] dbg_alu_a;
    wire [31:0] dbg_alu_b;
    wire [31:0] dbg_alu_result;
    wire [31:0] dbg_data_rd;
    wire [31:0] dbg_wdata;
    wire [31:0] dbg_jump_imm_target;
    wire [31:0] dbg_selected_jump_target;
    wire [4:0]  dbg_addr_rs;
    wire [4:0]  dbg_addr_rt;
    wire [4:0]  dbg_addr_rd;
    wire [4:0]  dbg_write_reg;
    wire        dbg_reg_wen;
    wire        dbg_branch;
    wire        dbg_jump;
    wire        dbg_branch_taken;
    wire [1:0]  dbg_pcsel;

    mips_single_cycle_top dut (
        .clk(clk),
        .rst(rst),
        .dbg_pc(dbg_pc),
        .dbg_next_pc(dbg_next_pc),
        .dbg_pc_plus4(dbg_pc_plus4),
        .dbg_inst(dbg_inst),
        .dbg_data_rs(dbg_data_rs),
        .dbg_data_rt(dbg_data_rt),
        .dbg_imm_val(dbg_imm_val),
        .dbg_branch_off(dbg_branch_off),
        .dbg_alu_a(dbg_alu_a),
        .dbg_alu_b(dbg_alu_b),
        .dbg_alu_result(dbg_alu_result),
        .dbg_data_rd(dbg_data_rd),
        .dbg_wdata(dbg_wdata),
        .dbg_jump_imm_target(dbg_jump_imm_target),
        .dbg_selected_jump_target(dbg_selected_jump_target),
        .dbg_addr_rs(dbg_addr_rs),
        .dbg_addr_rt(dbg_addr_rt),
        .dbg_addr_rd(dbg_addr_rd),
        .dbg_write_reg(dbg_write_reg),
        .dbg_reg_wen(dbg_reg_wen),
        .dbg_branch(dbg_branch),
        .dbg_jump(dbg_jump),
        .dbg_branch_taken(dbg_branch_taken),
        .dbg_pcsel(dbg_pcsel)
    );

    reg [CHECK_W-1:0] checks [0:MAX_CHECKS-1];

    integer run_cycles;
    integer num_checks;
    integer cycle_idx;
    integer check_idx;
    integer errors;
    integer plusarg_ok;
    integer trace_en;
    reg [1023:0] program_file;
    reg [1023:0] checks_file;

    reg [3:0]  chk_kind;
    reg [7:0]  chk_index;
    reg [31:0] chk_expected;
    reg [31:0] chk_observed;
    reg        compare_pass;

    // Waveform-friendly debug/status registers.
    reg [31:0] tb_cycle;
    reg [31:0] tb_pc;
    reg [31:0] tb_inst;
    reg [8*16-1:0] phase_ascii;
    reg [8*16-1:0] instr_ascii;
    reg [8*16-1:0] result_ascii;
    reg [8*80-1:0] status_ascii;

    always #5 clk = ~clk;

    function [8*16-1:0] inst_name;
        input [31:0] inst;
        reg [5:0] opcode;
        reg [5:0] funct;
        begin
            opcode = inst[31:26];
            funct  = inst[5:0];
            case (opcode)
                6'h00: begin
                    case (funct)
                        6'h00: inst_name = "SLL/NOP";
                        6'h02: inst_name = "SRL";
                        6'h03: inst_name = "SRA";
                        6'h08: inst_name = "JR";
                        6'h09: inst_name = "JALR";
                        6'h20: inst_name = "ADD";
                        6'h21: inst_name = "ADDU";
                        6'h22: inst_name = "SUB";
                        6'h23: inst_name = "SUBU";
                        6'h24: inst_name = "AND";
                        6'h25: inst_name = "OR";
                        6'h26: inst_name = "XOR";
                        6'h27: inst_name = "NOR";
                        6'h2A: inst_name = "SLT";
                        6'h2B: inst_name = "SLTU";
                        default: inst_name = "R-UNKNOWN";
                    endcase
                end
                6'h02: inst_name = "J";
                6'h03: inst_name = "JAL";
                6'h04: inst_name = "BEQ";
                6'h05: inst_name = "BNE";
                6'h08: inst_name = "ADDI";
                6'h09: inst_name = "ADDIU";
                6'h0C: inst_name = "ANDI";
                6'h0D: inst_name = "ORI";
                6'h0E: inst_name = "XORI";
                6'h0F: inst_name = "LUI";
                6'h20: inst_name = "LB";
                6'h21: inst_name = "LH";
                6'h23: inst_name = "LW";
                6'h24: inst_name = "LBU";
                6'h25: inst_name = "LHU";
                6'h28: inst_name = "SB";
                6'h29: inst_name = "SH";
                6'h2B: inst_name = "SW";
                default: inst_name = "UNKNOWN";
            endcase
        end
    endfunction

    function [31:0] read_reg;
        input [7:0] index;
        begin
            if (index[4:0] == 5'd0) begin
                read_reg = 32'h0000_0000;
            end else begin
                read_reg = dut.u_regfile.regs[index[4:0]];
            end
        end
    endfunction

    function [31:0] read_dmem_word;
        input [7:0] word_index;
        begin
            read_dmem_word = dut.u_dmem.u_bram.mem[word_index];
        end
    endfunction

    task set_status;
        input [8*16-1:0] phase;
        input [8*16-1:0] result;
        begin
            phase_ascii = phase;
            result_ascii = result;
            status_ascii = {"PHASE=", phase, " RESULT=", result, " INST=", instr_ascii};
        end
    endtask

    task run_one_check;
        input integer idx;
        begin
            {chk_kind, chk_index, chk_expected} = checks[idx];
            case (chk_kind)
                KIND_REG: begin
                    chk_observed = read_reg(chk_index);
                end
                KIND_MEM_WORD: begin
                    chk_observed = read_dmem_word(chk_index);
                end
                default: begin
                    chk_observed = 32'hDEAD_BAAD;
                end
            endcase

            compare_pass = (chk_kind == KIND_REG || chk_kind == KIND_MEM_WORD) && (chk_observed === chk_expected);
            if (!compare_pass) begin
                errors = errors + 1;
                set_status("CHECK", "FAIL");
                $display("[FAIL] check=%0d kind=%0d index=%0d observed=%08h expected=%08h",
                         idx, chk_kind, chk_index, chk_observed, chk_expected);
            end else if (trace_en != 0) begin
                $display("[PASS] check=%0d kind=%0d index=%0d observed=%08h",
                         idx, chk_kind, chk_index, chk_observed);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        run_cycles = 0;
        num_checks = 0;
        errors = 0;
        trace_en = 0;
        tb_cycle = 32'd0;
        tb_pc = 32'd0;
        tb_inst = 32'd0;
        instr_ascii = "INIT";
        phase_ascii = "INIT";
        result_ascii = "INIT";
        status_ascii = "INIT";
        chk_kind = 4'd0;
        chk_index = 8'd0;
        chk_expected = 32'd0;
        chk_observed = 32'd0;
        compare_pass = 1'b0;
        program_file = "../../../../../test_vectors/generated/top_smoke/program.hex";
        checks_file = "../../../../../test_vectors/generated/top_smoke/checks.mem";

        plusarg_ok = $value$plusargs("PROGRAM_FILE=%s", program_file);
        plusarg_ok = $value$plusargs("CHECK_FILE=%s", checks_file);
        plusarg_ok = $value$plusargs("RUN_CYCLES=%d", run_cycles);
        plusarg_ok = $value$plusargs("NUM_CHECKS=%d", num_checks);
        plusarg_ok = $value$plusargs("TRACE=%d", trace_en);

        if (run_cycles <= 0) begin
            $display("ERROR: missing/invalid +RUN_CYCLES=<N>");
            $finish;
        end
        if (num_checks <= 0 || num_checks > MAX_CHECKS) begin
            $display("ERROR: invalid +NUM_CHECKS=%0d MAX_CHECKS=%0d", num_checks, MAX_CHECKS);
            $finish;
        end

        $shm_open("wave.shm");
        $shm_probe(tb_mips_single_cycle_top_smoke, "ACMTF");

        #1;
        $readmemh(program_file, dut.u_imem.u_bram.mem);
        $readmemh(checks_file, checks);

        $display("=======================================================");
        $display(" MIPS single-cycle top smoke test");
        $display("   program_file = %0s", program_file);
        $display("   checks_file  = %0s", checks_file);
        $display("   run_cycles   = %0d", run_cycles);
        $display("   num_checks   = %0d", num_checks);
        $display("=======================================================");

        set_status("RESET", "RUN");
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        set_status("RUN", "RUN");
        for (cycle_idx = 0; cycle_idx < run_cycles; cycle_idx = cycle_idx + 1) begin
            #1;
            tb_cycle = cycle_idx;
            tb_pc = dbg_pc;
            tb_inst = dbg_inst;
            instr_ascii = inst_name(dbg_inst);
            set_status("RUN", "RUN");
            if (trace_en != 0) begin
                $display("[TRACE] cycle=%0d pc=%08h inst=%08h name=%0s next=%08h regwen=%0b wr=%0d wdata=%08h pcsel=%0d",
                         cycle_idx, dbg_pc, dbg_inst, instr_ascii, dbg_next_pc,
                         dbg_reg_wen, dbg_write_reg, dbg_wdata, dbg_pcsel);
            end
            @(posedge clk);
        end
        #1;

        set_status("CHECK", "RUN");
        for (check_idx = 0; check_idx < num_checks; check_idx = check_idx + 1) begin
            run_one_check(check_idx);
        end

        $display("=======================================================");
        if (errors == 0) begin
            set_status("DONE", "ALL_PASS");
            $display("MIPS_SINGLE_CYCLE_TOP_SMOKE_PASS checks=%0d cycles=%0d", num_checks, run_cycles);
        end else begin
            set_status("DONE", "FAIL");
            $display("MIPS_SINGLE_CYCLE_TOP_SMOKE_FAIL errors=%0d checks=%0d cycles=%0d", errors, num_checks, run_cycles);
        end
        $display("=======================================================");
        #10;
        $finish;
    end

    initial begin
        #1000000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
