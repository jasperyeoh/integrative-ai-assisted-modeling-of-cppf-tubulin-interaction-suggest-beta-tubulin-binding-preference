#!/usr/bin/env python3
"""
Extract cofactor residues from a PDB into a standalone PDB.

Designed for the 5IJ0-derived tubulin system where we want to keep:
- GTP
- GDP
- MG (Mg2+)

This helps parameterize cofactors separately (e.g., with AmberTools/tleap)
without mixing them into protein-only pdb2gmx.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, type=Path)
    ap.add_argument("--out", dest="out", required=True, type=Path)
    ap.add_argument("--resnames", nargs="+", default=["GTP", "GDP", "MG"])
    args = ap.parse_args()

    keep = set(r.strip().upper() for r in args.resnames)
    out_lines: list[str] = []
    n = 0

    with args.inp.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if not (line.startswith("ATOM") or line.startswith("HETATM")):
                continue
            if len(line) < 54:
                continue
            resn = line[17:20].strip().upper()
            if resn in keep:
                out_lines.append(line.rstrip("\n"))
                n += 1

    if n == 0:
        raise SystemExit(f"No residues found for resnames={sorted(keep)} in {args.inp}")

    out_lines.append("END")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(out_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

