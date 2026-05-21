#!/usr/bin/env python3
"""Generate additive HDL .mem artifacts from existing Logisim test_vectors."""
from __future__ import annotations

import argparse
from pathlib import Path

from mem_pack import generate_many, schema_names


def main() -> int:
    known_blocks = schema_names()
    parser = argparse.ArgumentParser(
        description=(
            "Pack existing test_vectors/generated/<block>/*.hex into HDL-oriented "
            "test_vectors/generated/<block>/vectors.mem files"
        )
    )
    parser.add_argument("--block", choices=["all"] + known_blocks, default="all")
    parser.add_argument("--root", default=".", help="project root")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    blocks = known_blocks if args.block == "all" else [args.block]
    generated = generate_many(root, blocks)

    for item in generated:
        field_desc = ",".join(f"{name}:{width}" for name, width in item.fields)
        print(
            f"{item.block}: count={item.count} width={item.width} "
            f"out={item.out_path.relative_to(root)} fields={field_desc}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
