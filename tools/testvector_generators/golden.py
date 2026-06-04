#!/usr/bin/env python3
"""Golden reference functions for the MIPS Logisim block-level vectors.

The functions in this file intentionally use only Python's standard library so
that the vectors can be regenerated on the EDA server without package installs.
All arithmetic is masked to 32-bit where a Logisim datapath signal is 32-bit.
"""
from __future__ import annotations

import csv
import filecmp
import shutil
import tempfile
from pathlib import Path

MASK32 = 0xFFFFFFFF

DEST = {"RT": 0b00, "RD": 0b01, "RA": 0b10, "NONE": 0b11}
WB = {"MEM": 0b00, "ALU": 0b01, "PC4": 0b10, "NONE": 0b11}
ASEL = {"RS": 0b00, "PC4": 0b01, "ZERO": 0b10, "RT": 0b11}
BSEL = {"RT": 0b000, "IMM": 0b001, "SHAMT": 0b010, "RS_LOW5": 0b011, "ZERO": 0b100, "RESERVED5": 0b101, "RESERVED6": 0b110, "NONE": 0b111}
IMMSEL = {"SIGN16": 0b00, "ZERO16": 0b01, "LUI16": 0b10, "BRANCH16": 0b11}
BRSEL = {"EQ": 0b0, "NE": 0b1}
ALU = {"ADD": 0b0000, "SUB": 0b0001, "AND": 0b0010, "OR": 0b0011, "XOR": 0b0100, "SLT": 0b0101, "SLTU": 0b0110, "SLL": 0b0111, "SRL": 0b1000, "SRA": 0b1001, "NOR": 0b1010, "ABS": 0b1011, "NONE": 0b1111}
WDLEN = {"BYTE": 0b00, "HALF": 0b01, "WORD": 0b10, "NONE": 0b11}
MEMRW = {"IDLE": 0b00, "LOAD": 0b01, "STORE": 0b10}
PCSEL = {"PC_PLUS4": 0b00, "PC_BRANCH": 0b01, "PC_JUMP": 0b10, "RESERVED": 0b11}


def u32(value: int) -> int:
    return value & MASK32


def s32(value: int) -> int:
    value &= MASK32
    return value - 0x100000000 if value & 0x80000000 else value


def sign_extend(value: int, bits: int) -> int:
    sign = 1 << (bits - 1)
    value &= (1 << bits) - 1
    return u32((value ^ sign) - sign)


def zero_extend(value: int, bits: int) -> int:
    return value & ((1 << bits) - 1)


def hex32(value: int) -> str:
    return f"0x{u32(value):08X}"


def hexn(value: int, width_bits: int) -> str:
    digits = max(1, (width_bits + 3) // 4)
    return f"0x{value & ((1 << width_bits) - 1):0{digits}X}"


def bin_n(value: int, width: int) -> str:
    return format(value & ((1 << width) - 1), f"0{width}b")


def alu_result(a: int, b: int, sel: int) -> int:
    a = u32(a)
    b = u32(b)
    shamt = b & 0x1F
    if sel == ALU["ADD"]:
        return u32(a + b)
    if sel == ALU["SUB"]:
        return u32(a - b)
    if sel == ALU["AND"]:
        return a & b
    if sel == ALU["OR"]:
        return a | b
    if sel == ALU["XOR"]:
        return a ^ b
    if sel == ALU["SLT"]:
        return 1 if s32(a) < s32(b) else 0
    if sel == ALU["SLTU"]:
        return 1 if a < b else 0
    if sel == ALU["SLL"]:
        return u32(a << shamt)
    if sel == ALU["SRL"]:
        return u32(a >> shamt)
    if sel == ALU["SRA"]:
        return u32(s32(a) >> shamt)
    if sel == ALU["NOR"]:
        return u32(~(a | b))
    if sel == ALU["ABS"]:
        return u32(-s32(a)) if s32(a) < 0 else a
    if sel == ALU["NONE"]:
        return 0
    raise ValueError(f"unknown ALUSel {sel}")


def imm_values(imm16: int, target26: int, pc_plus4: int) -> dict:
    del target26, pc_plus4
    sign16 = sign_extend(imm16, 16)
    return {
        "ImmSign16": sign16,
        "ImmZero16": zero_extend(imm16, 16),
        "ImmLui16": u32((imm16 & 0xFFFF) << 16),
        "ImmBranch16": u32(sign16 << 2),
    }


def imm_by_sel(imm16: int, target26: int, pc_plus4: int, imm_sel: int) -> int:
    vals = imm_values(imm16, target26, pc_plus4)
    if imm_sel == IMMSEL["SIGN16"]:
        return vals["ImmSign16"]
    if imm_sel == IMMSEL["ZERO16"]:
        return vals["ImmZero16"]
    if imm_sel == IMMSEL["LUI16"]:
        return vals["ImmLui16"]
    if imm_sel == IMMSEL["BRANCH16"]:
        return vals["ImmBranch16"]
    return 0


def select_a(data_rs: int, data_rt: int, pc_plus4: int, a_sel: int) -> int:
    return {
        ASEL["RS"]: u32(data_rs),
        ASEL["PC4"]: u32(pc_plus4),
        ASEL["ZERO"]: 0,
        ASEL["RT"]: u32(data_rt),
    }.get(a_sel, 0)


def select_b(data_rs: int, data_rt: int, imm_val: int, shamt: int, b_sel: int) -> int:
    return {
        BSEL["RT"]: u32(data_rt),
        BSEL["IMM"]: u32(imm_val),
        BSEL["SHAMT"]: shamt & 0x1F,
        BSEL["RS_LOW5"]: data_rs & 0x1F,
        BSEL["ZERO"]: 0,
        BSEL["RESERVED5"]: 0,
        BSEL["RESERVED6"]: 0,
        BSEL["NONE"]: 0,
    }.get(b_sel, 0)


def dest_reg(rt: int, rd: int, dest_sel: int) -> int:
    if dest_sel == DEST["RT"]:
        return rt & 0x1F
    if dest_sel == DEST["RD"]:
        return rd & 0x1F
    if dest_sel == DEST["RA"]:
        return 31
    return 0


def branch_taken_raw(data_rs: int, data_rt: int, br_sel: int) -> int:
    eq = u32(data_rs) == u32(data_rt)
    if br_sel == BRSEL["EQ"]:
        return 1 if eq else 0
    if br_sel == BRSEL["NE"]:
        return 0 if eq else 1
    return 0


def jump_imm_target(pc_plus4: int, target26: int) -> int:
    return u32((pc_plus4 & 0xF0000000) | ((target26 & 0x03FFFFFF) << 2))


def selected_jump_target(pc_plus4: int, target26: int, data_rs: int, jump_sel: int) -> int:
    return jump_imm_target(pc_plus4, target26) if jump_sel == 0 else u32(data_rs)


def pc_control(branch: int, jump: int, branch_taken: int) -> int:
    if jump:
        return PCSEL["PC_JUMP"]
    if branch and branch_taken:
        return PCSEL["PC_BRANCH"]
    return PCSEL["PC_PLUS4"]


def wb_data(data_rd: int, alu: int, pc_plus4: int, wb_sel: int) -> int:
    return {
        WB["MEM"]: u32(data_rd),
        WB["ALU"]: u32(alu),
        WB["PC4"]: u32(pc_plus4),
        WB["NONE"]: 0,
    }.get(wb_sel, 0)


def word_to_bytes(word: int) -> list[int]:
    word = u32(word)
    return [(word >> (8 * i)) & 0xFF for i in range(4)]


def bytes_to_word(bytes_le: list[int]) -> int:
    out = 0
    for i, byte in enumerate(bytes_le[:4]):
        out |= (byte & 0xFF) << (8 * i)
    return u32(out)


def data_memory_result(initial_word: int, addr: int, data_rt: int, wd_len: int, memrw: int, load_ex: int) -> dict:
    lane = addr & 0x3
    b = word_to_bytes(initial_word)
    is_load = memrw == MEMRW["LOAD"]
    is_store = memrw == MEMRW["STORE"]
    is_mem = is_load or is_store
    misaligned = int(is_mem and (
        (wd_len == WDLEN["HALF"] and (addr & 0x1) != 0) or
        (wd_len == WDLEN["WORD"] and (addr & 0x3) != 0)
    ))
    write_enable = 1 if is_store and not misaligned and wd_len != WDLEN["NONE"] else 0
    new_word = u32(initial_word)
    data_rd = 0

    if is_load and not misaligned:
        if wd_len == WDLEN["BYTE"]:
            raw = b[lane]
            data_rd = raw if load_ex else sign_extend(raw, 8)
        elif wd_len == WDLEN["HALF"]:
            half_lane = lane & 0x2
            raw = b[half_lane] | (b[half_lane + 1] << 8)
            data_rd = raw if load_ex else sign_extend(raw, 16)
        elif wd_len == WDLEN["WORD"]:
            data_rd = u32(initial_word)
    elif is_store and not misaligned:
        if wd_len == WDLEN["BYTE"]:
            b[lane] = data_rt & 0xFF
            new_word = bytes_to_word(b)
        elif wd_len == WDLEN["HALF"]:
            half_lane = lane & 0x2
            b[half_lane] = data_rt & 0xFF
            b[half_lane + 1] = (data_rt >> 8) & 0xFF
            new_word = bytes_to_word(b)
        elif wd_len == WDLEN["WORD"]:
            new_word = u32(data_rt)
    return {"WriteEnable": write_enable, "MisalignedAccess": misaligned, "Data_RD": u32(data_rd), "ExpectedNewWord": u32(new_word), "Lane": lane}


def control_rows() -> list[dict]:
    n = {"RegWEn": 0, "DestSel": DEST["NONE"], "ASel": ASEL["ZERO"], "BSel": BSEL["ZERO"], "ImmSel": IMMSEL["SIGN16"], "BrSel": BRSEL["EQ"], "ALUSel": ALU["NONE"], "WBSel": WB["NONE"], "WdLen": WDLEN["NONE"], "MemRW": MEMRW["IDLE"], "LoadEx": 0, "Branch": 0, "Jump": 0, "JumpSel": 0}
    rows = []

    def add(instr, opcode, funct, **kw):
        r = dict(n)
        r.update(kw)
        r.update({"Instruction": instr, "opcode": opcode, "funct": funct})
        rows.append(r)

    r_common = {"RegWEn": 1, "DestSel": DEST["RD"], "ASel": ASEL["RS"], "BSel": BSEL["RT"], "WBSel": WB["ALU"]}
    for instr, funct, alu in [
        ("add", 0x20, "ADD"), ("addu", 0x21, "ADD"), ("sub", 0x22, "SUB"), ("subu", 0x23, "SUB"),
        ("and", 0x24, "AND"), ("or", 0x25, "OR"), ("xor", 0x26, "XOR"), ("nor", 0x27, "NOR"),
        ("slt", 0x2A, "SLT"), ("sltu", 0x2B, "SLTU")]:
        add(instr, 0x00, funct, **r_common, ALUSel=ALU[alu])
    add("abs", 0x00, 0x2C, RegWEn=1, DestSel=DEST["RD"], ASel=ASEL["RS"], BSel=BSEL["ZERO"], ALUSel=ALU["ABS"], WBSel=WB["ALU"])
    for instr, funct, alu in [("sll", 0x00, "SLL"), ("srl", 0x02, "SRL"), ("sra", 0x03, "SRA")]:
        add(instr, 0x00, funct, RegWEn=1, DestSel=DEST["RD"], ASel=ASEL["RT"], BSel=BSEL["SHAMT"], ALUSel=ALU[alu], WBSel=WB["ALU"])
    for instr, funct, alu in [("sllv", 0x04, "SLL"), ("srlv", 0x06, "SRL"), ("srav", 0x07, "SRA")]:
        add(instr, 0x00, funct, RegWEn=1, DestSel=DEST["RD"], ASel=ASEL["RT"], BSel=BSEL["RS_LOW5"], ALUSel=ALU[alu], WBSel=WB["ALU"])
    for instr, opcode, imm_sel, alu in [("addi", 0x08, "SIGN16", "ADD"), ("addiu", 0x09, "SIGN16", "ADD"), ("andi", 0x0C, "ZERO16", "AND"), ("ori", 0x0D, "ZERO16", "OR"), ("xori", 0x0E, "ZERO16", "XOR"), ("slti", 0x0A, "SIGN16", "SLT"), ("sltiu", 0x0B, "SIGN16", "SLTU")]:
        add(instr, opcode, None, RegWEn=1, DestSel=DEST["RT"], ASel=ASEL["RS"], BSel=BSEL["IMM"], ImmSel=IMMSEL[imm_sel], ALUSel=ALU[alu], WBSel=WB["ALU"])
    add("lui", 0x0F, None, RegWEn=1, DestSel=DEST["RT"], ASel=ASEL["ZERO"], BSel=BSEL["IMM"], ImmSel=IMMSEL["LUI16"], ALUSel=ALU["ADD"], WBSel=WB["ALU"])
    for instr, opcode, wd, load_ex in [("lb", 0x20, "BYTE", 0), ("lbu", 0x24, "BYTE", 1), ("lh", 0x21, "HALF", 0), ("lhu", 0x25, "HALF", 1), ("lw", 0x23, "WORD", 0)]:
        add(instr, opcode, None, RegWEn=1, DestSel=DEST["RT"], ASel=ASEL["RS"], BSel=BSEL["IMM"], ImmSel=IMMSEL["SIGN16"], ALUSel=ALU["ADD"], WBSel=WB["MEM"], WdLen=WDLEN[wd], MemRW=MEMRW["LOAD"], LoadEx=load_ex)
    for instr, opcode, wd in [("sb", 0x28, "BYTE"), ("sh", 0x29, "HALF"), ("sw", 0x2B, "WORD")]:
        add(instr, opcode, None, ASel=ASEL["RS"], BSel=BSEL["IMM"], ImmSel=IMMSEL["SIGN16"], ALUSel=ALU["ADD"], WdLen=WDLEN[wd], MemRW=MEMRW["STORE"])
    add("beq", 0x04, None, ASel=ASEL["PC4"], BSel=BSEL["IMM"], ImmSel=IMMSEL["BRANCH16"], BrSel=BRSEL["EQ"], ALUSel=ALU["ADD"], Branch=1)
    add("bne", 0x05, None, ASel=ASEL["PC4"], BSel=BSEL["IMM"], ImmSel=IMMSEL["BRANCH16"], BrSel=BRSEL["NE"], ALUSel=ALU["ADD"], Branch=1)
    add("j", 0x02, None, BSel=BSEL["NONE"], ImmSel=IMMSEL["SIGN16"], Jump=1, JumpSel=0)
    add("jal", 0x03, None, RegWEn=1, DestSel=DEST["RA"], BSel=BSEL["NONE"], ImmSel=IMMSEL["SIGN16"], WBSel=WB["PC4"], Jump=1, JumpSel=0)
    add("jr", 0x00, 0x08, ASel=ASEL["RS"], BSel=BSEL["NONE"], Jump=1, JumpSel=1)
    add("jalr", 0x00, 0x09, RegWEn=1, DestSel=DEST["RD"], ASel=ASEL["RS"], BSel=BSEL["NONE"], WBSel=WB["PC4"], Jump=1, JumpSel=1)
    add("unknown_safe_nop", 0x3F, None)
    return rows


def write_csv(path: Path, rows: list[dict], fieldnames: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fieldnames = fieldnames or list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fieldnames})


def write_lines(path: Path, values: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(values) + "\n", encoding="utf-8")


def safe_column_filename(name: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in name)
    return safe or "column"


def parse_numeric_value(value) -> tuple[int, int] | None:
    """Parse a CSV cell value into an integer plus its natural signal width.

    Returns None for descriptive fields such as instruction names or X values.
    Width is used only for zero-padding Logisim raw-hex memory files.
    """
    if isinstance(value, int):
        return value, max(1, value.bit_length())
    s = str(value).strip()
    if not s or s.upper() in {"X", "NA", "N/A", "NONE"}:
        return None
    if s.lower().startswith("0x"):
        digits = s[2:]
        if not digits:
            return None
        return int(digits, 16), max(1, len(digits) * 4)
    if all(ch in "01" for ch in s):
        return int(s, 2), max(1, len(s))
    if s.isdecimal():
        value_int = int(s, 10)
        return value_int, max(1, value_int.bit_length())
    return None


def logisim_hex_word(value: int, width_bits: int) -> str:
    width_bits = max(1, width_bits)
    digits = max(1, (width_bits + 3) // 4)
    return f"{value & ((1 << width_bits) - 1):0{digits}X}"


def write_logisim_hex(path: Path, values: list[int], width_bits: int) -> None:
    """Write a Logisim memory-image file using the v2.0 raw hex format."""
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["v2.0 raw"]
    lines.extend(logisim_hex_word(value, width_bits) for value in values)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def numeric_column(rows: list[dict], field: str) -> tuple[list[int], int] | None:
    values: list[int] = []
    width_bits = 1
    for row in rows:
        parsed = parse_numeric_value(row.get(field, ""))
        if parsed is None:
            return None
        value, width = parsed
        values.append(value)
        width_bits = max(width_bits, width)
    return values, width_bits


LOGISIM_HEX_FIELDS = {
    "alu": ["ALUSel_bin", "A", "B", "Expected"],
    "register_file": [
        "RESET", "RegWEn", "DestSel_bin", "rt", "rd", "Addr_rs", "Addr_rt", "Data_WR",
        "Expected_WriteReg", "Expected_WriteAccepted", "Expected_Data_rs", "Expected_Data_rt",
    ],
    "imm_generator": [
        "ImmSel_bin", "imm16", "Expected_ImmVal",
    ],
    "selectors": [
        "ASel_bin", "BSel_bin", "Data_rs", "Data_rt", "PCPlus4", "ImmVal", "shamt",
        "Expected_ALU_A", "Expected_ALU_B",
    ],
    "control_unit": [
        "opcode_bin", "funct_bin", "RegWEn", "DestSel", "ASel", "BSel",
        "ImmSel", "BrSel", "ALUSel", "WBSel", "WdLen", "MemRW", "LoadEx", "Branch", "Jump", "JumpSel",
    ],
    "branch_comp": ["BrSel_bin", "Data_rs", "Data_rt", "Expected_BranchTaken"],
    "jump_target": [
        "PCPlus4", "target26", "Expected_JumpImmTarget",
    ],
    "data_memory": [
        "InitialWord", "Addr", "Data_rt", "WdLen_bin", "MemRW_bin", "LoadEx",
        "Expected_Lane", "Expected_WE", "Expected_MisalignedAccess", "Expected_Data_RD", "ExpectedNewWord",
    ],
    "wb_selector": ["WBSel_bin", "Data_RD", "ALUResult", "PCPlus4", "Expected_Data_WR"],
    "pc_control": ["Branch", "Jump", "BranchTaken", "Expected_PCSel_bin"],
}


def write_hex_files(block_dir: Path, block_name: str, rows: list[dict]) -> None:
    """Write one Logisim artifact format: curated per-signal .hex files.

    `vectors.csv` is the human-readable/source-of-truth table.  `.hex` files are
    generated only for fields that are useful as Logisim ROM inputs or expected
    comparator outputs.  No `.txt`, metadata hex, or alias duplicates are written.
    """
    if not rows:
        return
    for field in LOGISIM_HEX_FIELDS[block_name]:
        parsed = numeric_column(rows, field)
        if parsed is None:
            raise SystemExit(f"cannot generate numeric .hex for {block_name}.{field}")
        values, width_bits = parsed
        write_logisim_hex(block_dir / f"{safe_column_filename(field)}.hex", values, width_bits)


def write_block_outputs(outdir: Path, block_name: str, rows: list[dict]) -> None:
    block_dir = outdir / block_name
    write_csv(block_dir / "vectors.csv", rows)
    write_hex_files(block_dir, block_name, rows)


def alu_vectors() -> list[dict]:
    cases = [
        ("ADD", 0x00000000, 0x00000000), ("ADD", 0x00000001, 0x00000002), ("ADD", 0xFFFFFFFF, 0x00000001), ("ADD", 0x7FFFFFFF, 0x00000001),
        ("SUB", 0x00000003, 0x00000001), ("SUB", 0x00000000, 0x00000001), ("SUB", 0x80000000, 0x00000001),
        ("AND", 0xA5A5A5A5, 0x0F0F0F0F), ("OR", 0xA5000000, 0x00A500A5), ("XOR", 0xFFFF0000, 0x00FFFF00), ("NOR", 0x00000000, 0x00000000), ("NOR", 0xAAAAAAAA, 0x55555555),
        ("SLT", 0xFFFFFFFF, 0x00000001), ("SLT", 0x7FFFFFFF, 0x80000000), ("SLTU", 0xFFFFFFFF, 0x00000001), ("SLTU", 0x00000001, 0xFFFFFFFF),
        ("ABS", 0x00000000, 0x00000000), ("ABS", 0x00000001, 0x00000000), ("ABS", 0xFFFFFFFF, 0x00000000), ("ABS", 0xFFFFFFFE, 0x00000000),
        ("ABS", 0x7FFFFFFF, 0x00000000), ("ABS", 0x80000000, 0x00000000), ("ABS", 0x80000001, 0x00000000),
        ("SLL", 0x00000001, 0x0000001F), ("SLL", 0x80000001, 0x00000004), ("SRL", 0x80000000, 0x0000001F), ("SRA", 0x80000000, 0x0000001F), ("SRA", 0x7FFFFFFF, 0x00000004),
        ("NONE", 0xDEADBEEF, 0x00000000),
    ]
    rows = []
    for i, (op, a, b) in enumerate(cases):
        sel = ALU[op]
        rows.append({"case": i, "op": op, "ALUSel_bin": bin_n(sel, 4), "ALUSel_hex": hexn(sel, 4), "A": hex32(a), "B": hex32(b), "Expected": hex32(alu_result(a, b, sel))})
    return rows


def register_vectors() -> list[dict]:
    regs = [0] * 32
    stimuli = [
        {"RESET": 1, "RegWEn": 0, "DestSel": DEST["NONE"], "rt": 0, "rd": 0, "Addr_rs": 0, "Addr_rt": 1, "Data_WR": 0},
        {"RESET": 0, "RegWEn": 1, "DestSel": DEST["RT"], "rt": 1, "rd": 2, "Addr_rs": 1, "Addr_rt": 0, "Data_WR": 0x11111111},
        {"RESET": 0, "RegWEn": 1, "DestSel": DEST["RD"], "rt": 3, "rd": 4, "Addr_rs": 4, "Addr_rt": 1, "Data_WR": 0x44444444},
        {"RESET": 0, "RegWEn": 1, "DestSel": DEST["RA"], "rt": 5, "rd": 6, "Addr_rs": 31, "Addr_rt": 4, "Data_WR": 0x31313131},
        {"RESET": 0, "RegWEn": 1, "DestSel": DEST["RT"], "rt": 0, "rd": 7, "Addr_rs": 0, "Addr_rt": 31, "Data_WR": 0xFFFFFFFF},
        {"RESET": 0, "RegWEn": 0, "DestSel": DEST["NONE"], "rt": 8, "rd": 9, "Addr_rs": 8, "Addr_rt": 31, "Data_WR": 0x88888888},
    ]
    rows = []
    for cycle, s in enumerate(stimuli):
        if s["RESET"]:
            regs = [0] * 32
        wr = dest_reg(s["rt"], s["rd"], s["DestSel"])
        accepted = 1 if s["RegWEn"] and wr != 0 else 0
        if accepted:
            regs[wr] = u32(s["Data_WR"])
        regs[0] = 0
        rows.append({
            "cycle": cycle, "RESET": s["RESET"], "RegWEn": s["RegWEn"], "DestSel_bin": bin_n(s["DestSel"], 2), "rt": s["rt"], "rd": s["rd"], "Expected_WriteReg": wr,
            "Addr_rs": s["Addr_rs"], "Addr_rt": s["Addr_rt"], "Data_WR": hex32(s["Data_WR"]), "Expected_WriteAccepted": accepted,
            "Expected_Data_rs": hex32(regs[s["Addr_rs"]]), "Expected_Data_rt": hex32(regs[s["Addr_rt"]]),
        })
    return rows


def imm_vectors() -> list[dict]:
    rows = []
    cases = [(0x0000, 0x0000001, 0x00400004), (0x7FFF, 0x0001234, 0x0FFFFFFC), (0x8000, 0x3FFFFFF, 0x10000004), (0xFFFF, 0x1555555, 0x80000004)]
    for i, (imm16, target26, pc4) in enumerate(cases):
        for name, sel in [("SIGN16", IMMSEL["SIGN16"]), ("ZERO16", IMMSEL["ZERO16"]), ("LUI16", IMMSEL["LUI16"]), ("BRANCH16", IMMSEL["BRANCH16"] )]:
            imm_expected = imm_by_sel(imm16, target26, pc4, sel)
            rows.append({"case": f"{i}_{name}", "ImmSel_bin": bin_n(sel, 2), "imm16": hexn(imm16, 16), "Expected_ImmVal": hex32(imm_expected)})
    return rows


def selector_vectors() -> list[dict]:
    rows = []
    sample = {"Data_rs": 0x12345678, "Data_rt": 0x89ABCDEF, "PCPlus4": 0x00400004, "ImmVal": 0xFFFF8000, "shamt": 0x1E}
    for a_sel in [ASEL["RS"], ASEL["PC4"], ASEL["ZERO"], ASEL["RT"]]:
        for b_sel in [BSEL["RT"], BSEL["IMM"], BSEL["SHAMT"], BSEL["RS_LOW5"], BSEL["ZERO"], BSEL["RESERVED5"], BSEL["RESERVED6"], BSEL["NONE"]]:
            rows.append({"ASel_bin": bin_n(a_sel, 2), "BSel_bin": bin_n(b_sel, 3), **{k: hex32(v) if k != "shamt" else hexn(v, 5) for k, v in sample.items()}, "Expected_ALU_A": hex32(select_a(sample["Data_rs"], sample["Data_rt"], sample["PCPlus4"], a_sel)), "Expected_ALU_B": hex32(select_b(sample["Data_rs"], sample["Data_rt"], sample["ImmVal"], sample["shamt"], b_sel))})
    return rows


def control_vectors() -> list[dict]:
    rows = []
    for r in control_rows():
        row = {"Instruction": r["Instruction"], "opcode_bin": bin_n(r["opcode"], 6), "funct_bin": bin_n(0 if r["funct"] is None else r["funct"], 6), "funct_dontcare": 1 if r["funct"] is None else 0}
        for name, width in [("RegWEn", 1), ("DestSel", 2), ("ASel", 2), ("BSel", 3), ("ImmSel", 2), ("BrSel", 1), ("ALUSel", 4), ("WBSel", 2), ("WdLen", 2), ("MemRW", 2), ("LoadEx", 1), ("Branch", 1), ("Jump", 1), ("JumpSel", 1)]:
            row[name] = bin_n(r[name], width)
        rows.append(row)
    return rows


def branch_vectors() -> list[dict]:
    """Current BranchComp vectors: 1-bit BrSel only, no Branch enable input.

    Branch enable gating belongs to PCControl/NextPC.  BrSel=0 means EQ/beq
    condition and BrSel=1 means NE/bne condition.
    """
    rows = []
    cases = [
        (0x00000001, 0x00000001),
        (0x00000001, 0x00000002),
        (0xFFFFFFFF, 0xFFFFFFFF),
        (0x80000000, 0x7FFFFFFF),
        (0x00000000, 0x00000000),
    ]
    for br_sel in [BRSEL["EQ"], BRSEL["NE"]]:
        for rs, rt in cases:
            taken = branch_taken_raw(rs, rt, br_sel)
            rows.append({
                "BrSel_bin": bin_n(br_sel, 1),
                "Data_rs": hex32(rs),
                "Data_rt": hex32(rt),
                "Expected_BranchTaken": taken,
            })
    return rows


def jump_vectors() -> list[dict]:
    rows = []
    cases = [
        (0x00400004, 0x0000001),
        (0x8ABC0004, 0x03FFFFF),
        (0x0FFFFFFC, 0x0000000),
        (0x10000000, 0x3FFFFFF),
    ]
    for pc4, target26 in cases:
        rows.append({
            "PCPlus4": hex32(pc4),
            "target26": hexn(target26, 26),
            "Expected_JumpImmTarget": hex32(jump_imm_target(pc4, target26)),
        })
    return rows


def data_memory_vectors() -> list[dict]:
    """Sequential Data Memory vectors for Logisim ROM/counter tests.

    Older vectors assumed a hidden testbench preload of InitialWord before every
    row.  That made the first load expect data even though the external stimulus
    had never written memory.  These vectors are self-contained instead: before
    each checked operation, an explicit aligned word store initializes the target
    word to 0xAABBCCDD.  Therefore a black-box Logisim testbench can drive only
    the listed input vectors in order and still see the expected results.
    """
    rows = []
    init = 0xAABBCCDD

    def append_row(kind: str, before_word: int, addr: int, data: int, wd: int, mem: int, load_ex: int) -> int:
        res = data_memory_result(before_word, addr, data, wd, mem, load_ex)
        rows.append({
            "Scenario": kind,
            "InitialWord": hex32(before_word),
            "Addr": hex32(addr),
            "Data_rt": hex32(data),
            "WdLen_bin": bin_n(wd, 2),
            "MemRW_bin": bin_n(mem, 2),
            "LoadEx": load_ex,
            "Expected_Lane": res["Lane"],
            "Expected_WE": res["WriteEnable"],
            "Expected_MisalignedAccess": res["MisalignedAccess"],
            "Expected_Data_RD": hex32(res["Data_RD"]),
            "ExpectedNewWord": hex32(res["ExpectedNewWord"]),
        })
        return res["ExpectedNewWord"]

    operations = [
        ("LB_SIGN", WDLEN["BYTE"], MEMRW["LOAD"], 0, 0),
        ("LBU_ZERO", WDLEN["BYTE"], MEMRW["LOAD"], 1, 0),
        ("LH_SIGN", WDLEN["HALF"], MEMRW["LOAD"], 0, 0),
        ("LHU_ZERO", WDLEN["HALF"], MEMRW["LOAD"], 1, 0),
        ("LW", WDLEN["WORD"], MEMRW["LOAD"], 0, 0),
        ("SB", WDLEN["BYTE"], MEMRW["STORE"], 0, 0x00000011),
        ("SH", WDLEN["HALF"], MEMRW["STORE"], 0, 0x00002233),
        ("SW", WDLEN["WORD"], MEMRW["STORE"], 0, 0x44556677),
        ("IDLE", WDLEN["NONE"], MEMRW["IDLE"], 0, 0),
    ]

    current_word = 0x00000000
    for addr in [0, 1, 2, 3]:
        for name, wd, mem, load_ex, data in operations:
            current_word = append_row("INIT_WORD", current_word, addr & ~0x3, init, WDLEN["WORD"], MEMRW["STORE"], 0)
            current_word = append_row(name, current_word, addr, data, wd, mem, load_ex)
    return rows


def wb_vectors() -> list[dict]:
    rows = []
    for wb_sel in [WB["MEM"], WB["ALU"], WB["PC4"], WB["NONE"]]:
        rows.append({"WBSel_bin": bin_n(wb_sel, 2), "Data_RD": hex32(0xAABBCCDD), "ALUResult": hex32(0x12345678), "PCPlus4": hex32(0x00400004), "Expected_Data_WR": hex32(wb_data(0xAABBCCDD, 0x12345678, 0x00400004, wb_sel))})
    return rows


def pc_control_vectors() -> list[dict]:
    rows = []
    for branch in [0, 1]:
        for jump in [0, 1]:
            for taken in [0, 1]:
                pcsel = pc_control(branch, jump, taken)
                rows.append({"Branch": branch, "Jump": jump, "BranchTaken": taken, "Expected_PCSel_bin": bin_n(pcsel, 2)})
    return rows


def write_block_readme(outdir: Path) -> None:
    text = """# Generated block-level golden vectors

이 디렉터리는 `tools/testvector_generators/generate_all.py`가 생성한 산출물입니다. 기존 `test_vectors/ALU_testvector`, `test_vectors/Register_file`, `test_vectors/Register_file_full`은 덮어쓰지 않습니다.

검증 재현:

```bash
python3 tools/testvector_generators/generate_all.py --check --out test_vectors/generated
```

각 block 디렉터리 산출물은 두 종류만 둡니다.

- `vectors.csv`: 사람이 검토하는 정본 로그입니다. 모든 column과 설명용 field를 여기에서 확인합니다.
- `<signal>.hex`: Logisim ROM에 import하기 쉬운 `v2.0 raw` hex memory image입니다. 실제 ROM 입력/expected 비교에 필요한 신호만 생성합니다.

중복을 줄이기 위해 per-column `.txt`, metadata `.hex`, `_bin` 없는 alias 파일은 생성하지 않습니다. 예를 들어 ALU control ROM은 CSV column 이름 그대로 `ALUSel_bin.hex`를 사용합니다.

Logisim ROM import 시 `.hex` 파일을 쓰고, ROM의 Data Bits 폭은 대상 signal 폭과 맞춥니다. 예: `A.hex`/`B.hex`/`Expected.hex`는 32-bit, `ALUSel_bin.hex`는 4-bit입니다.
"""
    (outdir / "README.md").write_text(text, encoding="utf-8")


GENERATED_MARKER = ".generated_by_mips_golden"


def is_safe_generated_outdir(outdir: Path) -> bool:
    """Return True only for paths this generator may clear before regeneration.

    The guard prevents accidental deletion of protected hand-authored vectors such
    as ``test_vectors/Register_file`` when a user passes the wrong ``--out``.
    """
    resolved = outdir.resolve()
    cwd = Path.cwd().resolve()
    try:
        resolved.relative_to(cwd)
    except ValueError:
        return False
    if resolved in {cwd, cwd / "test_vectors", cwd / "Project", cwd / "Project" / "Subcircuit"}:
        return False
    if (outdir / GENERATED_MARKER).exists():
        return True
    return outdir.name == "generated" and outdir.parent.name == "test_vectors"


def prepare_outdir(outdir: Path) -> None:
    if outdir.exists():
        if not is_safe_generated_outdir(outdir):
            raise SystemExit(f"refusing to delete non-generated output directory: {outdir}")
        shutil.rmtree(str(outdir))
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / GENERATED_MARKER).write_text("generated by tools/testvector_generators/generate_all.py\n", encoding="utf-8")


def generate_all(outdir: Path) -> None:
    prepare_outdir(outdir)
    write_block_readme(outdir)

    blocks = {
        "alu": alu_vectors(),
        "register_file": register_vectors(),
        "imm_generator": imm_vectors(),
        "selectors": selector_vectors(),
        "control_unit": control_vectors(),
        "branch_comp": branch_vectors(),
        "jump_target": jump_vectors(),
        "data_memory": data_memory_vectors(),
        "wb_selector": wb_vectors(),
        "pc_control": pc_control_vectors(),
    }
    for name, rows in blocks.items():
        write_block_outputs(outdir, name, rows)


def compare_trees(expected: Path, actual: Path) -> list[str]:
    diffs = []

    def comparable_files(base: Path) -> list[Path]:
        # HDL-oriented vectors.mem files are additive artifacts generated by
        # tools/tv_gen/generate_all.py from the source CSV/HEX vectors.  They are
        # intentionally ignored by the source-vector --check path.
        return sorted(
            p.relative_to(base)
            for p in base.rglob("*")
            if p.is_file()
            and p.name != "vectors.mem"
            and p.relative_to(base).parts[:1] != ("top_smoke",)
        )

    expected_files = comparable_files(expected)
    actual_files = comparable_files(actual)
    if expected_files != actual_files:
        missing = sorted(set(expected_files) - set(actual_files))
        extra = sorted(set(actual_files) - set(expected_files))
        if missing:
            diffs.append("missing: " + ", ".join(str(p) for p in missing))
        if extra:
            diffs.append("extra: " + ", ".join(str(p) for p in extra))
    for rel in expected_files:
        e = expected / rel
        a = actual / rel
        if a.exists() and not filecmp.cmp(str(e), str(a), shallow=False):
            diffs.append(f"content differs: {rel}")
    return diffs


def check_all(outdir: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="mips_golden_") as td:
        tmp = Path(td) / "generated"
        generate_all(tmp)
        diffs = compare_trees(tmp, outdir)
        if diffs:
            raise SystemExit("generated output mismatch:\n" + "\n".join(diffs))
