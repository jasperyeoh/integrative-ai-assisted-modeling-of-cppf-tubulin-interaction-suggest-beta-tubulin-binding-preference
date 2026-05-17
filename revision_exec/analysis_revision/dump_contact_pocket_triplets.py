#!/usr/bin/env python3
"""
Dump contact-defined pocket residue list as (chain,resi,resname) triplets.

This is intended for monomer systems where the `.gro` file provides residue names.
"""
from __future__ import annotations

import argparse
from pathlib import Path


def parse_gro_resnames(gro: Path) -> dict[int, str]:
    """
    Parse residue id -> residue name from a .gro file.

    GRO line format (fixed width, 1-indexed residue numbering in file):
      1-5 resnr, 6-10 resname, 11-15 atomname, 16-20 atomnr, ...
    """
    lines = gro.read_text(errors="replace").splitlines()
    if len(lines) < 3:
        raise ValueError(f"unexpected gro file (too short): {gro}")
    out: dict[int, str] = {}
    for line in lines[2:-1]:  # skip title + atom count + final box
        if len(line) < 10:
            continue
        try:
            resi = int(line[0:5])
        except ValueError:
            continue
        resn = line[5:10].strip()
        # One residue can appear across many atoms; first wins (same resn anyway).
        out.setdefault(resi, resn)
    if not out:
        raise ValueError(f"no residues parsed from {gro}")
    return out


def parse_residue_ids(txt: Path) -> list[int]:
    for line in txt.read_text(errors="replace").splitlines():
        if line.startswith("residue_ids="):
            s = line.split("=", 1)[1].strip()
            if not s:
                return []
            return [int(x) for x in s.split(",") if x]
    raise ValueError(f"missing residue_ids=... line in {txt}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gro", type=Path, required=True)
    ap.add_argument("--residue-txt", type=Path, required=True)
    ap.add_argument("--chain", required=True, help="Chain label to print (e.g., A or B)")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    resnames = parse_gro_resnames(args.gro)
    ids = parse_residue_ids(args.residue_txt)

    rows: list[str] = ["chain,resi,resname"]
    for r in ids:
        rows.append(f"{args.chain},{r},{resnames.get(r, 'NA')}")
    args.out.write_text("\n".join(rows) + "\n")
    print(f"Wrote {args.out} (n={len(ids)})")


if __name__ == "__main__":
    main()

