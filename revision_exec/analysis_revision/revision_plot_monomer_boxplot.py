#!/usr/bin/env python3
"""
Step 3: α vs β monomer comparison — 2×2 panel boxplots (last window_ns before T_end),
with jittered n=3 replicate points per group.

Panels (row-major):
  [ mindist_pl ]  [ hbond_num ]
  [ rmsd_ligand ] [ rg ]

Colours: α #F48FB1, β #81D4FA (default).
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
from revision_xvg_io import read_xvg_xy, window_mask

ALPHA = ["monomer_alpha_rep1", "monomer_alpha_rep2", "monomer_alpha_rep3"]
BETA = ["monomer_beta_rep1", "monomer_beta_rep2", "monomer_beta_rep3"]

PANELS: list[tuple[str, str, str]] = [
    ("mindist_pl", "mindist_pl.xvg", "Min distance protein–ligand (nm)"),
    ("hbond_num", "hbond_num.xvg", "H-bonds (#)"),
    ("rmsd_ligand", "rmsd_ligand.xvg", "RMSD ligand (nm)"),
    ("rg", "rg.xvg", "Rg protein (nm)"),
]


def load_t_end_ns(registry: Path) -> dict[str, float]:
    import re

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


def window_mean(t: np.ndarray, y: np.ndarray, t0: float, t1: float) -> float:
    m = window_mask(t, t0, t1) & np.isfinite(y)
    yy = y[m]
    if yy.size == 0:
        return float("nan")
    return float(np.mean(yy))


def collect_group(raw_root: Path, systems: list[str], fname: str, t0: float, t1: float) -> list[float]:
    vals: list[float] = []
    for sid in systems:
        p = raw_root / sid / fname
        if not p.is_file():
            vals.append(float("nan"))
            continue
        t, y = read_xvg_xy(p)
        vals.append(window_mean(t, y, t0, t1))
    return vals


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw-root", type=Path, required=True, help="raw_xvg parent (contains monomer_* subdirs)")
    ap.add_argument(
        "--registry",
        type=Path,
        default=None,
        help="T_end_registry.yaml (default: next to this script)",
    )
    ap.add_argument("--window-ns", type=float, default=50.0)
    ap.add_argument("--alpha-color", default="#F48FB1")
    ap.add_argument("--beta-color", default="#81D4FA")
    ap.add_argument("--title", default="Monomer α vs β — last-window distribution (n=3)")
    ap.add_argument("--out-fig", type=Path, required=True)
    ap.add_argument("--dpi", type=int, default=300, help="Raster DPI (default 300)")
    ap.add_argument(
        "--fig-format",
        default="tif",
        choices=("tif", "tiff", "png", "svg", "pdf", "eps"),
        help="Output format (default TIFF LZW)",
    )
    args = ap.parse_args()

    script_dir = Path(__file__).resolve().parent
    reg = args.registry or (script_dir / "T_end_registry.yaml")
    t_end_map = load_t_end_ns(reg)
    t_end = t_end_map["monomer_alpha_rep1"]
    for sid in ALPHA + BETA:
        if abs(t_end_map[sid] - t_end) > 1e-6:
            raise SystemExit("expected identical T_end_ns for all monomers")
    t0w = max(0.0, t_end - args.window_ns)
    t1w = t_end

    fig, axes = plt.subplots(2, 2, figsize=(8.5, 7.0), sharex=False)
    axes_flat = axes.ravel()
    rng = np.random.default_rng(1)

    for ax, (metric, fname, ylab) in zip(axes_flat, PANELS):
        a_vals = collect_group(args.raw_root, ALPHA, fname, t0w, t1w)
        b_vals = collect_group(args.raw_root, BETA, fname, t0w, t1w)
        data = [a_vals, b_vals]
        bp = ax.boxplot(
            data,
            positions=[0, 1],
            widths=0.45,
            patch_artist=True,
            showfliers=False,
        )
        ax.set_xticks([0, 1])
        ax.set_xticklabels(["α (n=3)", "β (n=3)"])
        bp["boxes"][0].set_facecolor(args.alpha_color)
        bp["boxes"][0].set_alpha(0.55)
        bp["boxes"][1].set_facecolor(args.beta_color)
        bp["boxes"][1].set_alpha(0.55)
        for i, vals in enumerate(data):
            xj = i + rng.uniform(-0.09, 0.09, size=len(vals))
            ax.scatter(xj, vals, color="0.15", s=22, alpha=0.85, zorder=3, linewidths=0)
        ax.set_ylabel(ylab)
        ax.set_title(metric)
        ax.grid(True, axis="y", alpha=0.25)

    fig.suptitle(f"{args.title}\nwindow [{t0w:.1f}, {t1w:.1f}] ns", fontsize=11)
    fig.tight_layout()
    args.out_fig.parent.mkdir(parents=True, exist_ok=True)
    save_figure(fig, args.out_fig, dpi=args.dpi, fig_format=args.fig_format)
    plt.close(fig)
    print(f"Wrote {args.out_fig}")


if __name__ == "__main__":
    main()
