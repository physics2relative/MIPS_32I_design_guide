#!/usr/bin/env python3
"""Generate a small MIPS single-cycle top smoke program and golden checks.

This is not an exhaustive ISA test.  It is a deterministic top-integration
smoke test that exercises representative datapaths:
- I-type ALU immediates: addi, andi, ori, lui
- R-type ALU: add, sub, sll
- data memory: sw/lw
- PC control: beq taken, j, jal/link

Outputs are written under test_vectors/generated/top_smoke/:
- program.hex : instruction words for instruction_memory ($readmemh)
- checks.mem  : packed golden checks consumed by the Verilog testbench
- checks.csv  : human-readable check list
- program.csv : human-readable program listing
- run_cycles.txt : cycle count used by the testbench run script
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Dict, List, Tuple

MASK32 = 0xFFFF_FFFF

# checks.mem packed format, MSB -> LSB:
#   { kind[3:0], index[7:0], expected[31:0] }
# kind=1: register index, kind=2: data-memory word index.
KIND_REG = 1
KIND_MEM_WORD = 2


def u32(value: int) -> int:
    return value & MASK32


def s16(value: int) -> int:
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def s32(value: int) -> int:
    value &= MASK32
    return value - 0x1_0000_0000 if value & 0x8000_0000 else value


def enc_r(rs: int, rt: int, rd: int, shamt: int, funct: int) -> int:
    return ((rs & 0x1F) << 21) | ((rt & 0x1F) << 16) | ((rd & 0x1F) << 11) | ((shamt & 0x1F) << 6) | (funct & 0x3F)


def enc_i(opcode: int, rs: int, rt: int, imm: int) -> int:
    return ((opcode & 0x3F) << 26) | ((rs & 0x1F) << 21) | ((rt & 0x1F) << 16) | (imm & 0xFFFF)


def enc_j(opcode: int, target_word_index: int) -> int:
    return ((opcode & 0x3F) << 26) | (target_word_index & 0x03FF_FFFF)


def build_program() -> List[Tuple[int, str]]:
    """Return [(instruction_word, asm)].  PC starts at byte address 0."""
    return [
        (enc_i(0x08, 0, 1, 5),          "addi $1,$0,5"),
        (enc_i(0x08, 0, 2, 7),          "addi $2,$0,7"),
        (enc_r(1, 2, 3, 0, 0x20),       "add  $3,$1,$2"),
        (enc_r(3, 1, 4, 0, 0x22),       "sub  $4,$3,$1"),
        (enc_i(0x0C, 3, 5, 0x000F),     "andi $5,$3,0x000f"),
        (enc_i(0x0D, 0, 6, 0x00F0),     "ori  $6,$0,0x00f0"),
        (enc_i(0x2B, 0, 3, 0),          "sw   $3,0($0)"),
        (enc_i(0x23, 0, 7, 0),          "lw   $7,0($0)"),
        (enc_i(0x04, 7, 3, 1),          "beq  $7,$3,+1"),
        (enc_i(0x08, 0, 8, 0x1111),     "addi $8,$0,0x1111  # skipped"),
        (enc_i(0x08, 0, 8, 0x2222),     "addi $8,$0,0x2222"),
        (enc_j(0x02, 13),               "j    13"),
        (enc_i(0x08, 0, 9, 0x3333),     "addi $9,$0,0x3333  # skipped"),
        (enc_j(0x03, 15),               "jal  15"),
        (enc_i(0x08, 0, 10, 0x4444),    "addi $10,$0,0x4444 # skipped"),
        (enc_i(0x08, 31, 11, 4),        "addi $11,$31,4"),
        (enc_i(0x0F, 0, 12, 0x1234),    "lui  $12,0x1234"),
        (enc_i(0x0D, 12, 12, 0x5678),   "ori  $12,$12,0x5678"),
        (enc_r(0, 1, 13, 2, 0x00),      "sll  $13,$1,2"),
        (0x00000000,                    "nop"),
        (0x00000000,                    "nop"),
    ]


def mem_read_word(mem: Dict[int, int], addr: int) -> int:
    base = addr & ~0x3
    return u32(
        (mem.get(base + 0, 0) << 0)
        | (mem.get(base + 1, 0) << 8)
        | (mem.get(base + 2, 0) << 16)
        | (mem.get(base + 3, 0) << 24)
    )


def mem_write_word(mem: Dict[int, int], addr: int, value: int) -> None:
    base = addr & ~0x3
    value = u32(value)
    mem[base + 0] = (value >> 0) & 0xFF
    mem[base + 1] = (value >> 8) & 0xFF
    mem[base + 2] = (value >> 16) & 0xFF
    mem[base + 3] = (value >> 24) & 0xFF


def emulate(program: List[Tuple[int, str]], run_cycles: int) -> Tuple[List[int], Dict[int, int], List[Dict[str, object]]]:
    regs = [0] * 32
    mem: Dict[int, int] = {}
    pc = 0
    trace: List[Dict[str, object]] = []

    for cycle in range(run_cycles):
        idx = (pc >> 2) & 0xFFFF_FFFF
        inst = program[idx][0] if 0 <= idx < len(program) else 0
        asm = program[idx][1] if 0 <= idx < len(program) else "nop(out-of-program)"
        opcode = (inst >> 26) & 0x3F
        rs = (inst >> 21) & 0x1F
        rt = (inst >> 16) & 0x1F
        rd = (inst >> 11) & 0x1F
        shamt = (inst >> 6) & 0x1F
        funct = inst & 0x3F
        imm = inst & 0xFFFF
        target = inst & 0x03FF_FFFF
        next_pc = u32(pc + 4)
        write_reg = 0
        write_val = 0
        wrote = False

        if opcode == 0x00:
            if funct == 0x20 or funct == 0x21:  # add/addu
                write_reg, write_val, wrote = rd, u32(regs[rs] + regs[rt]), True
            elif funct == 0x22 or funct == 0x23:  # sub/subu
                write_reg, write_val, wrote = rd, u32(regs[rs] - regs[rt]), True
            elif funct == 0x24:  # and
                write_reg, write_val, wrote = rd, regs[rs] & regs[rt], True
            elif funct == 0x25:  # or
                write_reg, write_val, wrote = rd, regs[rs] | regs[rt], True
            elif funct == 0x26:  # xor
                write_reg, write_val, wrote = rd, regs[rs] ^ regs[rt], True
            elif funct == 0x27:  # nor
                write_reg, write_val, wrote = rd, u32(~(regs[rs] | regs[rt])), True
            elif funct == 0x2A:  # slt
                write_reg, write_val, wrote = rd, 1 if s32(regs[rs]) < s32(regs[rt]) else 0, True
            elif funct == 0x2B:  # sltu
                write_reg, write_val, wrote = rd, 1 if regs[rs] < regs[rt] else 0, True
            elif funct == 0x00:  # sll / nop
                write_reg, write_val, wrote = rd, u32(regs[rt] << shamt), True
            elif funct == 0x02:  # srl
                write_reg, write_val, wrote = rd, u32(regs[rt] >> shamt), True
            elif funct == 0x03:  # sra
                write_reg, write_val, wrote = rd, u32(s32(regs[rt]) >> shamt), True
            elif funct == 0x08:  # jr
                next_pc = regs[rs]
            elif funct == 0x09:  # jalr
                write_reg, write_val, wrote = rd, u32(pc + 4), True
                next_pc = regs[rs]
        elif opcode == 0x08 or opcode == 0x09:  # addi/addiu
            write_reg, write_val, wrote = rt, u32(regs[rs] + s16(imm)), True
        elif opcode == 0x0C:  # andi
            write_reg, write_val, wrote = rt, regs[rs] & imm, True
        elif opcode == 0x0D:  # ori
            write_reg, write_val, wrote = rt, regs[rs] | imm, True
        elif opcode == 0x0E:  # xori
            write_reg, write_val, wrote = rt, regs[rs] ^ imm, True
        elif opcode == 0x0F:  # lui
            write_reg, write_val, wrote = rt, u32(imm << 16), True
        elif opcode == 0x23:  # lw
            write_reg, write_val, wrote = rt, mem_read_word(mem, u32(regs[rs] + s16(imm))), True
        elif opcode == 0x2B:  # sw
            mem_write_word(mem, u32(regs[rs] + s16(imm)), regs[rt])
        elif opcode == 0x04:  # beq
            if regs[rs] == regs[rt]:
                next_pc = u32(pc + 4 + (s16(imm) << 2))
        elif opcode == 0x05:  # bne
            if regs[rs] != regs[rt]:
                next_pc = u32(pc + 4 + (s16(imm) << 2))
        elif opcode == 0x02:  # j
            next_pc = u32(((pc + 4) & 0xF0000000) | (target << 2))
        elif opcode == 0x03:  # jal
            write_reg, write_val, wrote = 31, u32(pc + 4), True
            next_pc = u32(((pc + 4) & 0xF0000000) | (target << 2))

        if wrote and write_reg != 0:
            regs[write_reg] = u32(write_val)
        regs[0] = 0
        trace.append({"cycle": cycle, "pc": pc, "inst": inst, "asm": asm, "next_pc": next_pc})
        pc = next_pc

    return regs, mem, trace


def pack_check(kind: int, index: int, expected: int) -> int:
    return ((kind & 0xF) << 40) | ((index & 0xFF) << 32) | u32(expected)


def write_outputs(root: Path, run_cycles: int) -> Path:
    program = build_program()
    regs, mem, trace = emulate(program, run_cycles)
    out_dir = root / "test_vectors" / "generated" / "top_smoke"
    out_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "program.hex").write_text("".join(f"{word:08X}\n" for word, _asm in program), encoding="utf-8")
    (out_dir / "run_cycles.txt").write_text(f"{run_cycles}\n", encoding="utf-8")

    with (out_dir / "program.csv").open("w", newline="", encoding="utf-8") as fp:
        writer = csv.writer(fp)
        writer.writerow(["index", "pc", "instruction_hex", "asm"])
        for index, (word, asm) in enumerate(program):
            writer.writerow([index, f"0x{index * 4:08X}", f"0x{word:08X}", asm])

    with (out_dir / "trace.csv").open("w", newline="", encoding="utf-8") as fp:
        writer = csv.writer(fp)
        writer.writerow(["cycle", "pc", "instruction_hex", "asm", "next_pc"])
        for item in trace:
            writer.writerow([
                item["cycle"], f"0x{item['pc']:08X}", f"0x{item['inst']:08X}", item["asm"], f"0x{item['next_pc']:08X}",
            ])

    checks: List[Tuple[int, int, int, str]] = []
    for reg_index in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 31]:
        checks.append((KIND_REG, reg_index, regs[reg_index], f"reg${reg_index}"))
    checks.append((KIND_MEM_WORD, 0, mem_read_word(mem, 0), "dmem_word[0]"))

    (out_dir / "checks.mem").write_text(
        "".join(f"{pack_check(kind, index, expected):011X}\n" for kind, index, expected, _name in checks),
        encoding="utf-8",
    )

    with (out_dir / "checks.csv").open("w", newline="", encoding="utf-8") as fp:
        writer = csv.writer(fp)
        writer.writerow(["kind", "index", "name", "expected_hex", "expected_dec"])
        for kind, index, expected, name in checks:
            writer.writerow([kind, index, name, f"0x{expected:08X}", expected])

    return out_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate MIPS top smoke program/check vectors")
    parser.add_argument("--root", default=".", help="project root")
    parser.add_argument("--run-cycles", type=int, default=24, help="single-cycle clocks after reset release")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    out_dir = write_outputs(root, args.run_cycles)
    print(f"top_smoke: out={out_dir.relative_to(root)} run_cycles={args.run_cycles}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
