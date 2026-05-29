`timescale 1ns/1ps

// =============================================================
// MIPS immediate generator
// -------------------------------------------------------------
// ImmSel is intentionally 2-bit because this block only handles
// 16-bit immediates.  Jump target26 is routed directly to the
// jump_target_generator in the top-level datapath.
// =============================================================

module immediate_generator (
    input  [1:0]  ImmSel,
    input  [15:0] imm16,
    output reg [31:0] ImmVal
);
    localparam [1:0] IMM_SIGN16   = 2'b00;
    localparam [1:0] IMM_ZERO16   = 2'b01;
    localparam [1:0] IMM_LUI16    = 2'b10;
    localparam [1:0] IMM_BRANCH16 = 2'b11;

    wire [31:0] sign16   = {{16{imm16[15]}}, imm16};
    wire [31:0] zero16   = {16'h0000, imm16};
    wire [31:0] lui16    = {imm16, 16'h0000};
    wire [31:0] branch16 = sign16 << 2;

    always @(*) begin
        case (ImmSel)
            IMM_SIGN16:   ImmVal = sign16;
            IMM_ZERO16:   ImmVal = zero16;
            IMM_LUI16:    ImmVal = lui16;
            IMM_BRANCH16: ImmVal = branch16;
            default:      ImmVal = 32'h0000_0000;
        endcase
    end
endmodule
