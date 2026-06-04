`timescale 1ns/1ps

// MIPS single-cycle ALU
// Structural style follows the Logisim ALU block:
// - ADD/SUB share one adder. ALUSel[0] drives B inversion and carry-in.
// - SLT/SLTU share one unsigned comparator. Signed LT is derived by sign-bit
//   xor selecting between A[31] and unsigned comparison result.
// - Logic operation results are exposed as named block-level wires before the
//   final result mux selects the requested ALU operation.
module ALU (
    input  wire [31:0] ALU_a,
    input  wire [31:0] ALU_b,
    input  wire [3:0]  ALUSel,
    output reg  [31:0] ALU_Result
);

    localparam ADD  = 4'd0;
    localparam SUB  = 4'd1;
    localparam AND  = 4'd2;
    localparam OR   = 4'd3;
    localparam XOR  = 4'd4;
    localparam SLT  = 4'd5;
    localparam SLTU = 4'd6;
    localparam SLL  = 4'd7;
    localparam SRL  = 4'd8;
    localparam SRA  = 4'd9;
    localparam NOR  = 4'd10;
    localparam ABS  = 4'd11;
    localparam NONE = 4'd15;

    // Adder path.  This intentionally uses only ALUSel[0], matching the
    // Logisim mux/carry wiring: ADD(0000)->B,+0 and SUB(0001)->~B,+1.
    wire        add_sub_sel;
    wire        adder_c_out;
    wire [31:0] adder_in_a;
    wire [31:0] adder_in_b;
    wire [31:0] adder_out;

    assign add_sub_sel = ALUSel[0];
    assign adder_in_a  = ALU_a;
    assign adder_in_b  = add_sub_sel ? ~ALU_b : ALU_b;

    adder u_adder (
        .c_in  (add_sub_sel),
        .in_a  (adder_in_a),
        .in_b  (adder_in_b),
        .out   (adder_out),
        .c_out (adder_c_out)
    );

    // Logic gate path.  NOR is derived from the OR gate output so the HDL keeps
    // the same block relationship as the Logisim circuit.
    wire [31:0] and_result;
    wire [31:0] or_result;
    wire [31:0] xor_result;
    wire [31:0] nor_result;

    assign and_result = ALU_a & ALU_b;
    assign or_result  = ALU_a | ALU_b;
    assign xor_result = ALU_a ^ ALU_b;
    assign nor_result = ~or_result;

    // Custom integer ABS extension.  This keeps two-complement wrap-around,
    // so abs(0x8000_0000) remains 0x8000_0000 because the project has no
    // overflow/exception path.
    wire [31:0] abs_result;
    assign abs_result = ALU_a[31] ? (~ALU_a + 32'd1) : ALU_a;

    // Comparator path.  Only one unsigned comparator is instantiated.  Signed
    // less-than is reconstructed with the sign-bit xor mux:
    //   if signs differ, signed_lt = A[31]
    //   else             signed_lt = unsigned_lt
    wire sign_diff;
    wire unsigned_lt;
    wire signed_lt;

    assign sign_diff = ALU_a[31] ^ ALU_b[31];
    assign signed_lt = sign_diff ? ALU_a[31] : unsigned_lt;

    comparator u_unsigned_comparator (
        .in_a (ALU_a),
        .in_b (ALU_b),
        .lt   (unsigned_lt)
    );

    wire [4:0] shamt;
    assign shamt = ALU_b[4:0];

    always @(*) begin
        case (ALUSel)
            ADD  : ALU_Result = adder_out;
            SUB  : ALU_Result = adder_out;
            AND  : ALU_Result = and_result;
            OR   : ALU_Result = or_result;
            XOR  : ALU_Result = xor_result;
            SLT  : ALU_Result = {31'b0, signed_lt};
            SLTU : ALU_Result = {31'b0, unsigned_lt};
            SLL  : ALU_Result = ALU_a << shamt;
            SRL  : ALU_Result = ALU_a >> shamt;
            SRA  : ALU_Result = $signed(ALU_a) >>> shamt;
            NOR  : ALU_Result = nor_result;
            ABS  : ALU_Result = abs_result;
            NONE : ALU_Result = 32'h0000_0000;
            default: ALU_Result = 32'h0000_0000;
        endcase
    end

endmodule
