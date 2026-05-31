`timescale 1ns/1ps

// =============================================================
// MIPS single-cycle Data Memory
// -------------------------------------------------------------
// Wrapper kept stable for the CPU, while the storage hierarchy is
// normalized as:
//   u_dmem : data_memory
//     └── u_bram : bram_be
//         └── mem[]  // 32-bit word array with byte enable
//
// - Load path remains combinational for the current single-cycle CPU.
// - Store path commits on posedge clk using byte enables.
// - Little-endian byte lane mapping is preserved.
// - Misaligned half/word accesses are treated as idle: no write, load=0.
// - MEM_AW is still the byte-address width for wrapper compatibility;
//   internal BRAM word address width is MEM_AW-2.
// =============================================================

module data_memory #(
    parameter MEM_AW = 10
)(
    input         clk,
    input  [31:0] Addr,
    input  [31:0] Data_rt,
    input  [1:0]  WdLen,
    input  [1:0]  MemRW,
    input         LoadEx,
    output [31:0] Data_RD,
    output        MisalignedAccess
);
    localparam [1:0] MEM_BYTE = 2'b00;
    localparam [1:0] MEM_HALF = 2'b01;
    localparam [1:0] MEM_WORD = 2'b10;
    localparam [1:0] MEM_NONE = 2'b11;

    localparam [1:0] MEM_LOAD  = 2'b01;
    localparam [1:0] MEM_STORE = 2'b10;

    localparam WORD_AW = MEM_AW - 2;

    wire [WORD_AW-1:0] word_addr;
    wire [1:0]         lane;
    wire [31:0]        word_rdata;
    reg  [31:0]        word_wdata;
    reg  [3:0]         byte_enable;
    wire               load_access;
    wire               store_access;
    wire               memory_access;
    wire               half_misaligned;
    wire               word_misaligned;
    wire               effective_store;

    assign word_addr = Addr[MEM_AW-1:2];
    assign lane      = Addr[1:0];

    assign load_access      = (MemRW == MEM_LOAD);
    assign store_access     = (MemRW == MEM_STORE);
    assign memory_access    = load_access | store_access;
    assign half_misaligned  = (WdLen == MEM_HALF) & Addr[0];
    assign word_misaligned  = (WdLen == MEM_WORD) & (Addr[1] | Addr[0]);
    assign MisalignedAccess = memory_access & (half_misaligned | word_misaligned);
    assign effective_store  = store_access & ~MisalignedAccess & (WdLen != MEM_NONE);

    always @(*) begin
        byte_enable = 4'b0000;
        word_wdata  = 32'h0000_0000;

        if (effective_store) begin
            case (WdLen)
                MEM_BYTE: begin
                    case (lane)
                        2'b00: begin byte_enable = 4'b0001; word_wdata = {24'h000000, Data_rt[7:0]}; end
                        2'b01: begin byte_enable = 4'b0010; word_wdata = {16'h0000, Data_rt[7:0], 8'h00}; end
                        2'b10: begin byte_enable = 4'b0100; word_wdata = {8'h00, Data_rt[7:0], 16'h0000}; end
                        2'b11: begin byte_enable = 4'b1000; word_wdata = {Data_rt[7:0], 24'h000000}; end
                    endcase
                end
                MEM_HALF: begin
                    if (Addr[1] == 1'b0) begin
                        byte_enable = 4'b0011;
                        word_wdata  = {16'h0000, Data_rt[15:0]};
                    end else begin
                        byte_enable = 4'b1100;
                        word_wdata  = {Data_rt[15:0], 16'h0000};
                    end
                end
                MEM_WORD: begin
                    byte_enable = 4'b1111;
                    word_wdata  = Data_rt;
                end
                default: begin
                    byte_enable = 4'b0000;
                    word_wdata  = 32'h0000_0000;
                end
            endcase
        end
    end

    bram_be #(
        .ADDR_WIDTH(WORD_AW),
        .RESET_WORD(32'h0000_0000)
    ) u_bram (
        .clk(clk),
        .we(effective_store),
        .be(byte_enable),
        .addr(word_addr),
        .wdata(word_wdata),
        .rdata(word_rdata)
    );

    wire [7:0] selected_byte;
    wire [15:0] selected_half;

    assign selected_byte = (lane == 2'b00) ? word_rdata[ 7: 0] :
                           (lane == 2'b01) ? word_rdata[15: 8] :
                           (lane == 2'b10) ? word_rdata[23:16] :
                                             word_rdata[31:24];

    assign selected_half = (Addr[1] == 1'b0) ? word_rdata[15:0] : word_rdata[31:16];

    reg [31:0] read_data;
    always @(*) begin
        read_data = 32'h0000_0000;
        if (load_access && !MisalignedAccess) begin
            case (WdLen)
                MEM_BYTE: read_data = LoadEx ? {24'h000000, selected_byte}
                                            : {{24{selected_byte[7]}}, selected_byte};
                MEM_HALF: read_data = LoadEx ? {16'h0000, selected_half}
                                            : {{16{selected_half[15]}}, selected_half};
                MEM_WORD: read_data = word_rdata;
                default:  read_data = 32'h0000_0000;
            endcase
        end
    end

    assign Data_RD = read_data;
endmodule
