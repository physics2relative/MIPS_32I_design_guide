`timescale 1ns/1ps

// =============================================================
// Generic 32-bit word BRAM model with byte enable
// -------------------------------------------------------------
// - Exposes mem[] under u_bram for CRT/testbench inspection.
// - Asynchronous read is kept for the single-cycle CPU model.
// - Synchronous byte-enable write models a synthesizable BRAM style.
// =============================================================

module bram_be #(
    parameter ADDR_WIDTH = 8,
    parameter RESET_WORD = 32'h0000_0000
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [3:0]            be,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [31:0]           wdata,
    output wire [31:0]           rdata
);
    integer i;
    reg [31:0] mem [0:(1 << ADDR_WIDTH)-1];

    initial begin
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            mem[i] = RESET_WORD;
        end
    end

    assign rdata = mem[addr];

    always @(posedge clk) begin
        if (we) begin
            if (be[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
            if (be[1]) mem[addr][15: 8] <= wdata[15: 8];
            if (be[2]) mem[addr][23:16] <= wdata[23:16];
            if (be[3]) mem[addr][31:24] <= wdata[31:24];
        end
    end
endmodule
