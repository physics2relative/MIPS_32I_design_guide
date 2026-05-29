`timescale 1ns/1ps

// =============================================================
// MIPS pipeline Data Memory / MEM-WB load-data alignment
// -------------------------------------------------------------
// FPGA-oriented version with synchronous BRAM read and synchronous write.
// Read control/address lane metadata is delayed to match BRAM read latency.
// =============================================================

module data_memory #(
    parameter MEM_AW = 10
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] Addr,
    input  wire [31:0] Data_rt,
    input  wire [1:0]  WdLen,
    input  wire [2:0]  MemRW,
    input  wire        LoadEx,
    output wire [31:0] Data_RD
);
    localparam [1:0] MEM_BYTE = 2'b00;
    localparam [1:0] MEM_HALF = 2'b01;
    localparam [1:0] MEM_WORD = 2'b10;

    localparam [2:0] MEM_SB   = 3'b000;
    localparam [2:0] MEM_SH   = 3'b001;
    localparam [2:0] MEM_SW   = 3'b010;
    localparam [2:0] MEM_LOAD = 3'b011;

    localparam WORD_AW = MEM_AW - 2;

    wire [WORD_AW-1:0] word_addr;
    wire [1:0]         lane;
    reg  [31:0]        word_wdata;
    reg  [3:0]         byte_enable;
    wire [31:0]        word_rdata;

    assign word_addr = Addr[MEM_AW-1:2];
    assign lane      = Addr[1:0];

    always @(*) begin
        byte_enable = 4'b0000;
        word_wdata  = 32'h0000_0000;
        case (MemRW)
            MEM_SB: begin
                byte_enable = 4'b0001 << lane;
                word_wdata  = {4{Data_rt[7:0]}};
            end
            MEM_SH: begin
                byte_enable = lane[1] ? 4'b1100 : 4'b0011;
                word_wdata  = {2{Data_rt[15:0]}};
            end
            MEM_SW: begin
                byte_enable = 4'b1111;
                word_wdata  = Data_rt;
            end
            default: begin
                byte_enable = 4'b0000;
                word_wdata  = 32'h0000_0000;
            end
        endcase
    end

    bram_be #(
        .ADDR_WIDTH(WORD_AW),
        .RESET_WORD(32'h0000_0000)
    ) u_bram (
        .clk(clk),
        .be(byte_enable),
        .addr(word_addr),
        .wdata(word_wdata),
        .rdata(word_rdata)
    );

    reg [1:0] WdLen_d;
    reg [1:0] lane_d;
    reg [2:0] MemRW_d;
    reg       LoadEx_d;
    reg       rst_d;

    always @(posedge clk) begin
        WdLen_d  <= WdLen;
        lane_d   <= lane;
        MemRW_d  <= MemRW;
        LoadEx_d <= LoadEx;
        rst_d    <= rst;
    end

    wire [7:0] selected_byte;
    wire [15:0] selected_half;

    assign selected_byte = (lane_d == 2'b00) ? word_rdata[ 7: 0] :
                           (lane_d == 2'b01) ? word_rdata[15: 8] :
                           (lane_d == 2'b10) ? word_rdata[23:16] :
                                               word_rdata[31:24];

    assign selected_half = lane_d[1] ? word_rdata[31:16] : word_rdata[15:0];

    reg [31:0] read_data;
    always @(*) begin
        case (WdLen_d)
            MEM_BYTE: read_data = LoadEx_d ? {24'h000000, selected_byte}
                                          : {{24{selected_byte[7]}}, selected_byte};
            MEM_HALF: read_data = LoadEx_d ? {16'h0000, selected_half}
                                          : {{16{selected_half[15]}}, selected_half};
            MEM_WORD: read_data = word_rdata;
            default:  read_data = 32'h0000_0000;
        endcase
    end

    reg [31:0] data_held;
    always @(posedge clk) begin
        if (rst) begin
            data_held <= 32'h0000_0000;
        end else if (MemRW_d == MEM_LOAD) begin
            data_held <= read_data;
        end
    end

    assign Data_RD = (MemRW_d == MEM_LOAD && !rst_d) ? read_data : data_held;
endmodule
