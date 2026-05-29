`timescale 1ns/1ps

// =============================================================
// MIPS 5-stage hazard / forwarding / stall / flush unit
// -------------------------------------------------------------
// This unit owns all data/control hazard decisions for the pipeline:
//   - EX-stage operand forwarding from MEM/WB
//   - load-use stall and ID/EX bubble insertion
//   - IF/ID + ID/EX flush on EX-stage PC redirect
//
// Branch compare and jump-register target selection also happen in EX, so
// branch/jump operands use the same EX-stage forwarding path as ALU operands.
//
// Forward encodings:
//   00: original ID/EX pipeline-register operand
//   01: WB stage writeback value
//   10: MEM stage forwarding value
// =============================================================

module hazard_unit (
    input  wire       RsUsed_ID,
    input  wire       RtUsed_ID,
    input  wire [4:0] rs_ID,
    input  wire [4:0] rt_ID,

    input  wire [4:0] rs_EX,
    input  wire [4:0] rt_EX,

    input  wire [4:0] DestReg_EX,
    input  wire [4:0] DestReg_MEM,
    input  wire [4:0] DestReg_WB,

    input  wire       RegWEn_EX,
    input  wire       RegWEn_MEM,
    input  wire       RegWEn_WB,
    input  wire       MemRead_EX,

    input  wire       PCRedirect_EX,

    output reg  [1:0] ForwardA_EX,
    output reg  [1:0] ForwardB_EX,

    output reg        Stall_PC,
    output reg        Stall_IF_ID,
    output reg        Flush_IF_ID,
    output reg        Flush_ID_EX
);
    localparam [1:0] FWD_REG = 2'b00;
    localparam [1:0] FWD_WB  = 2'b01;
    localparam [1:0] FWD_MEM = 2'b10;

    wire rs_load_use = RsUsed_ID && (rs_ID != 5'd0) &&
                       RegWEn_EX && MemRead_EX && (DestReg_EX == rs_ID);
    wire rt_load_use = RtUsed_ID && (rt_ID != 5'd0) &&
                       RegWEn_EX && MemRead_EX && (DestReg_EX == rt_ID);
    wire load_use_hazard = rs_load_use || rt_load_use;

    // EX-stage forwarding.  The nearest producer wins: MEM over WB.
    // This feeds ALU operands, EX-stage BranchComp operands, and jr/jalr targets.
    always @(*) begin
        ForwardA_EX = FWD_REG;
        if (rs_EX != 5'd0) begin
            if (RegWEn_MEM && (DestReg_MEM != 5'd0) && (DestReg_MEM == rs_EX)) begin
                ForwardA_EX = FWD_MEM;
            end else if (RegWEn_WB && (DestReg_WB != 5'd0) && (DestReg_WB == rs_EX)) begin
                ForwardA_EX = FWD_WB;
            end
        end
    end

    always @(*) begin
        ForwardB_EX = FWD_REG;
        if (rt_EX != 5'd0) begin
            if (RegWEn_MEM && (DestReg_MEM != 5'd0) && (DestReg_MEM == rt_EX)) begin
                ForwardB_EX = FWD_MEM;
            end else if (RegWEn_WB && (DestReg_WB != 5'd0) && (DestReg_WB == rt_EX)) begin
                ForwardB_EX = FWD_WB;
            end
        end
    end

    // Stall/flush policy.
    // EX-stage redirect is older than the instruction currently in ID, so it
    // has priority and flushes both younger visible stages.  Load-use stalls
    // only when no older redirect is being taken.
    always @(*) begin
        Stall_PC    = 1'b0;
        Stall_IF_ID = 1'b0;
        Flush_IF_ID = 1'b0;
        Flush_ID_EX = 1'b0;

        if (PCRedirect_EX) begin
            Flush_IF_ID = 1'b1;
            Flush_ID_EX = 1'b1;
        end else if (load_use_hazard) begin
            Stall_PC    = 1'b1;
            Stall_IF_ID = 1'b1;
            Flush_ID_EX = 1'b1;
        end
    end
endmodule
