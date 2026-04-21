#!/usr/bin/env python3
"""
Split a PDB into separate PDBs per residue instance (resname+chain+resid).

Used to isolate GTP and GDP from a cofactor-only PDB so we can run
AmberTools antechamber/GAFF2 on each molecule separately.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Key:
    resname: str
    chain: str
    resid: str

    def stem(self) -> str:
        c = self.chain if self.chain else "_"
        return f"{self.resname}_{c}{self.resid}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, type=Path)
    ap.add_argument("--outdir", required=True, type=Path)
    ap.add_argument("--resnames", nargs="*", default=[])
    args = ap.parse_args()

    wanted = set(r.upper() for r in args.resnames) if args.resnames else None
    buckets: dict[Key, list[str]] = {}

    with args.inp.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if not (line.startswith("ATOM") or line.startswith("HETATM")):
                continue
            if len(line) < 26:
                continue
            resn = line[17:20].strip().upper()
            if wanted is not None and resn not in wanted:
                continue
            chain = line[21:22].strip()
            resid = line[22:26].strip()
            k = Key(resname=resn, chain=chain, resid=resid)
            buckets.setdefault(k, []).append(line.rstrip("\n"))

    if not buckets:
        raise SystemExit("No matching residues found to split.")

    args.outdir.mkdir(parents=True, exist_ok=True)
    for k, lines in buckets.items():
        out = args.outdir / f"{k.stem()}.pdb"
        out.write_text("\n".join(lines + ["TER", "END"]) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

