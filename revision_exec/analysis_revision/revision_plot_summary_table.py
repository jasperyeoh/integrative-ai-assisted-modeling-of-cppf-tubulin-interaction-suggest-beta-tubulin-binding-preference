#!/usr/bin/env python3
"""
Step 3: build summary_by_window.csv — per system × metric, mean/std in [T_end−window, T_end].

Time-series metrics use the first two columns of each .xvg (t, y). RMSF file is special (residue vs RMSF):
we report mean/std of RMSF across residues (no time window).

Optional --smoke-write DIR creates a minimal raw_xvg tree for offline tests.
"""
from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

import numpy as np

from revision_xvg_io import mean_std_vector, read_xvg_xy, window_stats

METRIC_FILES: dict[str, str] = {
    "rmsd_backbone": "rmsd_backbone.xvg",
    "rmsd_ligand": "rmsd_ligand.xvg",
    "mindist_pl": "mindist_pl.xvg",
    "hbond_num": "hbond_num.xvg",
    "rg": "rg.xvg",
    "sasa": "sasa.xvg",
    "rmsf_residue": "rmsf_residue.xvg",
}

ALL_SYSTEMS = [
    "dimer_rep1",
    "dimer_rep2",
    "dimer_rep3",
    "monomer_alpha_rep1",
    "monomer_alpha_rep2",
    "monomer_alpha_rep3",
    "monomer_beta_rep1",
    "monomer_beta_rep2",
    "monomer_beta_rep3",
]


def load_t_end_ns(registry: Path) -> dict[str, float]:
    """Parse T_end_ns per system from T_end_registry.yaml (no PyYAML)."""
    out: dict[str, float] = {}
    cur: str | None = None
    for line in registry.read_text().splitlines():
        m = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
        if m:
            cur = m.group(1)
            continue
        if cur and line.strip().startswith("T_end_ns:"):
            out[cur] = float(line.split(":", 1)[1].strip())
    return out


def write_smoke_raw_xvg(root: Path) -> None:
    """Create 9 × 7 minimal .xvg files with plausible two-column time series."""
    rng = np.random.default_rng(0)
    root.mkdir(parents=True, exist_ok=True)
    for sid in ALL_SYSTEMS:
        d = root / sid
        d.mkdir(parents=True, exist_ok=True)
        is_dimer = sid.startswith("dimer_")
        t_end = 400.0 if is_dimer else 200.0
        t = np.arange(0.0, t_end + 0.01, 0.5)  # 0.5 ns steps — short files
        base = hash(sid) % 97 * 0.01
        for metric, fname in METRIC_FILES.items():
            p = d / fname
            if metric == "rmsf_residue":
                res = np.arange(1, 120, dtype=float)
                y = 0.15 + 0.05 * rng.standard_normal(res.size) + base * 0.001
                lines = ["# RMSF smoke", "@TYPE xy"]
                for a, b in zip(res, y):
                    lines.append(f"{a:10.4f}  {b:10.6f}")
                p.write_text("\n".join(lines) + "\n")
                continue
            y = (
                0.1
                + 0.02 * np.sin(0.03 * t)
                + 0.015 * rng.standard_normal(t.size)
                + base
                + (0.03 if "hbond" in metric else 0.0)
            )
            lines = [f"# smoke {sid} {metric}", '@    title "smoke"', "@TYPE xy"]
            for a, b in zip(t, y):
                lines.append(f"{a:12.6f}  {b:12.6f}")
            p.write_text("\n".join(lines) + "\n")
    print(f"Wrote smoke raw_xvg under {root}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw-root", type=Path, help="Directory containing <system_id>/*.xvg (e.g. raw_xvg)")
    ap.add_argument(
        "--registry",
        type=Path,
        default=None,
        help="T_end_registry.yaml (default: alongside this script)",
    )
    ap.add_argument("--window-ns", type=float, default=50.0, help="Trailing window length (ns)")
    ap.add_argument("--out-csv", type=Path, default=None, help="Output CSV (not used with --smoke-write)")
    ap.add_argument(
        "--smoke-write",
        type=Path,
        metavar="DIR",
        help="Only write synthetic raw_xvg tree to DIR and exit",
    )
    args = ap.parse_args()

    if args.smoke_write is not None:
        write_smoke_raw_xvg(args.smoke_write)
        return

    if args.out_csv is None:
        ap.error("--out-csv required unless using only --smoke-write")

    if args.raw_root is None:
        ap.error("--raw-root required unless --smoke-write")

    script_dir = Path(__file__).resolve().parent
    reg = args.registry or (script_dir / "T_end_registry.yaml")
    if not reg.is_file():
        raise SystemExit(f"missing registry: {reg}")
    t_end_map = load_t_end_ns(reg)

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "system_id",
        "metric",
        "xvg_file",
        "window_t_start_ns",
        "window_t_end_ns",
        "window_kind",
        "n_points",
        "mean",
        "std",
    ]
    with args.out_csv.open("w", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=fieldnames)
        w.writeheader()
        for sid in ALL_SYSTEMS:
            t_end = t_end_map.get(sid)
            if t_end is None:
                raise SystemExit(f"no T_end_ns for {sid} in {reg}")
            t0w = max(0.0, t_end - args.window_ns)
            t1w = t_end
            sub = args.raw_root / sid
            for metric, fname in METRIC_FILES.items():
                p = sub / fname
                row = {
                    "system_id": sid,
                    "metric": metric,
                    "xvg_file": str(p),
                    "window_t_start_ns": "",
                    "window_t_end_ns": "",
                    "window_kind": "",
                    "n_points": "",
                    "mean": "",
                    "std": "",
                }
                if not p.is_file():
                    row["window_kind"] = "missing_file"
                    w.writerow(row)
                    continue
                if metric == "rmsf_residue":
                    x, y = read_xvg_xy(p)
                    mu, sd = mean_std_vector(y)
                    row["window_t_start_ns"] = "NA"
                    row["window_t_end_ns"] = "NA"
                    row["window_kind"] = "rmsf_across_residues"
                    row["n_points"] = str(int(np.sum(np.isfinite(y))))
                    row["mean"] = f"{mu:.8g}"
                    row["std"] = f"{sd:.8g}"
                    w.writerow(row)
                    continue
                t, y = read_xvg_xy(p)
                st = window_stats(t, y, t0w, t1w)
                row["window_t_start_ns"] = f"{t0w:.8g}"
                row["window_t_end_ns"] = f"{t1w:.8g}"
                row["window_kind"] = "time_tail"
                row["n_points"] = str(int(st["n"]))
                row["mean"] = f"{st['mean']:.8g}"
                row["std"] = f"{st['std']:.8g}"
                w.writerow(row)

    print(f"Wrote {args.out_csv}")


if __name__ == "__main__":
    main()
