`timescale 1ns/1ps

// =============================================================
// MIPS PC Control
// -------------------------------------------------------------
// Branch comparator emits BranchTaken as the raw branch condition.
// This block applies Branch enable and gives Jump priority over branch
// when both are asserted.
// =============================================================

module pc_control (
    input  Branch,
    input  Jump,
    input  BranchTaken,
    output reg [1:0] PCSel
);
    localparam [1:0] PC_PLUS4  = 2'b00;
    localparam [1:0] PC_BRANCH = 2'b01;
    localparam [1:0] PC_JUMP   = 2'b10;

    always @(*) begin
        if (Jump) begin
            PCSel = PC_JUMP;
        end else if (Branch && BranchTaken) begin
            PCSel = PC_BRANCH;
        end else begin
            PCSel = PC_PLUS4;
        end
    end
endmodule
