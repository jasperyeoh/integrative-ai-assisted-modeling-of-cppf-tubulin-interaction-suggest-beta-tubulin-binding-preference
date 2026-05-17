#!/usr/bin/env python3
"""
Monomer α vs β — time series comparison (0–200 ns) with three replicates.

Layout (row-major):
  [ A: alpha ligand RMSD ]  [ B: beta ligand RMSD ]
  [ C: alpha mindist     ]  [ D: beta mindist     ]

Input directory structure:
  raw_xvg/<system_id>/{rmsd_ligand.xvg,mindist_pl.xvg}

Output:
  TIFF (LZW) or PNG/SVG/PDF via revision_figure_export.save_figure.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:  # pragma: no cover
    raise SystemExit("matplotlib is required: pip install matplotlib") from e

from revision_figure_export import save_figure
from revision_xvg_io import read_xvg_xy

ALPHA = ["monomer_alpha_rep1", "monomer_alpha_rep2", "monomer_alpha_rep3"]
BETA = ["monomer_beta_rep1", "monomer_beta_rep2", "monomer_beta_rep3"]


def _apply_plos_style() -> None:
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 10,
            "axes.titlesize": 10,
            "axes.labelsize": 10,
            "xtick.labelsize": 9,
            "ytick.labelsize": 9,
            "legend.fontsize": 8,
        }
    )


def _panel_label(ax: "plt.Axes", lab: str) -> None:
    ax.text(
        0.01,
        0.99,
        lab,
        transform=ax.transAxes,
        fontsize=22,
        fontweight="bold",
        ha="left",
        va="top",
        color="black",
    )


def _plot_reps(ax: "plt.Axes", raw_root: Path, systems: list[str], fname: str, colors: tuple[str, str, str]) -> None:
    for sid, c in zip(systems, colors):
        p = raw_root / sid / fname
        if not p.is_file():
            continue
        t, y = read_xvg_xy(p)
        ax.plot(t, y, color=c, lw=1.0, alpha=0.95, label=sid.split("_")[-1])


def main() -> None:
    _apply_plos_style()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw-root", type=Path, required=True)
    ap.add_argument("--t-end-ns", type=float, default=200.0)
    ap.add_argument("--out-fig", type=Path, required=True)
    ap.add_argument("--dpi", type=int, default=300)
    ap.add_argument(
        "--fig-format",
        default="tif",
        choices=("tif", "tiff", "png", "svg", "pdf", "eps"),
        help="Output format (default TIFF LZW)",
    )
    args = ap.parse_args()

    colors = ("#0072B2", "#D55E00", "#009E73")  # rep1/2/3 (Okabe-Ito)

    fig, axes = plt.subplots(2, 2, figsize=(9.0, 6.8), sharex=True)

    # A/B: ligand RMSD
    _plot_reps(axes[0, 0], args.raw_root, ALPHA, "rmsd_ligand.xvg", colors)
    _plot_reps(axes[0, 1], args.raw_root, BETA, "rmsd_ligand.xvg", colors)
    axes[0, 0].set_title("α-tubulin monomer — ligand RMSD")
    axes[0, 1].set_title("β-tubulin monomer — ligand RMSD")
    axes[0, 0].set_ylabel("RMSD ligand (nm)")
    axes[0, 1].set_ylabel("RMSD ligand (nm)")

    # C/D: mindist
    _plot_reps(axes[1, 0], args.raw_root, ALPHA, "mindist_pl.xvg", colors)
    _plot_reps(axes[1, 1], args.raw_root, BETA, "mindist_pl.xvg", colors)
    axes[1, 0].set_title("α-tubulin monomer — mindist")
    axes[1, 1].set_title("β-tubulin monomer — mindist")
    axes[1, 0].set_ylabel("Min distance protein–ligand (nm)")
    axes[1, 1].set_ylabel("Min distance protein–ligand (nm)")

    for ax in axes.ravel():
        ax.grid(True, alpha=0.25)
        ax.set_xlim(0.0, float(args.t_end_ns))
        ax.legend(loc="best", fontsize=8, frameon=False)

    for ax, lab in zip(axes.ravel(), ("A", "B", "C", "D")):
        _panel_label(ax, lab)

    for ax in axes[1, :]:
        ax.set_xlabel("Time (ns)")

    fig.suptitle("Monomer α vs β — replicate time series (0–200 ns)", fontsize=12)
    fig.tight_layout()
    args.out_fig.parent.mkdir(parents=True, exist_ok=True)
    save_figure(fig, args.out_fig, dpi=args.dpi, fig_format=args.fig_format)
    plt.close(fig)
    print(f"Wrote {args.out_fig}")


if __name__ == "__main__":
    main()

