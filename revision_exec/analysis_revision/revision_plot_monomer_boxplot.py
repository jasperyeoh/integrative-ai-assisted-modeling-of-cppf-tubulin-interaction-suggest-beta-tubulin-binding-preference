#!/usr/bin/env python3
"""
Step 3: α vs β monomer comparison — 2×2 panel boxplots (last window_ns before T_end),
with jittered n=3 replicate points per group.

Panels (row-major):
  [ mindist_pl ]  [ binding_site_rmsf (last 50 ns; mean of residues 236/253/314) ]
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

# Tubulin residue numbers (1-based in the structure) for the binding-pocket summary.
BINDING_SITE_RESIDUES: tuple[int, ...] = (236, 253, 314)

# (metric_key, xvg_filename, y_label, kind)
# kind "ts" = time-series xvg (pool per-frame values in the window; overlay n=3 replicate means).
# kind "rmsf_mean" = gmx rmsf -res xvg (one curve); take mean RMSF at BINDING_SITE_RESIDUES → one value per replicate.
PANELS: list[tuple[str, str, str, str]] = [
    ("mindist_pl", "mindist_pl.xvg", "Min distance protein–ligand (nm)", "ts"),
    (
        "binding_site_rmsf",
        "rmsf_binding_site_last50ns.xvg",
        "Binding-site RMSF (nm)\n(mean of residues 236, 253, 314; last 50 ns)",
        "rmsf_mean",
    ),
    ("rmsd_ligand", "rmsd_ligand.xvg", "RMSD ligand (nm)", "ts"),
    ("rg", "rg.xvg", "Rg protein (nm)", "ts"),
]

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

def window_values(t: np.ndarray, y: np.ndarray, t0: float, t1: float) -> np.ndarray:
    """Return per-frame values inside [t0,t1] (for boxplot distributions)."""
    m = window_mask(t, t0, t1) & np.isfinite(y)
    return y[m]


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


def collect_group_values(raw_root: Path, systems: list[str], fname: str, t0: float, t1: float) -> list[np.ndarray]:
    out: list[np.ndarray] = []
    for sid in systems:
        p = raw_root / sid / fname
        if not p.is_file():
            out.append(np.array([], dtype=float))
            continue
        t, y = read_xvg_xy(p)
        out.append(window_values(t, y, t0, t1))
    return out


def parse_rmsf_residue_map(path: Path) -> dict[int, float]:
    """Parse `gmx rmsf -res` xvg: x = residue index, y = RMSF (nm)."""
    m: dict[int, float] = {}
    for line in path.read_text(errors="replace").splitlines():
        if not line.strip() or line[0] in "#@&":
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        try:
            resi = int(float(parts[0]))
            m[resi] = float(parts[1])
        except ValueError:
            continue
    return m


def mean_binding_site_rmsf(path: Path, residues: tuple[int, ...]) -> float:
    m = parse_rmsf_residue_map(path)
    vals: list[float] = []
    for r in residues:
        if r not in m:
            return float("nan")
        vals.append(m[r])
    return float(np.mean(vals))


def collect_group_binding_rmsf(raw_root: Path, systems: list[str], fname: str) -> list[float]:
    out: list[float] = []
    for sid in systems:
        p = raw_root / sid / fname
        if not p.is_file():
            out.append(float("nan"))
            continue
        out.append(mean_binding_site_rmsf(p, BINDING_SITE_RESIDUES))
    return out


def main() -> None:
    _apply_plos_style()
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

    for ax, (metric, fname, ylab, kind) in zip(axes_flat, PANELS):
        if kind == "ts":
            # Box = pooled per-frame distribution (alpha reps pooled vs beta reps pooled)
            # Points = per-rep means, preserving the n=3 replicate structure explicitly.
            a_series = collect_group_values(args.raw_root, ALPHA, fname, t0w, t1w)
            b_series = collect_group_values(args.raw_root, BETA, fname, t0w, t1w)
            a_pool = (
                np.concatenate([x for x in a_series if x.size], dtype=float)
                if any(x.size for x in a_series)
                else np.array([], dtype=float)
            )
            b_pool = (
                np.concatenate([x for x in b_series if x.size], dtype=float)
                if any(x.size for x in b_series)
                else np.array([], dtype=float)
            )
            data = [a_pool, b_pool]
            a_means = [float(np.mean(x)) if x.size else float("nan") for x in a_series]
            b_means = [float(np.mean(x)) if x.size else float("nan") for x in b_series]
        elif kind == "rmsf_mean":
            a_means = collect_group_binding_rmsf(args.raw_root, ALPHA, fname)
            b_means = collect_group_binding_rmsf(args.raw_root, BETA, fname)
            data = [np.array(a_means, dtype=float), np.array(b_means, dtype=float)]
        else:  # pragma: no cover
            raise SystemExit(f"unknown panel kind: {kind}")

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
        for i, vals in enumerate([a_means, b_means]):
            xj = i + rng.uniform(-0.09, 0.09, size=len(vals))
            ax.scatter(xj, vals, color="0.15", s=28, alpha=0.9, zorder=3, linewidths=0)
        ax.set_ylabel(ylab)
        ax.set_title(metric)
        ax.grid(True, axis="y", alpha=0.25)

    for ax, lab in zip(axes_flat, ("A", "B", "C", "D")):
        _panel_label(ax, lab)

    fig.suptitle(f"{args.title}\nwindow [{t0w:.1f}, {t1w:.1f}] ns", fontsize=11)
    fig.tight_layout()
    args.out_fig.parent.mkdir(parents=True, exist_ok=True)
    save_figure(fig, args.out_fig, dpi=args.dpi, fig_format=args.fig_format)
    plt.close(fig)
    print(f"Wrote {args.out_fig}")


if __name__ == "__main__":
    main()
