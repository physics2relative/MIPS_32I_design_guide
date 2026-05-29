`timescale 1ns/1ps

// Branch comparator for current single-cycle MIPS subset.
// BrSel is 1-bit because only beq/bne are implemented here:
//   BrSel=0 -> EQ branch condition
//   BrSel=1 -> NE branch condition
// No Branch input is used in this block; branch enable / PC selection is handled
// outside by control/PC logic.
module branch_comparator (
    input  wire        BrSel,
    input  wire [31:0] Data_rs,
    input  wire [31:0] Data_rt,
    output wire        BranchTaken
);

    localparam BR_EQ = 1'b0;
    localparam BR_NE = 1'b1;

    wire eq;
    assign eq = (Data_rs == Data_rt);
    assign BranchTaken = (BrSel == BR_EQ) ? eq : ~eq;

endmodule
