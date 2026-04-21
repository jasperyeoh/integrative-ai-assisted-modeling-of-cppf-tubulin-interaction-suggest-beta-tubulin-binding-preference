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
    ap.add_argument("--gas", required=True)
    ap.add_argument("--water", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    g = read_charges(args.gas)
    w = read_charges(args.water)
    if len(g) != len(w):
        raise SystemExit(f"Charge length mismatch: gas={len(g)} water={len(w)}")

    mix = [(0.5 * gv + 0.5 * wv) for gv, wv in zip(g, w)]
    with open(args.out, "w", encoding="utf-8") as f:
        for v in mix:
            f.write(f"{v:.8f}\n")
    print(f"Wrote {len(mix)} mixed RESP2(0.5) charges to {args.out}")


if __name__ == "__main__":
    main()
