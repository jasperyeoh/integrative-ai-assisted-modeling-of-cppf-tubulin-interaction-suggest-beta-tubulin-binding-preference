#!/usr/bin/env python3
"""
Step 3 (revision): dimer three-replicate time series.

Modes:
  single  — one metric, three --xvg entries, min–max band + per-rep window CSV.
  panels  — 2×2 figure: [rmsd_backbone, rg] / [mindist_pl, hbond_num], each panel three reps + band.

Read path: two-column .xvg (t_ns, y); skip #/@/& (see revision_xvg_io).

Examples:
  python revision_plot_dimer_timeseries.py --mode single \\
    --xvg rep1 raw_xvg/dimer_rep1/rmsd_backbone_FORMAT_CHECK.xvg \\
    --xvg rep2 raw_xvg/dimer_rep1/rmsd_backbone_FORMAT_CHECK.xvg \\
    --xvg rep3 raw_xvg/dimer_rep1/rmsd_backbone_FORMAT_CHECK.xvg \\
    --metric rmsd_backbone --t-end-ns 2 --window-ns 0.5 \\
    --out-fig figures/_smoke_dimer_bb.tif --out-csv tables/_smoke_dimer_bb.csv

  python revision_plot_dimer_timeseries.py --mode panels --raw-root _smoke/raw_xvg \\
    --t-end-ns 400 --window-ns 50 --out-fig figures/_smoke_dimer_panels.tif
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Iterable

import numpy as np

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:  # pragma: no cover
    raise SystemExit("matplotlib is required: pip install matplotlib") from e

from revision_figure_export import save_figure
from revision_xvg_io import read_xvg_xy, window_stats

DIMER_REPS = ("dimer_rep1", "dimer_rep2", "dimer_rep3")
PANEL_METRICS: list[tuple[str, str, str]] = [
    ("rmsd_backbone", "rmsd_backbone.xvg", "Backbone RMSD (nm)"),
    ("rg", "rg.xvg", "Rg protein (nm)"),
    ("mindist_pl", "mindist_pl.xvg", "Min dist protein–ligand (nm)"),
    ("hbond_num", "hbond_num.xvg", "H-bonds (#)"),
]


def align_on_grid(
    series: Iterable[tuple[np.ndarray, np.ndarray]],
    t_min: float,
    t_max: float,
) -> tuple[np.ndarray, np.ndarray]:
    ts_list: list[np.ndarray] = []
    for t, _y in series:
        m = (t >= t_min) & (t <= t_max)
        ts_list.append(np.unique(t[m]))
    if not any(len(x) for x in ts_list):
        raise ValueError("empty time overlap after clipping")
    t_grid = np.unique(np.concatenate(ts_list))
    t_grid.sort()
    ys: list[np.ndarray] = []
    for t, y in series:
        yi = np.interp(t_grid, t, y, left=np.nan, right=np.nan)
        ys.append(yi)
    y_stack = np.vstack(ys)
    return t_grid, y_stack


def run_single(args: argparse.Namespace) -> None:
    reps: list[tuple[str, Path]] = [(lab, Path(p)) for lab, p in args.xvg]
    data: list[tuple[str, np.ndarray, np.ndarray]] = []
    for lab, p in reps:
        if not p.is_file():
            raise SystemExit(f"missing xvg: {p}")
        t, y = read_xvg_xy(p)
        data.append((lab, t, y))

    t_min = 0.0
    t_max = min(args.t_end_ns, max(float(np.max(d[1])) for d in data))
    t_grid, y_stack = align_on_grid([(d[1], d[2]) for d in data], t_min, t_max)
    y_min = np.nanmin(y_stack, axis=0)
    y_max = np.nanmax(y_stack, axis=0)

    args.out_fig.parent.mkdir(parents=True, exist_ok=True)
    args.out_csv.parent.mkdir(parents=True, exist_ok=True)

    fig, ax = plt.subplots(figsize=(9, 4.5))
    colors = ("#0072B2", "#D55E00", "#009E73")
    for i, (lab, t, y) in enumerate(data):
        c = colors[i % len(colors)]
        ax.plot(t, y, color=c, lw=0.9, label=str(lab), alpha=0.95)
    ax.fill_between(t_grid, y_min, y_max, color="0.5", alpha=0.22, linewidth=0, label="min–max across reps")
    ax.set_xlabel(args.xlabel)
    ax.set_ylabel(args.ylabel)
    ax.set_title(args.title)
    ax.set_xlim(t_min, t_max)
    ax.legend(loc="best", fontsize=8)
    ax.grid(True, alpha=0.25)
    fig.tight_layout()
    save_figure(fig, args.out_fig, dpi=args.dpi, fig_format=args.fig_format)
    plt.close(fig)

    t0w = max(t_min, args.t_end_ns - args.window_ns)
    t1w = args.t_end_ns

    with args.out_csv.open("w", newline="") as fp:
        w = csv.DictWriter(
            fp,
            fieldnames=[
                "metric",
                "replicate",
                "t_window_start_ns",
                "t_window_end_ns",
                "n_points",
                "mean",
                "std",
                "p25",
                "p50",
                "p75",
            ],
        )
        w.writeheader()
        for lab, t, y in data:
            st = window_stats(t, y, t0w, t1w)
            w.writerow(
                {
                    "metric": args.metric,
                    "replicate": lab,
                    "t_window_start_ns": f"{t0w:.6g}",
                    "t_window_end_ns": f"{t1w:.6g}",
                    "n_points": int(st["n"]),
                    "mean": f"{st['mean']:.8g}",
                    "std": f"{st['std']:.8g}",
                    "p25": f"{st['p25']:.8g}",
                    "p50": f"{st['p50']:.8g}",
                    "p75": f"{st['p75']:.8g}",
                }
            )

    print(f"Wrote {args.out_fig}")
    print(f"Wrote {args.out_csv}")


def run_panels(args: argparse.Namespace) -> None:
    raw = Path(args.raw_root)
    colors = ("#0072B2", "#D55E00", "#009E73")
    labels = ("rep1", "rep2", "rep3")
    fig, axes = plt.subplots(2, 2, figsize=(10.5, 7.2))
    t_min = 0.0
    t0w = max(0.0, args.t_end_ns - args.window_ns)
    t1w = args.t_end_ns

    for ax, (metric, fname, ylab) in zip(axes.ravel(), PANEL_METRICS):
        data: list[tuple[str, np.ndarray, np.ndarray]] = []
        for rep, lab in zip(DIMER_REPS, labels):
            p = raw / rep / fname
            if not p.is_file():
                ax.text(0.5, 0.5, f"missing\n{p.name}", ha="center", va="center", transform=ax.transAxes)
                ax.set_title(metric)
                continue
            t, y = read_xvg_xy(p)
            data.append((lab, t, y))
        if not data:
            continue
        t_max = min(args.t_end_ns, max(float(np.max(d[1])) for d in data))
        t_grid, y_stack = align_on_grid([(d[1], d[2]) for d in data], t_min, t_max)
        y_lo = np.nanmin(y_stack, axis=0)
        y_hi = np.nanmax(y_stack, axis=0)
        ax.fill_between(t_grid, y_lo, y_hi, color="0.5", alpha=0.2, linewidth=0)
        for i, (lab, t, y) in enumerate(data):
            ax.plot(t, y, color=colors[i % len(colors)], lw=0.85, label=lab, alpha=0.95)
        ax.set_xlim(t_min, t_max)
        ax.set_ylabel(ylab)
        ax.set_title(metric)
        ax.grid(True, alpha=0.25)
        ax.legend(loc="best", fontsize=7)

    for ax in axes[1, :]:
        ax.set_xlabel("Time (ns)")
    fig.suptitle("Heterodimer — three replicates (convergence)", fontsize=12)
    fig.tight_layout()
    args.out_fig.parent.mkdir(parents=True, exist_ok=True)
    save_figure(fig, args.out_fig, dpi=args.dpi, fig_format=args.fig_format)
    plt.close(fig)

    if args.out_csv is not None:
        args.out_csv.parent.mkdir(parents=True, exist_ok=True)
        with args.out_csv.open("w", newline="") as fp:
            w = csv.DictWriter(
                fp,
                fieldnames=[
                    "metric",
                    "replicate",
                    "t_window_start_ns",
                    "t_window_end_ns",
                    "n_points",
                    "mean",
                    "std",
                ],
            )
            w.writeheader()
            for metric, fname, _yl in PANEL_METRICS:
                for rep, lab in zip(DIMER_REPS, labels):
                    p = raw / rep / fname
                    if not p.is_file():
                        continue
                    t, y = read_xvg_xy(p)
                    st = window_stats(t, y, t0w, t1w)
                    w.writerow(
                        {
                            "metric": metric,
                            "replicate": lab,
                            "t_window_start_ns": f"{t0w:.6g}",
                            "t_window_end_ns": f"{t1w:.6g}",
                            "n_points": int(st["n"]),
                            "mean": f"{st['mean']:.8g}",
                            "std": f"{st['std']:.8g}",
                        }
                    )
        print(f"Wrote {args.out_csv}")

    print(f"Wrote {args.out_fig}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--mode", choices=("single", "panels"), default="single")
    ap.add_argument(
        "--xvg",
        action="append",
        metavar=("LABEL", "PATH"),
        nargs=2,
        help="(single) replicate label and path; repeat three times",
    )
    ap.add_argument("--metric", default="rmsd_backbone")
    ap.add_argument("--t-end-ns", type=float, required=True)
    ap.add_argument("--window-ns", type=float, default=50.0)
    ap.add_argument("--xlabel", default="Time (ns)")
    ap.add_argument("--ylabel", default="RMSD (nm)")
    ap.add_argument("--title", default="Heterodimer — backbone RMSD (three replicates)")
    ap.add_argument("--raw-root", type=Path, help="(panels) raw_xvg directory")
    ap.add_argument("--out-fig", type=Path, required=True)
    ap.add_argument("--out-csv", type=Path, default=None, help="required for single; optional for panels")
    ap.add_argument("--dpi", type=int, default=300, help="Raster DPI (PLOS: 300–600; default 300)")
    ap.add_argument(
        "--fig-format",
        default="tif",
        choices=("tif", "tiff", "png", "svg", "pdf", "eps"),
        help="Output image format (default tif, LZW for TIFF)",
    )
    args = ap.parse_args()

    if args.mode == "single":
        if not args.xvg or len(args.xvg) < 1:
            ap.error("single mode needs --xvg LABEL PATH (×3 for dimer)")
        if args.out_csv is None:
            ap.error("single mode requires --out-csv")
        run_single(args)
    else:
        if args.raw_root is None:
            ap.error("panels mode requires --raw-root")
        run_panels(args)


if __name__ == "__main__":
    main()
