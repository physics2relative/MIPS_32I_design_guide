#!/usr/bin/env python3
"""Generate Logisim control ROM for MIPS Control Unit.

Address format:
    Addr[11:6] = opcode[5:0]
    Addr[5:0]  = funct[5:0]

Data format is a 32-bit control word:
    [31:27] reserved = 0
    [26]    RegWEn
    [25:24] DestSel
    [23:22] ASel
    [21:19] BSel
    [18:17] ImmSel
    [16]    BrSel
    [15:12] ALUSel
    [11:10] WBSel
    [9:8]   WdLen
    [7]     reserved = 0
    [6:5]   MemRW
    [4]     LoadEx
    [3]     Branch
    [2]     Jump
    [1]     JumpSel
    [0]     reserved = 0
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "testvector_generators"))
from golden import ALU, ASEL, BRSEL, BSEL, DEST, IMMSEL, MEMRW, WB, WDLEN, control_rows  # noqa: E402

ROM_DEPTH = 4096
ROM_WIDTH = 32

FIELD_LAYOUT = [
    ("RegWEn", 26, 1),
    ("DestSel", 24, 2),
    ("ASel", 22, 2),
    ("BSel", 19, 3),
    ("ImmSel", 17, 2),
    ("BrSel", 16, 1),
    ("ALUSel", 12, 4),
    ("WBSel", 10, 2),
    ("WdLen", 8, 2),
    ("MemRW", 5, 2),
    ("LoadEx", 4, 1),
    ("Branch", 3, 1),
    ("Jump", 2, 1),
    ("JumpSel", 1, 1),
]

NOP = {
    "RegWEn": 0,
    "DestSel": DEST["NONE"],
    "ASel": ASEL["ZERO"],
    "BSel": BSEL["ZERO"],
    "ImmSel": IMMSEL["SIGN16"],
    "BrSel": BRSEL["EQ"],
    "ALUSel": ALU["NONE"],
    "WBSel": WB["NONE"],
    "WdLen": WDLEN["NONE"],
    "MemRW": MEMRW["IDLE"],
    "LoadEx": 0,
    "Branch": 0,
    "Jump": 0,
    "JumpSel": 0,
}


def pack_control(row: dict) -> int:
    word = 0
    for field, lsb, width in FIELD_LAYOUT:
        value = int(row[field])
        max_value = (1 << width) - 1
        if value < 0 or value > max_value:
            raise ValueError(f"{field}={value:#x} exceeds {width}-bit field")
        word |= value << lsb
    return word & 0xFFFFFFFF


def addr(opcode: int, funct: int) -> int:
    if not (0 <= opcode < 64 and 0 <= funct < 64):
        raise ValueError(f"bad opcode/funct: {opcode:#x}/{funct:#x}")
    return (opcode << 6) | funct


def generate_rom() -> tuple[list[int], list[dict]]:
    rom = [pack_control(NOP) for _ in range(ROM_DEPTH)]
    map_rows: list[dict] = []
    for row in control_rows():
        instr = row["Instruction"]
        opcode = int(row["opcode"])
        funct = row["funct"]
        word = pack_control(row)
        if funct is None:
            start = addr(opcode, 0)
            end = addr(opcode, 63)
            for fn in range(64):
                rom[addr(opcode, fn)] = word
            map_rows.append({
                "instruction": instr,
                "kind": "opcode_range",
                "opcode_hex": f"0x{opcode:02X}",
                "funct_hex": "*",
                "addr_start_hex": f"0x{start:03X}",
                "addr_end_hex": f"0x{end:03X}",
                "control_word_hex": f"0x{word:08X}",
            })
        else:
            fn = int(funct)
            a = addr(opcode, fn)
            rom[a] = word
            map_rows.append({
                "instruction": instr,
                "kind": "exact",
                "opcode_hex": f"0x{opcode:02X}",
                "funct_hex": f"0x{fn:02X}",
                "addr_start_hex": f"0x{a:03X}",
                "addr_end_hex": f"0x{a:03X}",
                "control_word_hex": f"0x{word:08X}",
            })
    return rom, map_rows


def write_logisim_hex(path: Path, rom: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["v2.0 raw"] + [f"{word:08X}" for word in rom]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_map(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["instruction", "kind", "opcode_hex", "funct_hex", "addr_start_hex", "addr_end_hex", "control_word_hex"]
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    rom, rows = generate_rom()
    out_dir = ROOT / "Project" / "ROM"
    write_logisim_hex(out_dir / "control_unit_opcode_funct_rom.hex", rom)
    write_map(out_dir / "control_unit_opcode_funct_rom_map.csv", rows)
    print(f"generated {out_dir / 'control_unit_opcode_funct_rom.hex'} depth={ROM_DEPTH} width={ROM_WIDTH}")
    print(f"generated {out_dir / 'control_unit_opcode_funct_rom_map.csv'} entries={len(rows)}")


if __name__ == "__main__":
    main()
