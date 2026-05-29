`timescale 1ns/1ps

// 32-bit unsigned comparator used by the ALU.
// Signed SLT is derived in the ALU wrapper using sign-bit xor + mux logic.
module comparator (
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    output wire        lt
);
    assign lt = (in_a < in_b);
endmodule
