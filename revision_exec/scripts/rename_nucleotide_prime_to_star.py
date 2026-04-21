#!/usr/bin/env python3
"""
Convert PDB atom names from prime notation (e.g., O5', C4') to AMBER prep-style
asterisk notation (e.g., O5*, C4*).

This is needed because some legacy AMBER .prep libraries (e.g., ADP.prep/ATP.prep
from Meagher/Redman/Carlson polyphosphate parameters) use '*' in atom names.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def convert_atom_name(name4: str) -> str:
    # name4 includes padding (width 4). Replace a single quote with '*'
    return name4.replace("'", "*")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, type=Path)
    ap.add_argument("--out", dest="out", required=True, type=Path)
    ap.add_argument("--resnames", nargs="+", default=["GTP", "GDP", "ATP", "ADP"])
    args = ap.parse_args()

    targets = set(r.upper() for r in args.resnames)
    out_lines: list[str] = []

    with args.inp.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.startswith(("ATOM", "HETATM")) and len(line) >= 20:
                resn = line[17:20].strip().upper()
                if resn in targets:
                    atom_name = line[12:16]
                    new_atom_name = convert_atom_name(atom_name)
                    if new_atom_name != atom_name:
                        line = line[:12] + new_atom_name + line[16:]
            out_lines.append(line.rstrip("\n"))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(out_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

