`timescale 1ns/1ps

// =============================================================
// Generic 32-bit word ROM/RAM model for instruction memory
// -------------------------------------------------------------
// - Exposes mem[] under u_bram for CRT/testbench injection.
// - Asynchronous read is kept for the single-cycle CPU model.
// - The wrapper decides how byte PC addresses map to word indices.
// =============================================================

module bram_rom #(
    parameter ADDR_WIDTH = 9,
    parameter INIT_FILE = "",
    parameter RESET_WORD = 32'h0000_0000
)(
    input  wire [ADDR_WIDTH-1:0] addr,
    output wire [31:0]           rdata
);
    integer i;
    reg [31:0] mem [0:(1 << ADDR_WIDTH)-1];

    initial begin
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            mem[i] = RESET_WORD;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    assign rdata = mem[addr];
endmodule
