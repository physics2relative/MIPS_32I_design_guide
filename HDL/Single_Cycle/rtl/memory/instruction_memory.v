`timescale 1ns/1ps

// =============================================================
// MIPS single-cycle Instruction Memory
// -------------------------------------------------------------
// Wrapper kept stable for the CPU, while the storage hierarchy is
// normalized as:
//   u_imem : instruction_memory
//     └── u_bram : bram_rom
//         └── mem[]  // 32-bit word array
//
// The CPU provides a byte-addressed PC.  The instruction memory converts
// that byte address to a word index with Addr[MEM_AW+1:2].
//
// Read remains asynchronous so the current single-cycle CPU timing is
// unchanged.  CRT/testbenches can inject instructions through
// u_imem.u_bram.mem[index].
// =============================================================

module instruction_memory #(
    parameter INIT_FILE = "",
    parameter MEM_AW = 9
)(
    input  wire [31:0] Addr,
    output wire [31:0] Inst
);
    wire [MEM_AW-1:0] word_index;
    assign word_index = Addr[MEM_AW+1:2];

    bram_rom #(
        .ADDR_WIDTH(MEM_AW),
        .INIT_FILE(INIT_FILE),
        .RESET_WORD(32'h0000_0000) // MIPS NOP = sll $0,$0,0
    ) u_bram (
        .addr(word_index),
        .rdata(Inst)
    );
endmodule
