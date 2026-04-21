#!/usr/bin/env python3
import argparse
from collections import Counter


def parse_pdb(path):
    chains = Counter()
    resnames = Counter()
    atoms = 0
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("ATOM") or line.startswith("HETATM"):
                atoms += 1
                chain = line[21:22]
                resn = line[17:20].strip()
                chains[chain] += 1
                resnames[resn] += 1
    return atoms, chains, resnames


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdb", required=True)
    ap.add_argument("--require-chains", nargs="*", default=[])
    ap.add_argument("--require-resnames", nargs="*", default=[])
    ap.add_argument("--report", required=True)
    args = ap.parse_args()

    atoms, chains, resnames = parse_pdb(args.pdb)
    missing_chains = [c for c in args.require_chains if c not in chains]
    missing_resn = [r for r in args.require_resnames if r not in resnames]

    ok = not missing_chains and not missing_resn
    with open(args.report, "w", encoding="utf-8") as f:
        f.write(f"PDB: {args.pdb}\n")
        f.write(f"Total atoms: {atoms}\n")
        f.write(f"Chains: {dict(chains)}\n")
        f.write(f"Selected resnames counts: { {k:v for k,v in resnames.items() if k in args.require_resnames} }\n")
        if missing_chains:
            f.write(f"Missing chains: {missing_chains}\n")
        if missing_resn:
            f.write(f"Missing resnames: {missing_resn}\n")
        f.write(f"VALIDATION_STATUS: {'PASS' if ok else 'FAIL'}\n")

    print(f"Wrote report: {args.report}")
    if not ok:
        raise SystemExit("Validation failed; see report.")


if __name__ == "__main__":
    main()
