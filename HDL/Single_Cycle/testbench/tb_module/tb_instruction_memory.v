`timescale 1ns/1ps

module tb_instruction_memory;
    reg [31:0] Addr;
    wire [31:0] Inst;

    wire [5:0]  opcode;
    wire [4:0]  rs;
    wire [4:0]  rt;
    wire [4:0]  rd;
    wire [4:0]  shamt;
    wire [5:0]  funct;
    wire [15:0] imm16;
    wire [25:0] target26;

    integer errors;

    instruction_memory #(.INIT_FILE(""), .MEM_AW(4)) dut (
        .Addr(Addr),
        .Inst(Inst)
    );

    instruction_splitter u_inst_splitter (
        .Inst(Inst),
        .opcode(opcode),
        .rs(rs),
        .rt(rt),
        .rd(rd),
        .shamt(shamt),
        .funct(funct),
        .imm16(imm16),
        .target26(target26)
    );

    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_instruction_memory, "ACMTF");
        errors = 0;

        Addr = 32'h0000_0000; #1;
        if (Inst !== 32'h0000_0000) begin errors = errors + 1; $display("IMEM_FAIL addr0 got=%08h", Inst); end

        // add $t0,$t1,$t2 = 000000_01001_01010_01000_00000_100000
        dut.u_bram.mem[0] = 32'h012A_4020;
        // lw $t1,0($a0) = 100011_00100_01001_0000000000000000
        dut.u_bram.mem[1] = 32'h8C89_0000;
        // j 0x00000010 = 000010_000000000000000000000100
        dut.u_bram.mem[2] = 32'h0800_0004;

        Addr = 32'h0000_0000; #1;
        if (Inst !== 32'h012A_4020) begin errors = errors + 1; $display("IMEM_FAIL addr0 got=%08h", Inst); end
        if (opcode !== 6'h00 || rs !== 5'd9 || rt !== 5'd10 || rd !== 5'd8 || shamt !== 5'd0 || funct !== 6'h20 || imm16 !== 16'h4020 || target26 !== 26'h12A4020) begin
            errors = errors + 1;
            $display("INST_SPLITTER_FAIL add fields op=%h rs=%0d rt=%0d rd=%0d shamt=%0d funct=%h imm=%h target=%h", opcode, rs, rt, rd, shamt, funct, imm16, target26);
        end

        Addr = 32'h0000_0004; #1;
        if (Inst !== 32'h8C89_0000) begin errors = errors + 1; $display("IMEM_FAIL addr4 got=%08h", Inst); end
        if (opcode !== 6'h23 || rs !== 5'd4 || rt !== 5'd9 || imm16 !== 16'h0000 || target26 !== 26'h0890000) begin
            errors = errors + 1;
            $display("INST_SPLITTER_FAIL lw fields op=%h rs=%0d rt=%0d imm=%h target=%h", opcode, rs, rt, imm16, target26);
        end

        Addr = 32'h0000_0008; #1;
        if (Inst !== 32'h0800_0004) begin errors = errors + 1; $display("IMEM_FAIL addr8 got=%08h", Inst); end
        if (opcode !== 6'h02 || target26 !== 26'h0000004) begin
            errors = errors + 1;
            $display("INST_SPLITTER_FAIL jump fields op=%h target=%h", opcode, target26);
        end

        if (errors == 0) $display("INSTRUCTION_MEMORY_SMOKE_PASS");
        else $display("INSTRUCTION_MEMORY_SMOKE_FAIL errors=%0d", errors);
        $finish;
    end
endmodule
