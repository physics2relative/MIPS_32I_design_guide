`timescale 1ns/1ps

// =============================================================
// MIPS Jump Target Generator
// -------------------------------------------------------------
// Receives instruction[25:0] (`target26`) directly from instruction
// split logic and combines it with PCPlus4[31:28].
// =============================================================

module jump_target_generator (
    input        Jump,
    input        JumpSel,
    input [31:0] PCPlus4,
    input [25:0] target26,
    input [31:0] Data_rs,
    output [31:0] JumpImmTarget,
    output [31:0] SelectedJumpTarget
);
    wire unused_jump;
    assign unused_jump = Jump;

    assign JumpImmTarget = {PCPlus4[31:28], target26, 2'b00};
    assign SelectedJumpTarget = JumpSel ? Data_rs : JumpImmTarget;
endmodule
