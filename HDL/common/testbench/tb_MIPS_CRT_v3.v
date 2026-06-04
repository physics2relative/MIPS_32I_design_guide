`timescale 1ns/1ps

// =============================================================
// tb_MIPS_CRT_v3 -- MIPS constrained-random torture test
// -------------------------------------------------------------
// Common CRT testbench for the current Single Cycle DUT and the future
// Pipeline DUT adapter contract.  The generator is intentionally ordinary
// Verilog and uses $random(seed) instead of an external Python generator.
//
// Verification model:
//   - Write the same generated program/data image into DUT and MIPS_Golden.
//   - Run until the golden model reaches the project halt convention
//     (`j self`).
//   - Let the DUT settle/drain, then compare architectural registers and
//     the bounded data-memory byte window.
//
// Safety profile from mips-crt-v3-ralplan.md:
//   - no pipeline RTL changes in this pass
//   - no DUT memory/timing redesign
//   - default random program avoids same-instruction write/read alias cases
//     that create combinational feedback in the current single-cycle RF
//     bypass topology
// =============================================================

`ifndef MIPS_CRT_DUT_PIPELINE
`ifndef MIPS_CRT_DUT_SINGLE
`define MIPS_CRT_DUT_SINGLE
`endif
`endif

module tb_MIPS_CRT_v3 #(
    parameter SEED             = 32'd1,
    parameter N_INST           = 120,
    parameter M_ITER           = 20,
    parameter REG_POOL         = 8,
    parameter PHASE_START      = 1,
    parameter PHASE_END        = 3,
    parameter IMEM_WORDS            = 512,
    parameter DMEM_BYTES            = 256,
    parameter DUT_DRAIN_CYCLES      = 4,
    parameter MAX_WAIT_CYCLES       = 200000,
    parameter GLOBAL_TIMEOUT_CYCLES = 0
)();
    reg clk;
    reg rst;

`ifdef MIPS_CRT_DUT_SINGLE
    // ---------------------------------------------------------
    // DUT: current Single Cycle implementation
    // ---------------------------------------------------------
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

    mips_single_cycle_top #(
        .IMEM_AW(9),
        .DMEM_AW(10),
        .IMEM_INIT_FILE("")
    ) uut (
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
`else
    // ---------------------------------------------------------
    // DUT: 5-stage Pipeline implementation
    // ---------------------------------------------------------
    // The CRT body is shared with Single Cycle.  The adapter switches
    // architectural-state access and halt detection to the WB retire contract.
    wire        p_dbg_wb_valid;
    wire [31:0] p_dbg_wb_pc;
    wire [31:0] p_dbg_wb_inst;
    wire        p_dbg_wb_reg_wen;
    wire [4:0]  p_dbg_wb_write_reg;
    wire [31:0] p_dbg_wb_wdata;
    wire [31:0] p_dbg_if_pc;
    wire [31:0] p_dbg_id_inst;
    wire [31:0] p_dbg_ex_alu_result;
    wire [31:0] p_dbg_next_pc;

    mips_pipeline_top #(
        .IMEM_AW(12),
        .DMEM_AW(10),
        .IMEM_INIT_FILE("")
    ) uut (
        .clk(clk),
        .rst(rst),
        .dbg_wb_valid(p_dbg_wb_valid),
        .dbg_wb_pc(p_dbg_wb_pc),
        .dbg_wb_inst(p_dbg_wb_inst),
        .dbg_wb_reg_wen(p_dbg_wb_reg_wen),
        .dbg_wb_write_reg(p_dbg_wb_write_reg),
        .dbg_wb_wdata(p_dbg_wb_wdata),
        .dbg_if_pc(p_dbg_if_pc),
        .dbg_id_inst(p_dbg_id_inst),
        .dbg_ex_alu_result(p_dbg_ex_alu_result),
        .dbg_next_pc(p_dbg_next_pc)
    );
`endif

`include "mips_crt_adapter.vh"

    // ---------------------------------------------------------
    // Golden Model
    // ---------------------------------------------------------
    wire [31:0] g_pc;
    wire        g_done;
    wire        g_fault;
    wire [31:0] g_inst;
    wire [31:0] g_result;
    wire [4:0]  g_rd;
    wire        g_wen;
    wire [8*12-1:0] g_inst_name;
    wire [8*32-1:0] g_status;

    MIPS_Golden #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_BYTES(DMEM_BYTES),
        .PC_RESET(32'h0000_0000),
        .MAX_CYCLES(MAX_WAIT_CYCLES)
    ) golden (
        .clk(clk),
        .rst(rst),
        .pc(g_pc),
        .done(g_done),
        .fault(g_fault),
        .inst(g_inst),
        .result(g_result),
        .rd_out(g_rd),
        .wen_out(g_wen),
        .inst_name(g_inst_name),
        .status(g_status)
    );

    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // MIPS opcodes/funct values
    // ---------------------------------------------------------
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
    localparam [5:0] FN_ABS   = 6'b101100;

    // ---------------------------------------------------------
    // Instruction encoding helpers
    // ---------------------------------------------------------
    function [31:0] enc_r;
        input [4:0] rs;
        input [4:0] rt;
        input [4:0] rd;
        input [4:0] shamt;
        input [5:0] funct;
        begin
            enc_r = {OP_RTYPE, rs, rt, rd, shamt, funct};
        end
    endfunction

    function [31:0] enc_i;
        input [5:0] opcode;
        input [4:0] rs;
        input [4:0] rt;
        input [15:0] imm16;
        begin
            enc_i = {opcode, rs, rt, imm16};
        end
    endfunction

    function [31:0] enc_j;
        input [5:0] opcode;
        input [25:0] target26;
        begin
            enc_j = {opcode, target26};
        end
    endfunction

    function [8*12-1:0] iname;
        input [31:0] insn;
        reg [5:0] op;
        reg [5:0] fn;
        begin
            op = insn[31:26];
            fn = insn[5:0];
            iname = "UNKNOWN     ";
            case (op)
                OP_RTYPE: begin
                    case (fn)
                        FN_SLL:  iname = "SLL         ";
                        FN_SRL:  iname = "SRL         ";
                        FN_SRA:  iname = "SRA         ";
                        FN_SLLV: iname = "SLLV        ";
                        FN_SRLV: iname = "SRLV        ";
                        FN_SRAV: iname = "SRAV        ";
                        FN_JR:   iname = "JR          ";
                        FN_JALR: iname = "JALR        ";
                        FN_ADD:  iname = "ADD         ";
                        FN_ADDU: iname = "ADDU        ";
                        FN_SUB:  iname = "SUB         ";
                        FN_SUBU: iname = "SUBU        ";
                        FN_AND:  iname = "AND         ";
                        FN_OR:   iname = "OR          ";
                        FN_XOR:  iname = "XOR         ";
                        FN_NOR:  iname = "NOR         ";
                        FN_SLT:  iname = "SLT         ";
                        FN_SLTU: iname = "SLTU        ";
                        FN_ABS:  iname = "ABS         ";
                    endcase
                end
                OP_J:     iname = "J           ";
                OP_JAL:   iname = "JAL         ";
                OP_BEQ:   iname = "BEQ         ";
                OP_BNE:   iname = "BNE         ";
                OP_ADDI:  iname = "ADDI        ";
                OP_ADDIU: iname = "ADDIU       ";
                OP_SLTI:  iname = "SLTI        ";
                OP_SLTIU: iname = "SLTIU       ";
                OP_ANDI:  iname = "ANDI        ";
                OP_ORI:   iname = "ORI         ";
                OP_XORI:  iname = "XORI        ";
                OP_LUI:   iname = "LUI         ";
                OP_LB:    iname = "LB          ";
                OP_LH:    iname = "LH          ";
                OP_LW:    iname = "LW          ";
                OP_LBU:   iname = "LBU         ";
                OP_LHU:   iname = "LHU         ";
                OP_SB:    iname = "SB          ";
                OP_SH:    iname = "SH          ";
                OP_SW:    iname = "SW          ";
            endcase
        end
    endfunction

    wire [8*12-1:0] dut_inst_name;
    assign dut_inst_name = iname(`MIPS_CRT_DUT_INST);

    // ---------------------------------------------------------
    // Random helper functions.  $random(seed_state) keeps generation fully
    // reproducible with +define+SEED or xrun -defparam tb.SEED=...
    // ---------------------------------------------------------
    integer seed_state;

    function [31:0] rand32;
        input integer dummy;
        begin
            rand32 = $random(seed_state);
        end
    endfunction

    function integer rand_mod;
        input integer limit;
        reg [31:0] r;
        begin
            r = $random(seed_state);
            if (limit <= 1) begin
                rand_mod = 0;
            end else begin
                if (r[31]) begin
                    r = (~r) + 32'd1;
                end
                rand_mod = r % limit;
            end
        end
    endfunction

    function [4:0] pick_reg;
        input integer dummy;
        begin
            pick_reg = 5'd1 + rand_mod(REG_POOL);
        end
    endfunction

    function [4:0] pick_reg_except1;
        input [4:0] ex1;
        reg [4:0] r;
        integer guard;
        begin
            r = pick_reg(0);
            guard = 0;
            while ((r == ex1) && (guard < 64)) begin
                r = pick_reg(0);
                guard = guard + 1;
            end
            if (r == ex1) begin
                r = (ex1 == 5'd1) ? 5'd2 : 5'd1;
            end
            pick_reg_except1 = r;
        end
    endfunction

    function [4:0] pick_reg_except2;
        input [4:0] ex1;
        input [4:0] ex2;
        reg [4:0] r;
        integer guard;
        begin
            r = pick_reg(0);
            guard = 0;
            while (((r == ex1) || (r == ex2)) && (guard < 64)) begin
                r = pick_reg(0);
                guard = guard + 1;
            end
            if ((r == ex1) || (r == ex2)) begin
                r = 5'd1;
                while ((r == ex1) || (r == ex2)) begin
                    r = r + 5'd1;
                end
            end
            pick_reg_except2 = r;
        end
    endfunction

    function [15:0] small_signed_imm;
        input integer dummy;
        reg [31:0] r;
        begin
            r = rand32(0);
            small_signed_imm = r[15:0];
        end
    endfunction

    // ---------------------------------------------------------
    // Testbench state / waveform-readable ASCII status
    // ---------------------------------------------------------
    integer g_ptr;
    integer halt_index;
    reg [31:0] halt_pc;
    integer total_pass;
    integer total_fail;
    integer phase;
    integer iter;
    integer gi;
    integer gen_error;
    integer last_emit_index;
    reg [31:0] last_emit_inst;
    reg [8*32-1:0] ascii_state;
    reg [8*24-1:0] ascii_phase;
    reg [8*24-1:0] ascii_iter_state;
    reg [8*12-1:0] ascii_last_emit_name;
    reg [8*12-1:0] ascii_dut_inst_name;
    reg [8*12-1:0] ascii_golden_inst_name;

    always @(*) begin
        ascii_dut_inst_name    = dut_inst_name;
        ascii_golden_inst_name = g_inst_name;
    end

    // ---------------------------------------------------------
    // Memory/image helpers
    // ---------------------------------------------------------
    task write_imem_word;
        input integer idx;
        input [31:0] value;
        begin
            if ((idx >= 0) && (idx < IMEM_WORDS)) begin
                `MIPS_CRT_DUT_WRITE_IMEM(idx, value);
                golden.imem[idx] = value;
            end else begin
                gen_error = 1;
                $display("MIPS_CRT_GEN_ERROR: IMEM index out of range idx=%0d", idx);
            end
        end
    endtask

    task emit_inst;
        input [31:0] inst;
        begin
            write_imem_word(g_ptr, inst);
            last_emit_index = g_ptr;
            last_emit_inst  = inst;
            ascii_last_emit_name = iname(inst);
            g_ptr = g_ptr + 1;
        end
    endtask

    task emit_nop;
        begin
            emit_inst(32'h0000_0000); // sll $0,$0,0
        end
    endtask

    task emit_nops;
        input integer count;
        integer n;
        begin
            for (n = 0; n < count; n = n + 1) begin
                emit_nop;
            end
        end
    endtask

    task emit_halt;
        begin
            halt_index = g_ptr;
            halt_pc    = g_ptr[31:0] << 2;
            write_imem_word(g_ptr, enc_j(OP_J, g_ptr[25:0]));
            last_emit_index = g_ptr;
            last_emit_inst  = enc_j(OP_J, g_ptr[25:0]);
            ascii_last_emit_name = "HALT_JSELF  ";
        end
    endtask

    task prepare_memories;
        integer i;
        begin
            ascii_state = "prepare memories                ";
            gen_error = 0;
            g_ptr = 0;
            halt_index = 0;
            halt_pc = 32'h0000_0000;
            last_emit_index = -1;
            last_emit_inst = 32'h0000_0000;
            ascii_last_emit_name = "NONE        ";

            for (i = 0; i < IMEM_WORDS; i = i + 1) begin
                `MIPS_CRT_DUT_CLEAR_IMEM_WORD(i);
                golden.imem[i] = 32'h0000_0000;
            end
            for (i = 0; i < (DMEM_BYTES / 4); i = i + 1) begin
                `MIPS_CRT_DUT_CLEAR_DMEM_WORD(i);
            end
            for (i = 0; i < DMEM_BYTES; i = i + 1) begin
                golden.dmem[i] = 8'h00;
            end

            // Deterministic non-zero data image for load tests before stores.
            for (i = 0; i < DMEM_BYTES; i = i + 1) begin
                golden.dmem[i] = (i[7:0] ^ 8'ha5);
            end
            for (i = 0; i < (DMEM_BYTES / 4); i = i + 1) begin
                `MIPS_CRT_DUT_WRITE_DMEM_WORD(i,
                    {golden.dmem[(i << 2) + 3], golden.dmem[(i << 2) + 2],
                     golden.dmem[(i << 2) + 1], golden.dmem[(i << 2) + 0]});
            end
        end
    endtask

    // ---------------------------------------------------------
    // Directed prelude: every implemented ISA class appears at least once.
    // ---------------------------------------------------------
    task emit_directed_prelude;
        integer j_target;
        integer skip;
        begin
            ascii_state = "emit directed prelude           ";

            // Register seeding through safe I-type writes (rt != rs).
            emit_inst(enc_i(OP_ADDIU, 5'd0, 5'd1,  16'd5));
            emit_inst(enc_i(OP_ADDIU, 5'd0, 5'd2,  16'd7));
            emit_inst(enc_i(OP_ADDIU, 5'd0, 5'd3,  16'hfffb)); // -5
            emit_inst(enc_i(OP_ORI,   5'd0, 5'd4,  16'ha5a5));
            emit_inst(enc_i(OP_LUI,   5'd0, 5'd5,  16'h1234));
            emit_inst(enc_i(OP_XORI,  5'd4, 5'd6,  16'h00ff));
            emit_inst(enc_i(OP_ANDI,  5'd4, 5'd7,  16'h0f0f));
            emit_inst(enc_i(OP_ADDI,  5'd1, 5'd8,  16'd12));

            // R-type ALU and shifts.  rd is kept distinct from active reads.
            emit_inst(enc_r(5'd1, 5'd2, 5'd9,  5'd0, FN_ADD));
            emit_inst(enc_r(5'd2, 5'd1, 5'd10, 5'd0, FN_ADDU));
            emit_inst(enc_r(5'd2, 5'd1, 5'd11, 5'd0, FN_SUB));
            emit_inst(enc_r(5'd1, 5'd2, 5'd12, 5'd0, FN_SUBU));
            emit_inst(enc_r(5'd4, 5'd6, 5'd13, 5'd0, FN_AND));
            emit_inst(enc_r(5'd4, 5'd7, 5'd14, 5'd0, FN_OR));
            emit_inst(enc_r(5'd4, 5'd6, 5'd15, 5'd0, FN_XOR));
            emit_inst(enc_r(5'd4, 5'd6, 5'd16, 5'd0, FN_NOR));
            emit_inst(enc_r(5'd3, 5'd1, 5'd17, 5'd0, FN_SLT));
            emit_inst(enc_r(5'd1, 5'd3, 5'd18, 5'd0, FN_SLTU));
            emit_inst(enc_r(5'd0, 5'd2, 5'd19, 5'd3, FN_SLL));
            emit_inst(enc_r(5'd0, 5'd5, 5'd20, 5'd4, FN_SRL));
            emit_inst(enc_r(5'd0, 5'd3, 5'd21, 5'd1, FN_SRA));
            emit_inst(enc_r(5'd1, 5'd2, 5'd22, 5'd0, FN_SLLV));
            emit_inst(enc_r(5'd1, 5'd5, 5'd23, 5'd0, FN_SRLV));
            emit_inst(enc_r(5'd1, 5'd3, 5'd24, 5'd0, FN_SRAV));

            // I-type comparison/immediate operations.
            emit_inst(enc_i(OP_SLTI,  5'd3, 5'd25, 16'd1));
            emit_inst(enc_i(OP_SLTIU, 5'd1, 5'd26, 16'hffff));

            // Memory width/sign-extension coverage with $zero base.
            emit_inst(enc_i(OP_SW, 5'd0, 5'd4, 16'd0));
            emit_inst(enc_i(OP_LW, 5'd0, 5'd27, 16'd0));
            emit_inst(enc_i(OP_SH, 5'd0, 5'd3, 16'd4));
            emit_inst(enc_i(OP_LH, 5'd0, 5'd28, 16'd4));
            emit_inst(enc_i(OP_LHU,5'd0, 5'd29, 16'd4));
            emit_inst(enc_i(OP_SB, 5'd0, 5'd3, 16'd8));
            emit_inst(enc_i(OP_LB, 5'd0, 5'd30, 16'd8));
            emit_inst(enc_i(OP_LBU,5'd0, 5'd31, 16'd8));

            // Branches skip NOPs only, so taken/not-taken is state-safe.
            emit_inst(enc_i(OP_BEQ, 5'd1, 5'd1, 16'd1));
            emit_inst(enc_i(OP_ADDIU, 5'd0, 5'd30, 16'h1111)); // skipped
            emit_inst(enc_i(OP_BNE, 5'd1, 5'd2, 16'd1));
            emit_inst(enc_i(OP_ADDIU, 5'd0, 5'd29, 16'h2222)); // skipped

            // J / JAL / JR / JALR forward over NOPs.
            skip = 1;
            j_target = g_ptr + 1 + skip;
            emit_inst(enc_j(OP_J, j_target[25:0]));
            emit_nops(skip);

            skip = 1;
            j_target = g_ptr + 1 + skip;
            emit_inst(enc_j(OP_JAL, j_target[25:0]));
            emit_nops(skip);

            skip = 1;
            j_target = g_ptr + 2 + skip;
            emit_inst(enc_i(OP_ADDIU, 5'd0, 5'd9, (j_target << 2) & 16'hffff));
            emit_inst(enc_r(5'd9, 5'd0, 5'd0, 5'd0, FN_JR));
            emit_nops(skip);

            skip = 1;
            j_target = g_ptr + 2 + skip;
            emit_inst(enc_i(OP_ADDIU, 5'd0, 5'd10, (j_target << 2) & 16'hffff));
            emit_inst(enc_r(5'd10, 5'd0, 5'd30, 5'd0, FN_JALR));
            emit_nops(skip);
        end
    endtask

    // ---------------------------------------------------------
    // Constrained random instruction generation.
    // ---------------------------------------------------------
    task emit_random_one;
        input integer cur_phase;
        integer max_type;
        integer rand_type;
        integer op_pick;
        integer skip;
        integer target_idx;
        integer byte_addr;
        reg [4:0] rs;
        reg [4:0] rt;
        reg [4:0] rd;
        reg [4:0] shamt;
        reg [5:0] funct;
        reg [5:0] opcode;
        reg [31:0] rand_tmp;
        begin
            max_type = (cur_phase <= 1) ? 5 : ((cur_phase == 2) ? 6 : 7);
            rand_type = rand_mod(max_type + 1);

            case (rand_type)
                0: begin // R-type ALU, rd != rs/rt
                    rs = pick_reg(0);
                    rt = pick_reg(0);
                    rd = pick_reg_except2(rs, rt);
                    op_pick = rand_mod(11);
                    case (op_pick)
                        0: funct = FN_ADD;
                        1: funct = FN_ADDU;
                        2: funct = FN_SUB;
                        3: funct = FN_SUBU;
                        4: funct = FN_AND;
                        5: funct = FN_OR;
                        6: funct = FN_XOR;
                        7: funct = FN_NOR;
                        8: funct = FN_SLT;
                        9: funct = FN_SLTU;
                        default: begin funct = FN_ABS; rt = 5'd0; end
                    endcase
                    emit_inst(enc_r(rs, rt, rd, 5'd0, funct));
                end

                1: begin // Shift immediate, rd != rt.  rs is kept zero.
                    rt = pick_reg(0);
                    rd = pick_reg_except1(rt);
                    shamt = rand_mod(32);
                    op_pick = rand_mod(3);
                    case (op_pick)
                        0: funct = FN_SLL;
                        1: funct = FN_SRL;
                        default: funct = FN_SRA;
                    endcase
                    emit_inst(enc_r(5'd0, rt, rd, shamt, funct));
                end

                2: begin // Variable shift, rd != rs/rt
                    rs = pick_reg(0);
                    rt = pick_reg(0);
                    rd = pick_reg_except2(rs, rt);
                    op_pick = rand_mod(3);
                    case (op_pick)
                        0: funct = FN_SLLV;
                        1: funct = FN_SRLV;
                        default: funct = FN_SRAV;
                    endcase
                    emit_inst(enc_r(rs, rt, rd, 5'd0, funct));
                end

                3: begin // I-type ALU, rt != rs where rs is used.
                    op_pick = rand_mod(8);
                    if (op_pick == 7) begin
                        rt = pick_reg(0);
                        rand_tmp = rand32(0);
                        emit_inst(enc_i(OP_LUI, 5'd0, rt, rand_tmp[15:0]));
                    end else begin
                        rs = pick_reg(0);
                        rt = pick_reg_except1(rs);
                        case (op_pick)
                            0: opcode = OP_ADDI;
                            1: opcode = OP_ADDIU;
                            2: opcode = OP_SLTI;
                            3: opcode = OP_SLTIU;
                            4: opcode = OP_ANDI;
                            5: opcode = OP_ORI;
                            default: opcode = OP_XORI;
                        endcase
                        emit_inst(enc_i(opcode, rs, rt, small_signed_imm(0)));
                    end
                end

                4: begin // Load with $zero base and bounded address, rt != rs.
                    rt = pick_reg(0);
                    op_pick = rand_mod(5);
                    case (op_pick)
                        0: begin opcode = OP_LB;  byte_addr = rand_mod(DMEM_BYTES); end
                        1: begin opcode = OP_LBU; byte_addr = rand_mod(DMEM_BYTES); end
                        2: begin opcode = OP_LH;  byte_addr = (rand_mod(DMEM_BYTES / 2) << 1); end
                        3: begin opcode = OP_LHU; byte_addr = (rand_mod(DMEM_BYTES / 2) << 1); end
                        default: begin opcode = OP_LW; byte_addr = (rand_mod(DMEM_BYTES / 4) << 2); end
                    endcase
                    emit_inst(enc_i(opcode, 5'd0, rt, byte_addr[15:0]));
                end

                5: begin // Store with $zero base and bounded address.
                    rt = pick_reg(0);
                    op_pick = rand_mod(3);
                    case (op_pick)
                        0: begin opcode = OP_SB; byte_addr = rand_mod(DMEM_BYTES); end
                        1: begin opcode = OP_SH; byte_addr = (rand_mod(DMEM_BYTES / 2) << 1); end
                        default: begin opcode = OP_SW; byte_addr = (rand_mod(DMEM_BYTES / 4) << 2); end
                    endcase
                    emit_inst(enc_i(opcode, 5'd0, rt, byte_addr[15:0]));
                end

                6: begin // BEQ/BNE over NOP-only gap.
                    rs = pick_reg(0);
                    rt = pick_reg(0);
                    skip = 1 + rand_mod(3);
                    opcode = (rand_mod(2) == 0) ? OP_BEQ : OP_BNE;
                    emit_inst(enc_i(opcode, rs, rt, skip[15:0]));
                    emit_nops(skip);
                end

                default: begin // J/JAL/JR/JALR forward over NOP-only gap.
                    op_pick = rand_mod(4);
                    skip = 1 + rand_mod(3);
                    if (op_pick == 0) begin
                        target_idx = g_ptr + 1 + skip;
                        emit_inst(enc_j(OP_J, target_idx[25:0]));
                        emit_nops(skip);
                    end else if (op_pick == 1) begin
                        target_idx = g_ptr + 1 + skip;
                        emit_inst(enc_j(OP_JAL, target_idx[25:0]));
                        emit_nops(skip);
                    end else if (op_pick == 2) begin
                        rs = pick_reg(0);
                        target_idx = g_ptr + 2 + skip;
                        emit_inst(enc_i(OP_ADDIU, 5'd0, rs, (target_idx << 2) & 16'hffff));
                        emit_inst(enc_r(rs, 5'd0, 5'd0, 5'd0, FN_JR));
                        emit_nops(skip);
                    end else begin
                        rs = pick_reg(0);
                        rd = pick_reg_except1(rs);
                        target_idx = g_ptr + 2 + skip;
                        emit_inst(enc_i(OP_ADDIU, 5'd0, rs, (target_idx << 2) & 16'hffff));
                        emit_inst(enc_r(rs, 5'd0, rd, 5'd0, FN_JALR));
                        emit_nops(skip);
                    end
                end
            endcase
        end
    endtask

    task generate_instructions;
        input integer cur_phase;
        integer i;
        begin
            ascii_state = "generate instructions           ";
            emit_directed_prelude;
            for (i = 0; (i < N_INST) && (g_ptr < (IMEM_WORDS - 12)); i = i + 1) begin
                emit_random_one(cur_phase);
            end
            emit_halt;
        end
    endtask

    // ---------------------------------------------------------
    // Compare golden vs DUT architectural state.
    // ---------------------------------------------------------
    task print_register_dump;
        integer r;
        begin
            $display("  ----- Golden Registers -----");
            for (r = 0; r < 32; r = r + 4) begin
                $display("    r%02d=%08h  r%02d=%08h  r%02d=%08h  r%02d=%08h",
                    r, golden.regs[r], r+1, golden.regs[r+1],
                    r+2, golden.regs[r+2], r+3, golden.regs[r+3]);
            end
            $display("  ----- DUT Registers -----");
            for (r = 0; r < 32; r = r + 4) begin
                $display("    r%02d=%08h  r%02d=%08h  r%02d=%08h  r%02d=%08h",
                    r, `MIPS_CRT_DUT_REG(r), r+1, `MIPS_CRT_DUT_REG(r+1),
                    r+2, `MIPS_CRT_DUT_REG(r+2), r+3, `MIPS_CRT_DUT_REG(r+3));
            end
        end
    endtask

    task compare_state;
        input integer cur_phase;
        input integer cur_iter;
        output integer pass;
        integer i;
        reg mismatch;
        reg [7:0] dut_byte;
        reg [31:0] dut_byte_word;
        begin
            ascii_state = "compare final state             ";
            mismatch = 0;

            if (g_fault) begin
                $display("\n========== FAIL Phase %0d Iter %0d ==========" , cur_phase, cur_iter);
                $display("  Golden faulted: pc=%08h status=%0s", g_pc, g_status);
                mismatch = 1;
            end

            if (`MIPS_CRT_DUT_REG(0) !== 32'h0000_0000) begin
                if (!mismatch) $display("\n========== FAIL Phase %0d Iter %0d ==========" , cur_phase, cur_iter);
                $display("  REG r0 : expected hard-zero, DUT %08h", `MIPS_CRT_DUT_REG(0));
                mismatch = 1;
            end

            for (i = 1; i < 32; i = i + 1) begin
                if (golden.regs[i] !== `MIPS_CRT_DUT_REG(i)) begin
                    if (!mismatch) $display("\n========== FAIL Phase %0d Iter %0d ==========" , cur_phase, cur_iter);
                    $display("  REG r%0d : golden %08h  DUT %08h", i, golden.regs[i], `MIPS_CRT_DUT_REG(i));
                    mismatch = 1;
                end
            end

            for (i = 0; i < DMEM_BYTES; i = i + 1) begin
                dut_byte_word = `MIPS_CRT_DUT_READ_DMEM_BYTE(i);
                dut_byte = dut_byte_word[7:0];
                if (golden.dmem[i] !== dut_byte) begin
                    if (!mismatch) $display("\n========== FAIL Phase %0d Iter %0d ==========" , cur_phase, cur_iter);
                    $display("  DMEM[%0d] : golden %02h  DUT %02h", i, golden.dmem[i], dut_byte);
                    mismatch = 1;
                end
            end

            if (mismatch) begin
                $display("  Context: SEED=%0d seed_state=%0d phase=%0d iter=%0d g_ptr=%0d halt_pc=%08h", SEED, seed_state, cur_phase, cur_iter, g_ptr, halt_pc);
                $display("  Golden: pc=%08h inst=%08h name=%0s done=%0b fault=%0b result=%08h rd=%0d wen=%0b status=%0s",
                    g_pc, g_inst, g_inst_name, g_done, g_fault, g_result, g_rd, g_wen, g_status);
                $display("  DUT   : pc=%08h inst=%08h name=%0s next_pc=%08h reg_wen=%0b wreg=%0d wdata=%08h alu=%08h",
                    `MIPS_CRT_DUT_PC, `MIPS_CRT_DUT_INST, dut_inst_name, `MIPS_CRT_DUT_NEXT_PC,
                    `MIPS_CRT_DUT_REG_WEN, `MIPS_CRT_DUT_WRITE_REG, `MIPS_CRT_DUT_WDATA, `MIPS_CRT_DUT_ALU_RESULT);
                print_register_dump;
                $display("==============================================\n");
                pass = 0;
            end else begin
                pass = 1;
            end
        end
    endtask

    // ---------------------------------------------------------
    // Main test control
    // ---------------------------------------------------------
    integer res;
    integer wait_count;

    initial begin
        seed_state = SEED;
        clk = 1'b0;
        rst = 1'b1;
        total_pass = 0;
        total_fail = 0;
        ascii_state = "crt init                        ";
        ascii_phase = "not started             ";
        ascii_iter_state = "not started             ";

        $display("");
        $display("=======================================================");
        $display(" MIPS CRT v3 -- Constrained Random Test");
        $display("   SEED=%0d N_INST=%0d M_ITER=%0d REG_POOL=%0d", SEED, N_INST, M_ITER, REG_POOL);
        $display("   PHASE_START=%0d PHASE_END=%0d IMEM_WORDS=%0d DMEM_BYTES=%0d", PHASE_START, PHASE_END, IMEM_WORDS, DMEM_BYTES);
        $display("=======================================================");

        repeat (3) @(posedge clk);

        for (phase = PHASE_START; phase <= PHASE_END; phase = phase + 1) begin
            if (phase == 1) ascii_phase = "phase1 alu/mem          ";
            else if (phase == 2) ascii_phase = "phase2 plus branch      ";
            else ascii_phase = "phase3 plus jump        ";

            $display("---- Phase %0d ----", phase);
            for (iter = 0; iter < M_ITER; iter = iter + 1) begin
                ascii_iter_state = "reset/load image        ";
                rst = 1'b1;
                repeat (3) @(posedge clk);
                // Wait for the reset-cycle nonblocking assignments in the DUT
                // and golden model to settle before injecting the next image.
                @(negedge clk);

                prepare_memories;
                generate_instructions(phase);

                if (gen_error) begin
                    $display("MIPS_CRT_GEN_ERROR: generated program overflowed memory");
                    total_fail = total_fail + 1;
                    $finish;
                end

                $display("  [RUN ] phase=%0d iter=%0d program_words=%0d halt_pc=%08h seed_state=%0d", phase, iter, g_ptr + 1, halt_pc, seed_state);

                ascii_iter_state = "running                 ";
                rst = 1'b0;

                wait_count = 0;
                while ((g_done !== 1'b1) && (wait_count < MAX_WAIT_CYCLES)) begin
                    @(posedge clk);
                    wait_count = wait_count + 1;
                end

                if (g_done !== 1'b1) begin
                    $display("\n========== FAIL Phase %0d Iter %0d ==========" , phase, iter);
                    $display("  Golden did not halt within MAX_WAIT_CYCLES=%0d", MAX_WAIT_CYCLES);
                    total_fail = total_fail + 1;
                    $finish;
                end

                wait_count = 0;
`ifdef MIPS_CRT_DUT_PIPELINE
                while (!(`MIPS_CRT_DUT_RETIRE_VALID && (`MIPS_CRT_DUT_RETIRE_PC === halt_pc)) &&
                       (wait_count < MAX_WAIT_CYCLES)) begin
                    @(posedge clk);
                    wait_count = wait_count + 1;
                end

                if (!(`MIPS_CRT_DUT_RETIRE_VALID && (`MIPS_CRT_DUT_RETIRE_PC === halt_pc))) begin
                    $display("\n========== FAIL Phase %0d Iter %0d ==========", phase, iter);
                    $display("  DUT did not retire halt_pc=%08h within MAX_WAIT_CYCLES=%0d; retire_valid=%0b retire_pc=%08h", halt_pc, MAX_WAIT_CYCLES, `MIPS_CRT_DUT_RETIRE_VALID, `MIPS_CRT_DUT_RETIRE_PC);
                    print_register_dump;
                    total_fail = total_fail + 1;
                    $finish;
                end
`else
                while ((`MIPS_CRT_DUT_PC !== halt_pc) && (wait_count < MAX_WAIT_CYCLES)) begin
                    @(posedge clk);
                    wait_count = wait_count + 1;
                end

                if (`MIPS_CRT_DUT_PC !== halt_pc) begin
                    $display("\n========== FAIL Phase %0d Iter %0d ==========", phase, iter);
                    $display("  DUT did not reach halt_pc=%08h within MAX_WAIT_CYCLES=%0d; DUT pc=%08h", halt_pc, MAX_WAIT_CYCLES, `MIPS_CRT_DUT_PC);
                    print_register_dump;
                    total_fail = total_fail + 1;
                    $finish;
                end
`endif

                repeat (DUT_DRAIN_CYCLES) @(posedge clk);

                compare_state(phase, iter, res);
                if (res) begin
                    total_pass = total_pass + 1;
                    $display("  [PASS] phase=%0d iter=%0d", phase, iter);
                end else begin
                    total_fail = total_fail + 1;
                    $display("  [FAIL] phase=%0d iter=%0d -- inspect wave.shm", phase, iter);
                    $finish;
                end
            end
        end

        ascii_state = "all tests passed                ";
        $display("=======================================================");
        $display(" FINAL: %0d PASSED / %0d FAILED", total_pass, total_fail);
        if (total_fail == 0) begin
            $display(" >>> MIPS CRT v3 ALL TESTS PASSED <<<");
        end
        $display("=======================================================");
        $finish;
    end

    // Optional global safety timeout.  Large regressions should keep this at
    // zero because each DUT/golden wait loop already has MAX_WAIT_CYCLES.
    initial begin
        if (GLOBAL_TIMEOUT_CYCLES > 0) begin
            repeat (GLOBAL_TIMEOUT_CYCLES) @(posedge clk);
            $display("MIPS_CRT_TIMEOUT: global simulation timeout after %0d cycles", GLOBAL_TIMEOUT_CYCLES);
            $finish;
        end
    end

`ifndef MIPS_CRT_NO_WAVE
    // ACMTF waveform for SimVision.  Large CRT regressions can disable this
    // with +define+MIPS_CRT_NO_WAVE to avoid generating huge wave.shm files.
    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_MIPS_CRT_v3, "ACMTF");
    end
`endif

endmodule
