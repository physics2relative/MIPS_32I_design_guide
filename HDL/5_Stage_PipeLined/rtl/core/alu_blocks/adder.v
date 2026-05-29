`timescale 1ns/1ps

// 32-bit combinational adder wrapper for the MIPS ALU.
// Arithmetic core is the CLA implementation ported from the RISC-V pipeline
// project (adder_cla32 + cla32_cla4).  The wrapper keeps the existing MIPS ALU
// port contract: in_a + in_b + c_in -> {c_out, out}.
module adder (
    input  wire        c_in,
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    output wire [31:0] out,
    output wire        c_out
);

    adder_cla32 u_adder_cla32 (
        .a     (in_a),
        .b     (in_b),
        .c_in  (c_in),
        .s     (out),
        .c_out (c_out)
    );

endmodule
