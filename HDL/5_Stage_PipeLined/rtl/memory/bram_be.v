`timescale 1ns/1ps

// =============================================================
// BRAM-inferrable single-port RAM with byte write enables
// -------------------------------------------------------------
// Pipeline version: synchronous read and synchronous write.  The byte
// enable pattern is compatible with FPGA BRAM inference and mem[] remains
// visible for CRT/testbench inspection.
// =============================================================

module bram_be #(
    parameter ADDR_WIDTH = 8,
    parameter RESET_WORD = 32'h0000_0000
)(
    input  wire                  clk,
    input  wire [3:0]            be,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [31:0]           wdata,
    output reg  [31:0]           rdata
);
    integer i;
    reg [31:0] mem [0:(1 << ADDR_WIDTH)-1];

    initial begin
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            mem[i] = RESET_WORD;
        end
    end

    always @(posedge clk) begin
        if (be[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
        if (be[1]) mem[addr][15: 8] <= wdata[15: 8];
        if (be[2]) mem[addr][23:16] <= wdata[23:16];
        if (be[3]) mem[addr][31:24] <= wdata[31:24];
        rdata <= mem[addr];
    end
endmodule
