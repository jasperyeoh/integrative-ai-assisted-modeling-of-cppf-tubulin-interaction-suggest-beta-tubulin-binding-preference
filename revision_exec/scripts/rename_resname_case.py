#!/usr/bin/env python3
"""
Rename residue names in a PDB (case-sensitive mapping).

Needed because some LEaP prep libraries use lowercase residue names
(e.g., Bryce GTP.prep defines residue 'gtp'), while PDBs often use uppercase.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, type=Path)
    ap.add_argument("--out", dest="out", required=True, type=Path)
    ap.add_argument("--map", nargs="+", required=True, help="Pairs like GTP=gtp GDP=gdp")
    args = ap.parse_args()

    mapping: dict[str, str] = {}
    for item in args.map:
        if "=" not in item:
            raise SystemExit(f"Bad --map item: {item} (expected KEY=VAL)")
        k, v = item.split("=", 1)
        k = k.strip()
        v = v.strip()
        if len(k) != 3 or len(v) != 3:
            raise SystemExit(f"Residue names must be 3 chars: {item}")
        mapping[k] = v

    out_lines: list[str] = []
    with args.inp.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.startswith(("ATOM", "HETATM")) and len(line) >= 20:
                resn = line[17:20]
                resn_stripped = resn.strip()
                if resn_stripped in mapping:
                    new = mapping[resn_stripped]
                    # keep width 3 inside columns 18-20
                    new_resn = f"{new:>3s}"
                    line = line[:17] + new_resn + line[20:]
            out_lines.append(line.rstrip("\n"))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(out_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

