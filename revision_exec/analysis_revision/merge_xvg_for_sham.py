#!/usr/bin/env python3
"""Merge two GROMACS .xvg time series on time (inner join).

Use for gsham_input when rg.xvg and rmsd_backbone.xvg may differ in sample count / spacing.
Do NOT use paste|awk blindly — align by time column first.

Output: 3 columns — time (same unit as input), value_A, value_B (no header, xvg-style comments optional).

Usage:
  merge_xvg_for_sham.py rg.xvg rmsd_backbone.xvg -o gsham_input.xvg
"""
from __future__ import annotations

import argparse
import numpy as np


def read_xvg_series(path: str) -> tuple[np.ndarray, np.ndarray]:
    """Return (time, y) from first two numeric columns of data lines."""
    times: list[float] = []
    vals: list[float] = []
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("@") or s.startswith("&"):
                continue
            parts = s.split()
            if len(parts) < 2:
                continue
            try:
                times.append(float(parts[0]))
                vals.append(float(parts[1]))
            except ValueError:
                continue
    return np.array(times), np.array(vals)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("xvg_a", help="First series (e.g. rg.xvg)")
    ap.add_argument("xvg_b", help="Second series (e.g. rmsd_backbone.xvg)")
    ap.add_argument("-o", "--output", required=True, help="Merged 3-column xvg")
    ap.add_argument(
        "--tol",
        type=float,
        default=1e-4,
        help="Tolerance for matching time (same units as xvg, typically ps or ns)",
    )
    ap.add_argument(
        "--plain",
        action="store_true",
        help="Write only three numeric columns (for gmx sham -f); no #/@ headers",
    )
    args = ap.parse_args()

    t1, y1 = read_xvg_series(args.xvg_a)
    t2, y2 = read_xvg_series(args.xvg_b)
    if len(t1) == 0 or len(t2) == 0:
        raise SystemExit("ERROR: empty series after parsing xvg")

    if len(t1) != len(t2):
        print(
            f"NOTE: row counts differ ({len(t1)} vs {len(t2)}); "
            "using inner join on time (not paste).",
            flush=True,
        )

    # Fast path: same length and aligned times (within tol)
    rows: list[tuple[float, float, float]]
    if len(t1) == len(t2) and np.max(np.abs(t1 - t2)) <= args.tol:
        rows = [(float(a), float(va), float(vb)) for a, va, vb in zip(t1, y1, y2)]
        method = "aligned_stacked"
    else:
        # Inner join on rounded time keys (handles different stride / length)
        scale = 1.0 / args.tol if args.tol > 0 else 1e12
        dict2 = {int(round(float(t) * scale)): float(v) for t, v in zip(t2, y2)}
        rows = []
        for ti, vi in zip(t1, y1):
            kk = int(round(float(ti) * scale))
            if kk in dict2:
                rows.append((float(ti), float(vi), dict2[kk]))
        method = "inner_join"

    if not rows:
        raise SystemExit("ERROR: no overlapping times after inner join; check tol or inputs")

    with open(args.output, "w") as out:
        if not args.plain:
            out.write("# Merged by merge_xvg_for_sham.py\n")
            out.write(f"# method={method} N_rows={len(rows)} N_a={len(t1)} N_b={len(t2)}\n")
        for ti, va, vb in rows:
            out.write(f"{ti:14.6f}  {va:14.6f}  {vb:14.6f}\n")

    print(
        f"Wrote {args.output}: {len(rows)} rows ({method}); input lengths {len(t1)} / {len(t2)}",
        flush=True,
    )


if __name__ == "__main__":
    main()
