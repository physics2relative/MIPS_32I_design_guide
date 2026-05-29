`ifndef MIPS_CRT_ADAPTER_VH
`define MIPS_CRT_ADAPTER_VH

// =============================================================
// MIPS CRTv3 DUT adapter contract
// -------------------------------------------------------------
// Include this file from tb_MIPS_CRT_v3.v after instantiating the DUT
// with instance name `uut`.
//
// Purpose:
//   - Keep the common MIPS CRT/golden testbench independent from the
//     concrete Single Cycle or future Pipeline hierarchy.
//   - Preserve existing DUT RTL behavior: this file is testbench-only glue.
//
// Default target:
//   - Single Cycle is selected unless MIPS_CRT_DUT_PIPELINE is defined.
//
// Hard boundaries from mips-crt-v3-ralplan.md:
//   - Do not modify Pipeline RTL in the first CRT pass.
//   - Do not redesign DUT timing or memory timing for CRT.
//   - Do not edit Logisim circuits or existing block-level testvectors.
//   - If an RTL-side mismatch is found, report evidence before RTL fixes.
// =============================================================

`ifndef MIPS_CRT_DUT_PIPELINE
`ifndef MIPS_CRT_DUT_SINGLE
`define MIPS_CRT_DUT_SINGLE
`endif
`endif

// Common constants. The CRT may override loop bounds with parameters, but
// these names keep default memory initialization/comparison consistent.
`define MIPS_CRT_NOP_WORD             32'h0000_0000  // sll $0,$0,0
`define MIPS_CRT_DEFAULT_IMEM_WORDS   4096
`define MIPS_CRT_DEFAULT_DMEM_BYTES   256

`ifdef MIPS_CRT_DUT_SINGLE
// -------------------------------------------------------------
// Current Single Cycle contract
// -------------------------------------------------------------
// Required DUT hierarchy, already present in mips_single_cycle_top:
//   uut.u_imem.u_bram.mem[index]   : instruction word array
//   uut.u_dmem.u_bram.mem[index]   : data word array
//   uut.u_regfile.regs[index]      : register file array
//   uut.dbg_pc/dbg_inst/...        : debug/observability ports

`define MIPS_CRT_DUT_IMEM_WORD(IDX)      uut.u_imem.u_bram.mem[(IDX)]
`define MIPS_CRT_DUT_DMEM_WORD(IDX)      uut.u_dmem.u_bram.mem[(IDX)]
`define MIPS_CRT_DUT_REG(IDX)            uut.u_regfile.regs[(IDX)]

`define MIPS_CRT_DUT_PC                  uut.dbg_pc
`define MIPS_CRT_DUT_INST                uut.dbg_inst
`define MIPS_CRT_DUT_NEXT_PC             uut.dbg_next_pc
`define MIPS_CRT_DUT_REG_WEN             uut.dbg_reg_wen
`define MIPS_CRT_DUT_WRITE_REG           uut.dbg_write_reg
`define MIPS_CRT_DUT_WDATA               uut.dbg_wdata
`define MIPS_CRT_DUT_ALU_RESULT          uut.dbg_alu_result
`define MIPS_CRT_DUT_BRANCH_TAKEN        uut.dbg_branch_taken
`define MIPS_CRT_DUT_PCSEL               uut.dbg_pcsel

// Single Cycle has no separate retire/WB valid signal. The CRT should wait
// for the current PC to reach the generated halt PC, then allow a small
// settle/drain interval before final state comparison.
`define MIPS_CRT_DUT_HAS_RETIRE          1'b0
`define MIPS_CRT_DUT_RETIRE_VALID        1'b1
`define MIPS_CRT_DUT_RETIRE_PC           `MIPS_CRT_DUT_PC
`define MIPS_CRT_DUT_RETIRE_INST         `MIPS_CRT_DUT_INST

`elsif MIPS_CRT_DUT_PIPELINE
// -------------------------------------------------------------
// Future 5-stage Pipeline contract placeholder
// -------------------------------------------------------------
// This branch is a contract only in the first CRT pass. It must not be used
// as evidence that Pipeline RTL is implemented. When Pipeline RTL exists, it
// should expose the following hierarchy/signals or adapt this section only:
//   uut.u_imem.u_bram.mem[index]
//   uut.u_dmem.u_bram.mem[index]
//   uut.u_regfile.regs[index]
//   uut.dbg_wb_valid
//   uut.dbg_wb_pc
//   uut.dbg_wb_inst
//   uut.dbg_wb_reg_wen
//   uut.dbg_wb_write_reg
//   uut.dbg_wb_wdata

`define MIPS_CRT_DUT_IMEM_WORD(IDX)      uut.u_imem.u_bram.mem[(IDX)]
`define MIPS_CRT_DUT_DMEM_WORD(IDX)      uut.u_dmem.u_bram.mem[(IDX)]
`define MIPS_CRT_DUT_REG(IDX)            uut.u_regfile.regs[(IDX)]

`define MIPS_CRT_DUT_PC                  uut.dbg_wb_pc
`define MIPS_CRT_DUT_INST                uut.dbg_wb_inst
`define MIPS_CRT_DUT_REG_WEN             uut.dbg_wb_reg_wen
`define MIPS_CRT_DUT_WRITE_REG           uut.dbg_wb_write_reg
`define MIPS_CRT_DUT_WDATA               uut.dbg_wb_wdata

// Optional single-cycle debug context is not part of the minimum
// Pipeline retire contract. Keep these macros defined so the common CRT
// failure printer remains compile-safe until Pipeline exposes richer debug.
`define MIPS_CRT_DUT_NEXT_PC             32'h0000_0000
`define MIPS_CRT_DUT_ALU_RESULT          32'h0000_0000
`define MIPS_CRT_DUT_BRANCH_TAKEN        1'b0
`define MIPS_CRT_DUT_PCSEL               2'b00

`define MIPS_CRT_DUT_HAS_RETIRE          1'b1
`define MIPS_CRT_DUT_RETIRE_VALID        uut.dbg_wb_valid
`define MIPS_CRT_DUT_RETIRE_PC           uut.dbg_wb_pc
`define MIPS_CRT_DUT_RETIRE_INST         uut.dbg_wb_inst

`else
// Keep this as a simulation-time failure instead of a SystemVerilog `error
// directive, so the include remains ordinary-Verilog friendly.
initial begin
    $display("MIPS_CRT_ADAPTER_ERROR: define MIPS_CRT_DUT_SINGLE or MIPS_CRT_DUT_PIPELINE");
    $finish;
end
`endif

// -------------------------------------------------------------
// Helper macros shared by Single Cycle and future Pipeline mode.
// These expand to lvalues/expressions and are intended for procedural use
// inside the CRT testbench.
// -------------------------------------------------------------
`define MIPS_CRT_DUT_WRITE_IMEM(IDX, VALUE) \
    `MIPS_CRT_DUT_IMEM_WORD(IDX) = (VALUE)

`define MIPS_CRT_DUT_WRITE_DMEM_WORD(IDX, VALUE) \
    `MIPS_CRT_DUT_DMEM_WORD(IDX) = (VALUE)

`define MIPS_CRT_DUT_READ_DMEM_BYTE(BYTE_IDX) \
    ((`MIPS_CRT_DUT_DMEM_WORD(((BYTE_IDX) >> 2)) >> (8 * ((BYTE_IDX) & 2'b11))) & 32'h0000_00ff)

`define MIPS_CRT_DUT_CLEAR_IMEM_WORD(IDX) \
    `MIPS_CRT_DUT_WRITE_IMEM((IDX), `MIPS_CRT_NOP_WORD)

`define MIPS_CRT_DUT_CLEAR_DMEM_WORD(IDX) \
    `MIPS_CRT_DUT_WRITE_DMEM_WORD((IDX), 32'h0000_0000)

`endif // MIPS_CRT_ADAPTER_VH
