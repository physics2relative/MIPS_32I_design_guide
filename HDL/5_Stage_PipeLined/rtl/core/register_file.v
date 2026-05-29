`timescale 1ns/1ps

// =============================================================
// MIPS Register File
// -------------------------------------------------------------
// - 32 x 32-bit registers
// - 2 asynchronous read ports: rs, rt
// - 1 synchronous write port
// - $zero (register 0) is hard-wired to 0
// - Active-high reset clears every register
// - Same-cycle read-after-write bypass on both read ports
//
// Bypass policy:
//   If RegWEn=1 and Addr_WR matches a read address in the same
//   cycle, the read output returns WData immediately, except when
//   Addr_WR is zero. Writes to $zero are ignored.
// =============================================================

module register_file (
    input  wire        clk,
    input  wire        rst,

    input  wire        RegWEn,
    input  wire [4:0]  Addr_Rs,
    input  wire [4:0]  Addr_Rt,
    input  wire [4:0]  Addr_WR,
    input  wire [31:0] WData,

    output wire [31:0] Data_Rs,
    output wire [31:0] Data_Rt
);

    reg [31:0] regs [0:31];

    integer i;

    // Register write / reset.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'd0;
            end
        end else begin
            regs[0] <= 32'd0;
            if (RegWEn && (Addr_WR != 5'd0)) begin
                regs[Addr_WR] <= WData;
            end
        end
    end

    wire bypass_rs = RegWEn && (Addr_WR != 5'd0) && (Addr_WR == Addr_Rs);
    wire bypass_rt = RegWEn && (Addr_WR != 5'd0) && (Addr_WR == Addr_Rt);

    assign Data_Rs = rst                 ? 32'd0 :
                     (Addr_Rs == 5'd0)  ? 32'd0 :
                     bypass_rs          ? WData  : regs[Addr_Rs];

    assign Data_Rt = rst                 ? 32'd0 :
                     (Addr_Rt == 5'd0)  ? 32'd0 :
                     bypass_rt          ? WData  : regs[Addr_Rt];

endmodule
