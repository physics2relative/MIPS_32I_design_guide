`timescale 1ns/1ps

// =============================================================
// MIPS pipeline Instruction Memory / IF-ID instruction register
// -------------------------------------------------------------
// FPGA-oriented version with synchronous BRAM read.  Because BRAM data is
// available one clock after Addr, this wrapper also owns the instruction
// side of the IF/ID register, including stall/flush handling.
//
// The separate IF/ID pipeline register in the top should carry PC/PC+4;
// Inst is supplied from this module already latency-aligned.
// =============================================================

module instruction_memory #(
    parameter INIT_FILE = "",
    parameter MEM_AW = 9
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] Addr,
    input  wire        Stall_IF_ID,
    input  wire        Flush_IF_ID,
    output wire [31:0] Inst
);
    localparam [31:0] MIPS_NOP = 32'h0000_0000; // sll $0,$0,0

    wire [MEM_AW-1:0] word_index;
    wire [31:0]       bram_q;
    assign word_index = Addr[MEM_AW+1:2];

    bram_rom #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(MEM_AW),
        .INIT_FILE(INIT_FILE),
        .RESET_WORD(MIPS_NOP)
    ) u_bram (
        .clk(clk),
        .addr(word_index),
        .q(bram_q)
    );

    // Delay control by one cycle to align with synchronous BRAM output.
    reg rst_d;
    reg flush_d;
    reg stall_d;
    always @(posedge clk) begin
        rst_d   <= rst;
        flush_d <= Flush_IF_ID;
        stall_d <= Stall_IF_ID;
    end

    reg [31:0] inst_held;
    always @(posedge clk) begin
        if (rst) begin
            inst_held <= MIPS_NOP;
        end else if (!stall_d) begin
            inst_held <= bram_q;
        end
    end

    wire [31:0] inst_selected = stall_d ? inst_held : bram_q;

    assign Inst = rst_d   ? MIPS_NOP :
                  flush_d ? MIPS_NOP :
                            inst_selected;
endmodule
