#!/usr/bin/env python3
import argparse


def read_charges(path):
    vals = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            vals.append(float(s.split()[0]))
    return vals


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True)
    ap.add_argument("--charges", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    charges = read_charges(args.charges)
    atom_count = 0
    in_atom_block = False
    charge_idx = 0
    out_lines = []

    with open(args.inp, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("@<TRIPOS>ATOM"):
                in_atom_block = True
                out_lines.append(line)
                continue
            if line.startswith("@<TRIPOS>") and not line.startswith("@<TRIPOS>ATOM"):
                in_atom_block = False
                out_lines.append(line)
                continue

            if in_atom_block and line.strip():
                atom_count += 1
                parts = line.rstrip("\n").split()
                if len(parts) < 9:
                    raise SystemExit(f"Unexpected mol2 atom line format: {line}")
                if charge_idx >= len(charges):
                    raise SystemExit("Not enough charges for mol2 atom lines.")
                parts[-1] = f"{charges[charge_idx]:.8f}"
                charge_idx += 1
                out_lines.append(" ".join(parts) + "\n")
            else:
                out_lines.append(line)

    if atom_count != len(charges):
        raise SystemExit(
            f"Charge count mismatch: mol2 atoms={atom_count}, provided charges={len(charges)}"
        )

    with open(args.out, "w", encoding="utf-8") as f:
        f.writelines(out_lines)
    print(f"Wrote updated mol2 with {atom_count} charges: {args.out}")


if __name__ == "__main__":
    main()
