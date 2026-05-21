#!/usr/bin/env python3
"""Compatibility wrapper for generating register_file vectors.mem."""
from __future__ import annotations

import argparse
from pathlib import Path

from mem_pack import generate_register_file


def generate(src_dir: Path, out_path: Path) -> int:
    """Preserve the previous register_file_mem.generate(src, out) API."""
    root = src_dir.parent.parent.parent
    result = generate_register_file(root)
    if out_path.resolve() != result.out_path.resolve():
        out_path.write_text(result.out_path.read_text(encoding="utf-8"), encoding="utf-8")
    return result.count


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate HDL packed mem vectors from existing Logisim register_file vectors")
    parser.add_argument("--src", default="test_vectors/generated/register_file", help="existing register_file vector directory")
    parser.add_argument("--out", default="test_vectors/generated/register_file/vectors.mem", help="output packed mem path")
    args = parser.parse_args()

    count = generate(Path(args.src), Path(args.out))
    print(f"REGISTER_FILE_MEM_GENERATED count={count} out={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
