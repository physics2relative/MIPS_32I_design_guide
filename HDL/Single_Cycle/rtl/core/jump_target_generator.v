`timescale 1ns/1ps

// =============================================================
// MIPS Jump Target Generator
// -------------------------------------------------------------
// Pure combinational generator for J-type immediate jump target.
// It only owns the MIPS address concatenation:
//   JumpImmTarget = {PCPlus4[31:28], target26, 2'b00}
//
// The rs-vs-immediate target selection is intentionally kept outside this
// module as the Jump Sel mux, because that mux also depends on forwarded rs in
// the pipelined datapath.
// =============================================================

module jump_target_generator (
    input  [31:0] PCPlus4,
    input  [25:0] target26,
    output [31:0] JumpImmTarget
);
    assign JumpImmTarget = {PCPlus4[31:28], target26, 2'b00};
endmodule
