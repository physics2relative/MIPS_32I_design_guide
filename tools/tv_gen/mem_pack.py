#!/usr/bin/env python3
"""Pack existing per-port Logisim vectors into HDL-friendly .mem files.

This module is intentionally an adapter layer:
- source of truth remains test_vectors/generated/<block>/*.hex and vectors.csv
- existing CSV/HEX files are not rewritten
- one packed vectors.mem is added per block for Verilog $readmemh testbenches
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


Field = Tuple[str, int]


@dataclass(frozen=True)
class GeneratedMem:
    block: str
    count: int
    width: int
    out_path: Path
    fields: Sequence[Field]


# Field order is MSB -> LSB. Testbenches should unpack in the same order.
SCHEMAS: Dict[str, Sequence[Field]] = {
    "alu": (("ALUSel_bin", 4), ("A", 32), ("B", 32), ("Expected", 32)),
    "branch_comp": (("BrSel_bin", 1), ("Data_rs", 32), ("Data_rt", 32), ("Expected_BranchTaken", 1)),
    "control_unit": (("opcode_bin", 6), ("funct_bin", 6), ("RegWEn", 1), ("DestSel", 2), ("ASel", 2), ("BSel", 3), ("ImmSel", 3), ("BrSel", 3), ("ALUSel", 4), ("WBSel", 2), ("WdLen", 2), ("MemRW", 3), ("LoadEx", 1), ("Branch", 1), ("Jump", 1), ("JumpSel", 2)),
    "data_memory": (("InitialWord", 32), ("Addr", 32), ("Data_rt", 32), ("WdLen_bin", 2), ("MemRW_bin", 3), ("LoadEx", 1), ("Expected_Lane", 2), ("Expected_WE", 4), ("Expected_Data_RD", 32), ("ExpectedNewWord", 32)),
    "imm_generator": (("ImmSel_bin", 3), ("imm16", 16), ("target26", 26), ("PCPlus4", 32), ("Expected_ImmVal", 32), ("Expected_BranchOff", 32), ("Expected_JumpImmTarget", 32)),
    "jump_target": (("Jump", 1), ("JumpSel", 2), ("PCPlus4", 32), ("target26", 26), ("Data_rs", 32), ("Expected_JumpImmTarget", 32), ("Expected_SelectedJumpTarget", 32)),
    "pc_control": (("Branch", 1), ("Jump", 1), ("BranchTakenRaw", 1), ("Expected_BranchTaken", 1), ("Expected_PCSel_bin", 2)),
    "selectors": (("ASel_bin", 2), ("BSel_bin", 3), ("Data_rs", 32), ("Data_rt", 32), ("PCPlus4", 32), ("ImmVal", 32), ("BranchOff", 32), ("shamt", 5), ("Expected_ALU_A", 32), ("Expected_ALU_B", 32)),
    "wb_selector": (("WBSel_bin", 2), ("Data_RD", 32), ("ALUResult", 32), ("PCPlus4", 32), ("Expected_Data_WR", 32)),
}

# register_file keeps the established HDL testbench format, including tag[7:0].
REGISTER_FILE_SCHEMA: Sequence[Field] = (
    ("tag", 8), ("RESET", 1), ("RegWEn", 1), ("Addr_rs", 5), ("Addr_rt", 5),
    ("Expected_WriteReg", 5), ("Data_WR", 32), ("Expected_Data_rs", 32), ("Expected_Data_rt", 32),
)

TAG_RESET = 0
TAG_READ = 1
TAG_WRITE = 2
TAG_BYPASS = 3
TAG_ZERO = 4


def schema_names() -> List[str]:
    return sorted(list(SCHEMAS.keys()) + ["register_file"])


def _parse_number(field_name: str, text: str) -> int:
    """Parse one Logisim v2.0 raw token.

    All generated per-port files use Logisim raw hex tokens. Some field names end
    with _bin because the logical control signal is binary-coded, but the raw file
    still stores the numeric value in hex, for example ALUSel 10 is written as A.
    """
    del field_name
    token = text.strip().replace("_", "")
    return int(token, 16)


def parse_vector_file(path: Path, field_name: str) -> List[int]:
    values: List[int] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.lower() == "v2.0 raw":
            continue
        values.append(_parse_number(field_name, line))
    return values


def _field_path(block_dir: Path, field_name: str) -> Path:
    return block_dir / f"{field_name}.hex"


def _check_width(block: str, field_name: str, width: int, values: Iterable[int]) -> None:
    if width <= 0:
        raise ValueError(f"{block}.{field_name}: width must be positive, got {width}")
    max_value = (1 << width) - 1
    for index, value in enumerate(values):
        if value < 0 or value > max_value:
            raise ValueError(f"{block}.{field_name}[{index}]={value:#x} exceeds {width}-bit field max {max_value:#x}")


def _load_schema_fields(block: str, block_dir: Path, schema: Sequence[Field]) -> Dict[str, List[int]]:
    vectors: Dict[str, List[int]] = {}
    for field_name, width in schema:
        path = _field_path(block_dir, field_name)
        if not path.exists():
            raise FileNotFoundError(f"missing vector file for {block}.{field_name}: {path}")
        values = parse_vector_file(path, field_name)
        _check_width(block, field_name, width, values)
        vectors[field_name] = values
    lengths = {name: len(values) for name, values in vectors.items()}
    if not lengths:
        raise ValueError(f"{block}: empty schema")
    if len(set(lengths.values())) != 1:
        raise ValueError(f"{block}: vector lengths differ: {lengths}")
    return vectors


def _pack_values(fields: Sequence[Field], values: Sequence[int]) -> int:
    value = 0
    for (_field_name, width), field_value in zip(fields, values):
        value = (value << width) | (field_value & ((1 << width) - 1))
    return value


def _write_mem(out_path: Path, packed_values: Sequence[int], width: int) -> None:
    hex_digits = (width + 3) // 4
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(f"{value:0{hex_digits}X}" for value in packed_values) + "\n", encoding="utf-8")


def generate_schema_block(root: Path, block: str) -> GeneratedMem:
    schema = SCHEMAS[block]
    block_dir = root / "test_vectors" / "generated" / block
    vectors = _load_schema_fields(block, block_dir, schema)
    count = len(next(iter(vectors.values())))
    width = sum(width for _, width in schema)
    packed: List[int] = []
    for index in range(count):
        values = [vectors[field_name][index] for field_name, _ in schema]
        packed.append(_pack_values(schema, values))
    out_path = block_dir / "vectors.mem"
    _write_mem(out_path, packed, width)
    return GeneratedMem(block=block, count=count, width=width, out_path=out_path, fields=schema)


def _infer_register_file_tag(rst: int, wen: int, wr: int, rs: int, rt: int, exp_accepted: int) -> int:
    if rst:
        return TAG_RESET
    if wen and wr == 0 and not exp_accepted:
        return TAG_ZERO
    if wen and wr != 0 and (wr == rs or wr == rt):
        return TAG_BYPASS
    if wen:
        return TAG_WRITE
    return TAG_READ


def generate_register_file(root: Path) -> GeneratedMem:
    block = "register_file"
    block_dir = root / "test_vectors" / "generated" / block
    source_schema: Sequence[Field] = (
        ("RESET", 1), ("RegWEn", 1), ("Addr_rs", 5), ("Addr_rt", 5), ("Expected_WriteReg", 5),
        ("Data_WR", 32), ("Expected_WriteAccepted", 1), ("Expected_Data_rs", 32), ("Expected_Data_rt", 32),
    )
    vectors = _load_schema_fields(block, block_dir, source_schema)
    count = len(next(iter(vectors.values())))
    width = sum(field_width for _, field_width in REGISTER_FILE_SCHEMA)
    packed: List[int] = []
    for index in range(count):
        rst = vectors["RESET"][index]
        wen = vectors["RegWEn"][index]
        rs = vectors["Addr_rs"][index]
        rt = vectors["Addr_rt"][index]
        wr = vectors["Expected_WriteReg"][index]
        accepted = vectors["Expected_WriteAccepted"][index]
        tag = _infer_register_file_tag(rst, wen, wr, rs, rt, accepted)
        values = [tag, rst, wen, rs, rt, wr, vectors["Data_WR"][index], vectors["Expected_Data_rs"][index], vectors["Expected_Data_rt"][index]]
        packed.append(_pack_values(REGISTER_FILE_SCHEMA, values))
    out_path = block_dir / "vectors.mem"
    _write_mem(out_path, packed, width)
    return GeneratedMem(block=block, count=count, width=width, out_path=out_path, fields=REGISTER_FILE_SCHEMA)


def generate_block(root: Path, block: str) -> GeneratedMem:
    if block == "register_file":
        return generate_register_file(root)
    if block not in SCHEMAS:
        raise KeyError(f"unknown block {block!r}; known blocks: {', '.join(schema_names())}")
    return generate_schema_block(root, block)


def generate_many(root: Path, blocks: Sequence[str]) -> List[GeneratedMem]:
    return [generate_block(root, block) for block in blocks]
