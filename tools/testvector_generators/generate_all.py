#!/usr/bin/env python3
"""Generate deterministic block-level golden vectors for MIPS Logisim."""
from __future__ import annotations

import argparse
from pathlib import Path

import golden


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate/check MIPS Logisim block golden vectors")
    parser.add_argument("--out", default="test_vectors/generated", help="output directory for generated vectors")
    parser.add_argument("--check", action="store_true", help="recompute in a temp dir and compare with --out")
    args = parser.parse_args()

    outdir = Path(args.out)
    if args.check:
        golden.check_all(outdir)
        print(f"CHECK OK: {outdir}")
    else:
        golden.generate_all(outdir)
        print(f"GENERATED: {outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
