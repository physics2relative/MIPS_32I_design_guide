`timescale 1ns/1ps

// =============================================================
// BRAM-inferrable single-port ROM/RAM model with synchronous read
// -------------------------------------------------------------
// Pipeline version: read data is registered on clk to match FPGA BRAM
// inference.  Keep mem[] visible for CRT/testbench program injection.
// =============================================================

module bram_rom #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 9,
    parameter INIT_FILE  = "",
    parameter RESET_WORD = 32'h0000_0000
)(
    input  wire                  clk,
    input  wire [ADDR_WIDTH-1:0] addr,
    output reg  [DATA_WIDTH-1:0] q
);
    integer i;
    reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];

    initial begin
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            mem[i] = RESET_WORD;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always @(posedge clk) begin
        q <= mem[addr];
    end
endmodule
