`timescale 1ns/1ps

// =============================================================
// MIPS_Golden -- behavioral reference model for MIPS CRTv3
// -------------------------------------------------------------
// Executes one instruction per clock and exposes architectural state for
// CRT comparison/waveform debug.  This model follows the project-specific
// MIPS subset documented in mips-crt-v3-ralplan.md:
//   - PC reset = 0x0000_0000
//   - no delay slot
//   - jal/jalr link value = PC + 4
//   - branch real instructions = beq/bne only
//   - arithmetic overflow exceptions are not modeled; results wrap like RTL
//   - halt convention = J instruction that targets its own PC (`j self`)
// =============================================================

module MIPS_Golden #(
    parameter IMEM_WORDS = 4096,
    parameter DMEM_BYTES = 256,
    parameter PC_RESET   = 32'h0000_0000,
    parameter MAX_CYCLES = 200000
)(
    input  wire        clk,
    input  wire        rst,

    output reg [31:0] pc,
    output reg        done,
    output reg        fault,
    output reg [31:0] inst,
    output reg [31:0] result,
    output reg [4:0]  rd_out,
    output reg        wen_out,
    output reg [8*12-1:0] inst_name,
    output reg [8*32-1:0] status
);
    // ---------------------------------------------------------
    // ISA encodings
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

    // ---------------------------------------------------------
    // Architectural state visible to the CRT/waveform
    // ---------------------------------------------------------
    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] regs [0:31];
    reg [7:0]  dmem [0:DMEM_BYTES-1];

    integer cycle_count;
    integer i;

    // ---------------------------------------------------------
    // Decode/execution temporaries
    // ---------------------------------------------------------
    reg [31:0] t_inst;
    reg [31:0] t_pc_plus4;
    reg [31:0] t_next_pc;
    reg [31:0] t_result;
    reg [31:0] t_rs_val;
    reg [31:0] t_rt_val;
    reg signed [31:0] t_rs_s;
    reg signed [31:0] t_rt_s;
    reg [31:0] t_sign_imm;
    reg [31:0] t_zero_imm;
    reg [31:0] t_branch_off;
    reg [31:0] t_jump_target;
    reg [5:0]  t_opcode;
    reg [5:0]  t_funct;
    reg [4:0]  t_rs;
    reg [4:0]  t_rt;
    reg [4:0]  t_rd;
    reg [4:0]  t_shamt;
    reg [15:0] t_imm16;
    reg [25:0] t_target26;
    reg        t_we;
    reg [4:0]  t_waddr;
    integer    t_iaddr;
    integer    t_addr;
    reg [7:0]  t_b0;
    reg [7:0]  t_b1;
    reg [7:0]  t_b2;
    reg [7:0]  t_b3;

    // ---------------------------------------------------------
    // Utility helpers
    // ---------------------------------------------------------
    function [31:0] addr_wrap;
        input [31:0] addr;
        begin
            // CRT first pass constrains addresses to 0..255.  Keep modulo
            // behavior here so accidental high address bits do not index
            // outside the golden byte memory.
            addr_wrap = addr % DMEM_BYTES;
        end
    endfunction

    function [8*12-1:0] decode_name;
        input [31:0] insn;
        reg [5:0] op;
        reg [5:0] fn;
        begin
            op = insn[31:26];
            fn = insn[5:0];
            decode_name = "UNKNOWN     ";
            case (op)
                OP_RTYPE: begin
                    case (fn)
                        FN_SLL:  decode_name = "SLL         ";
                        FN_SRL:  decode_name = "SRL         ";
                        FN_SRA:  decode_name = "SRA         ";
                        FN_SLLV: decode_name = "SLLV        ";
                        FN_SRLV: decode_name = "SRLV        ";
                        FN_SRAV: decode_name = "SRAV        ";
                        FN_JR:   decode_name = "JR          ";
                        FN_JALR: decode_name = "JALR        ";
                        FN_ADD:  decode_name = "ADD         ";
                        FN_ADDU: decode_name = "ADDU        ";
                        FN_SUB:  decode_name = "SUB         ";
                        FN_SUBU: decode_name = "SUBU        ";
                        FN_AND:  decode_name = "AND         ";
                        FN_OR:   decode_name = "OR          ";
                        FN_XOR:  decode_name = "XOR         ";
                        FN_NOR:  decode_name = "NOR         ";
                        FN_SLT:  decode_name = "SLT         ";
                        FN_SLTU: decode_name = "SLTU        ";
                    endcase
                end
                OP_J:     decode_name = "J           ";
                OP_JAL:   decode_name = "JAL         ";
                OP_BEQ:   decode_name = "BEQ         ";
                OP_BNE:   decode_name = "BNE         ";
                OP_ADDI:  decode_name = "ADDI        ";
                OP_ADDIU: decode_name = "ADDIU       ";
                OP_SLTI:  decode_name = "SLTI        ";
                OP_SLTIU: decode_name = "SLTIU       ";
                OP_ANDI:  decode_name = "ANDI        ";
                OP_ORI:   decode_name = "ORI         ";
                OP_XORI:  decode_name = "XORI        ";
                OP_LUI:   decode_name = "LUI         ";
                OP_LB:    decode_name = "LB          ";
                OP_LH:    decode_name = "LH          ";
                OP_LW:    decode_name = "LW          ";
                OP_LBU:   decode_name = "LBU         ";
                OP_LHU:   decode_name = "LHU         ";
                OP_SB:    decode_name = "SB          ";
                OP_SH:    decode_name = "SH          ";
                OP_SW:    decode_name = "SW          ";
            endcase
        end
    endfunction

    // ---------------------------------------------------------
    // Initialization.  The CRT overwrites imem/dmem during reset for each
    // iteration, but deterministic defaults make standalone compile/smoke
    // behavior easier to inspect.
    // ---------------------------------------------------------
    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1) begin
            imem[i] = 32'h0000_0000;
        end
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'h0000_0000;
        end
        for (i = 0; i < DMEM_BYTES; i = i + 1) begin
            dmem[i] = 8'h00;
        end
    end

    // ---------------------------------------------------------
    // Behavioral execution
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pc          <= PC_RESET;
            done        <= 1'b0;
            fault       <= 1'b0;
            inst        <= 32'h0000_0000;
            result      <= 32'h0000_0000;
            rd_out      <= 5'd0;
            wen_out     <= 1'b0;
            inst_name   <= "RESET       ";
            status      <= "reset                           ";
            cycle_count <= 0;
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'h0000_0000;
            end
            for (i = 0; i < DMEM_BYTES; i = i + 1) begin
                dmem[i] <= 8'h00;
            end
        end else if (!done) begin
            cycle_count = cycle_count + 1;
            t_iaddr = (pc - PC_RESET) >> 2;

            if ((cycle_count > MAX_CYCLES) || (t_iaddr < 0) || (t_iaddr >= IMEM_WORDS)) begin
                done      <= 1'b1;
                fault     <= 1'b1;
                wen_out   <= 1'b0;
                rd_out    <= 5'd0;
                result    <= 32'h0000_0000;
                inst_name <= "FAULT       ";
                status    <= "fault: timeout or pc out of range";
            end else begin
                t_inst       = imem[t_iaddr];
                t_opcode     = t_inst[31:26];
                t_rs         = t_inst[25:21];
                t_rt         = t_inst[20:16];
                t_rd         = t_inst[15:11];
                t_shamt      = t_inst[10:6];
                t_funct      = t_inst[5:0];
                t_imm16      = t_inst[15:0];
                t_target26   = t_inst[25:0];
                t_pc_plus4   = pc + 32'd4;
                t_next_pc    = t_pc_plus4;
                t_result     = 32'h0000_0000;
                t_we         = 1'b0;
                t_waddr      = 5'd0;
                t_rs_val     = regs[t_rs];
                t_rt_val     = regs[t_rt];
                t_rs_s       = regs[t_rs];
                t_rt_s       = regs[t_rt];
                t_sign_imm   = {{16{t_imm16[15]}}, t_imm16};
                t_zero_imm   = {16'h0000, t_imm16};
                t_branch_off = {{14{t_imm16[15]}}, t_imm16, 2'b00};
                t_jump_target = {t_pc_plus4[31:28], t_target26, 2'b00};

                inst      <= t_inst;
                inst_name <= decode_name(t_inst);
                status    <= "running                         ";

                case (t_opcode)
                    OP_RTYPE: begin
                        case (t_funct)
                            FN_SLL: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rt_val << t_shamt; end
                            FN_SRL: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rt_val >> t_shamt; end
                            FN_SRA: begin t_we = 1'b1; t_waddr = t_rd; t_result = $signed(t_rt_val) >>> t_shamt; end
                            FN_SLLV: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rt_val << t_rs_val[4:0]; end
                            FN_SRLV: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rt_val >> t_rs_val[4:0]; end
                            FN_SRAV: begin t_we = 1'b1; t_waddr = t_rd; t_result = $signed(t_rt_val) >>> t_rs_val[4:0]; end
                            FN_JR: begin
                                t_next_pc = t_rs_val;
                            end
                            FN_JALR: begin
                                t_we      = 1'b1;
                                t_waddr   = t_rd;
                                t_result  = t_pc_plus4;
                                t_next_pc = t_rs_val;
                            end
                            FN_ADD, FN_ADDU: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rs_val + t_rt_val; end
                            FN_SUB, FN_SUBU: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rs_val - t_rt_val; end
                            FN_AND: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rs_val & t_rt_val; end
                            FN_OR:  begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rs_val | t_rt_val; end
                            FN_XOR: begin t_we = 1'b1; t_waddr = t_rd; t_result = t_rs_val ^ t_rt_val; end
                            FN_NOR: begin t_we = 1'b1; t_waddr = t_rd; t_result = ~(t_rs_val | t_rt_val); end
                            FN_SLT: begin t_we = 1'b1; t_waddr = t_rd; t_result = (t_rs_s < t_rt_s) ? 32'd1 : 32'd0; end
                            FN_SLTU: begin t_we = 1'b1; t_waddr = t_rd; t_result = (t_rs_val < t_rt_val) ? 32'd1 : 32'd0; end
                            default: begin
                                // Unsupported R-type encodings are side-effect-free NOPs.
                            end
                        endcase
                    end

                    OP_J: begin
                        t_next_pc = t_jump_target;
                        if (t_jump_target == pc) begin
                            done   <= 1'b1;
                            status <= "halt: j self                   ";
                        end
                    end

                    OP_JAL: begin
                        t_we      = 1'b1;
                        t_waddr   = 5'd31;
                        t_result  = t_pc_plus4;
                        t_next_pc = t_jump_target;
                    end

                    OP_BEQ: begin
                        if (t_rs_val == t_rt_val) begin
                            t_next_pc = t_pc_plus4 + t_branch_off;
                        end
                    end

                    OP_BNE: begin
                        if (t_rs_val != t_rt_val) begin
                            t_next_pc = t_pc_plus4 + t_branch_off;
                        end
                    end

                    OP_ADDI, OP_ADDIU: begin
                        t_we = 1'b1; t_waddr = t_rt; t_result = t_rs_val + t_sign_imm;
                    end
                    OP_SLTI: begin
                        t_we = 1'b1; t_waddr = t_rt; t_result = (t_rs_s < $signed(t_sign_imm)) ? 32'd1 : 32'd0;
                    end
                    OP_SLTIU: begin
                        t_we = 1'b1; t_waddr = t_rt; t_result = (t_rs_val < t_sign_imm) ? 32'd1 : 32'd0;
                    end
                    OP_ANDI: begin
                        t_we = 1'b1; t_waddr = t_rt; t_result = t_rs_val & t_zero_imm;
                    end
                    OP_ORI: begin
                        t_we = 1'b1; t_waddr = t_rt; t_result = t_rs_val | t_zero_imm;
                    end
                    OP_XORI: begin
                        t_we = 1'b1; t_waddr = t_rt; t_result = t_rs_val ^ t_zero_imm;
                    end
                    OP_LUI: begin
                        t_we = 1'b1; t_waddr = t_rt; t_result = {t_imm16, 16'h0000};
                    end

                    OP_LB, OP_LBU, OP_LH, OP_LHU, OP_LW: begin
                        t_we   = 1'b1;
                        t_waddr = t_rt;
                        t_addr = addr_wrap(t_rs_val + t_sign_imm);
                        t_b0 = dmem[addr_wrap(t_addr + 0)];
                        t_b1 = dmem[addr_wrap(t_addr + 1)];
                        t_b2 = dmem[addr_wrap(t_addr + 2)];
                        t_b3 = dmem[addr_wrap(t_addr + 3)];
                        case (t_opcode)
                            OP_LB:  t_result = {{24{t_b0[7]}}, t_b0};
                            OP_LBU: t_result = {24'h000000, t_b0};
                            OP_LH:  t_result = {{16{t_b1[7]}}, t_b1, t_b0};
                            OP_LHU: t_result = {16'h0000, t_b1, t_b0};
                            OP_LW:  t_result = {t_b3, t_b2, t_b1, t_b0};
                        endcase
                    end

                    OP_SB, OP_SH, OP_SW: begin
                        t_addr = addr_wrap(t_rs_val + t_sign_imm);
                        dmem[addr_wrap(t_addr + 0)] <= t_rt_val[7:0];
                        if ((t_opcode == OP_SH) || (t_opcode == OP_SW)) begin
                            dmem[addr_wrap(t_addr + 1)] <= t_rt_val[15:8];
                        end
                        if (t_opcode == OP_SW) begin
                            dmem[addr_wrap(t_addr + 2)] <= t_rt_val[23:16];
                            dmem[addr_wrap(t_addr + 3)] <= t_rt_val[31:24];
                        end
                    end

                    default: begin
                        // Invalid/unsupported encodings are side-effect-free NOPs.
                    end
                endcase

                if (t_we && (t_waddr != 5'd0)) begin
                    regs[t_waddr] <= t_result;
                end
                regs[0] <= 32'h0000_0000;

                wen_out <= t_we && (t_waddr != 5'd0);
                rd_out  <= t_waddr;
                result  <= t_result;

                if (!(t_opcode == OP_J && t_jump_target == pc)) begin
                    pc <= t_next_pc;
                end
            end
        end else begin
            wen_out <= 1'b0;
            regs[0] <= 32'h0000_0000;
        end
    end
endmodule
