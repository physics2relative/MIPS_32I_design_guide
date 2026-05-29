`timescale 1ns/1ps


module adder_cla32(
    input [31:0] a,
    input [31:0] b,
    input c_in,
    output [31:0] s,
    output c_out
);

    wire [7:0] pg; 
    wire [7:0] gg; 
    wire [8:0] c; 

    assign c[0] = c_in;
    assign c_out = c[8];

    genvar k;

    generate 
        for (k = 0; k < 8; k = k + 1) begin : g1
            assign c[k+1] = gg[k] | (pg[k] & c[k]);
        end
    endgenerate

    genvar i;

    generate
        for (i = 0; i < 8; i = i + 1) begin : g2
            cla32_cla4 cla4 (
                .a    (a[4*i+3:4*i]),
                .b    (b[4*i+3:4*i]),
                .c_in (c[i]),
                .s    (s[4*i+3:4*i]),
                .pg   (pg[i]),
                .gg   (gg[i])
                );
            
        end
    endgenerate
endmodule


