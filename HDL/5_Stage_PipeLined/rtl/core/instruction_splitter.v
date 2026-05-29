`timescale 1ns/1ps

// =============================================================
// MIPS instruction field splitter
// -------------------------------------------------------------
// Logisim-friendly structural block placed after Instruction Memory.
// It exposes the raw 32-bit instruction fields used by control, register
// file addressing, immediate generation, shift amount selection, and jump
// target generation.
//
// MIPS instruction format split:
//   opcode   = Inst[31:26]
//   rs       = Inst[25:21]
//   rt       = Inst[20:16]
//   rd       = Inst[15:11]
//   shamt    = Inst[10:6]
//   funct    = Inst[5:0]
//   imm16    = Inst[15:0]
//   target26 = Inst[25:0]
// =============================================================

module instruction_splitter (
    input  wire [31:0] Inst,
    output wire [5:0]  opcode,
    output wire [4:0]  rs,
    output wire [4:0]  rt,
    output wire [4:0]  rd,
    output wire [4:0]  shamt,
    output wire [5:0]  funct,
    output wire [15:0] imm16,
    output wire [25:0] target26
);
    assign opcode   = Inst[31:26];
    assign rs       = Inst[25:21];
    assign rt       = Inst[20:16];
    assign rd       = Inst[15:11];
    assign shamt    = Inst[10:6];
    assign funct    = Inst[5:0];
    assign imm16    = Inst[15:0];
    assign target26 = Inst[25:0];
endmodule
