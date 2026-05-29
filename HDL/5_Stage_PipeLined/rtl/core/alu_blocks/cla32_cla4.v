`timescale 1ns/1ps


module cla32_cla4(
    input  [3:0] a,
    input  [3:0] b,
    input        c_in,
    output [3:0] s,
    output       pg,
    output       gg
    );

    wire [3:0] p, g;
    wire [4:1] c;

    assign p = a ^ b;
    assign g = a & b;

    assign c[1] = g[0] | (p[0] & c_in); 
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c_in);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c_in);
    assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c_in);

    assign s[0] = p[0] ^ c_in;
    assign s[1] = p[1] ^ c[1];
    assign s[2] = p[2] ^ c[2];
    assign s[3] = p[3] ^ c[3];

    assign pg = p[0] & p[1] & p[2] & p[3];
    assign gg = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);

endmodule
