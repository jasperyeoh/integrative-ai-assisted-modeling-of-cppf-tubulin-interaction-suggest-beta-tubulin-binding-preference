#!/usr/bin/env python3
import argparse

AA3 = {
    "ALA","ARG","ASN","ASP","CYS","GLU","GLN","GLY","HIS","ILE","LEU","LYS",
    "MET","PHE","PRO","SER","THR","TRP","TYR","VAL","HID","HIE","HIP","CYX",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    count = 0
    with open(args.inp, "r", encoding="utf-8") as fi, open(args.out, "w", encoding="utf-8") as fo:
        for line in fi:
            if line.startswith(("ATOM", "HETATM")):
                resn = line[17:20].strip()
                chain = line[21:22]
                if resn in AA3 and chain in ("A", "B"):
                    fo.write(line)
                    count += 1
            elif line.startswith("TER"):
                fo.write(line)
        fo.write("END\n")
    print(f"Wrote protein-only pdb: {args.out} (atoms={count})")


if __name__ == "__main__":
    main()
