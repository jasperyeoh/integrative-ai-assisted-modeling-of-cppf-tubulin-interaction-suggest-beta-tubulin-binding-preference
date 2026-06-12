#!/usr/bin/env python3
"""Concatenate protein and ligand GRO files with valid GROMACS formatting."""

from __future__ import annotations

import argparse
from pathlib import Path


def parse_gro(path: Path) -> tuple[str, list[dict], str]:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    title = lines[0]
    n = int(lines[1].strip())
    atoms = []
    for ln in lines[2 : 2 + n]:
        atoms.append(
            {
                "resnr": int(ln[0:5]),
                "resname": ln[5:10].strip(),
                "atomname": ln[10:15].strip(),
                "atomnr": int(ln[15:20]),
                "x": float(ln[20:28]),
                "y": float(ln[28:36]),
                "z": float(ln[36:44]),
                "suffix": ln[44:],
            }
        )
    box = lines[2 + n] if len(lines) > 2 + n else "0.00000   0.00000   0.00000"
    return title, atoms, box


def format_atom(resnr: int, resname: str, atomname: str, atomnr: int, x: float, y: float, z: float, suffix: str = "") -> str:
    resname = resname[:5]
    atomname = f"{atomname:<5}"[:5]
    return f"{resnr:5d}{resname:>5}{atomname}{atomnr:5d}{x:8.3f}{y:8.3f}{z:8.3f}{suffix}\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--protein", required=True, type=Path)
    ap.add_argument("--ligand", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--ligand-resname", default="CPP")
    ap.add_argument("--ligand-resnr", type=int, default=452)
    args = ap.parse_args()

    _pt, p_atoms, box = parse_gro(args.protein)
    _lt, l_atoms, _ = parse_gro(args.ligand)
    out_atoms = list(p_atoms)
    start = len(out_atoms) + 1
    for i, a in enumerate(l_atoms):
        out_atoms.append(
            {
                "resnr": args.ligand_resnr,
                "resname": args.ligand_resname,
                "atomname": a["atomname"],
                "atomnr": start + i,
                "x": a["x"],
                "y": a["y"],
                "z": a["z"],
                "suffix": "",
            }
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as f:
        f.write("Protein+CPPF (6E7B pose-fitted)\n")
        f.write(f"{len(out_atoms)}\n")
        for a in out_atoms:
            f.write(format_atom(**a))
        f.write(f"{box}\n")
    print(f"Wrote {args.out} ({len(out_atoms)} atoms)")


if __name__ == "__main__":
    main()
