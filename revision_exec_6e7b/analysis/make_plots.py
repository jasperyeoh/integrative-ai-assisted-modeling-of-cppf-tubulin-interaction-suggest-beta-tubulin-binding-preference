#!/usr/bin/env python3
"""
6E7B Full Analysis — statistics + plots + summary.md

Reads the XVG outputs from run_full_analysis.sh, generates:
  - Per-rep panels (RMSD, Rg, mindist, H-bond) — 3-rep min/max band style
  - 2D FEL via Boltzmann inversion of concatenated (RMSD, Rg)
  - 5IJ0 vs 6E7B comparison panels (if 5IJ0 numbers available)
  - summary.md with numbers ready for Response Letter [TBD] placeholders

Designed to match the visual style of the 5IJ0 main-text figures
(shared axis limits, shared free-energy color scale).
"""
import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

# 5IJ0 main-text reference values (from manuscript and 5IJ0 analysis)
# These are used for comparison panels and the summary table.
IJ0_REF = {
    "n_reps": 3,
    "duration_ns": 400,
    "rmsd_last100_mean": [0.30, 0.55, 0.65],   # per replicate (nm)
    "mindist_last100_mean": 0.19,                # across-replicate (nm)
    "fel_min_rmsd": 0.43,                        # nm
    "fel_min_rg": 2.19,                          # nm
    "mmpbsa_kcalmol": -31.19,                    # ± 4.04
}

# Shared color/style
COLORS = ["#1f77b4", "#ff7f0e", "#2ca02c"]      # rep1/2/3
FEL_CMAP = "viridis_r"


def read_xvg(path):
    """Return (t_ns, y) or (None, None) if file missing/empty."""
    if not os.path.exists(path):
        return None, None
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith(("#", "@", "&")):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            try:
                rows.append((float(parts[0]), float(parts[1])))
            except ValueError:
                continue
    if not rows:
        return None, None
    a = np.array(rows)
    return a[:, 0], a[:, 1]


def last_window_stats(t, y, t_min=150, t_max=200):
    """Mean ± std in time window (ns)."""
    if t is None:
        return None, None, 0
    mask = (t >= t_min) & (t <= t_max)
    if not mask.any():
        return None, None, 0
    return float(y[mask].mean()), float(y[mask].std()), int(mask.sum())


def load_rep_series(out_dir, n_reps, metric):
    """Return list of (t, y) for each rep, may contain (None, None)."""
    series = []
    for i in range(1, n_reps + 1):
        t, y = read_xvg(f"{out_dir}/timeseries/rep{i}/{metric}.xvg")
        series.append((t, y))
    return series


def plot_timeseries_panel(out_dir, series_list, ylabel, title, fname,
                           ymin=None, ymax=None, ref_value=None, ref_label=None):
    fig, ax = plt.subplots(figsize=(8, 4.2))
    for i, (t, y) in enumerate(series_list):
        if t is None:
            continue
        ax.plot(t, y, color=COLORS[i], alpha=0.8, lw=1.0, label=f"rep{i+1}")
    # Min/max band
    valid = [(t, y) for t, y in series_list if t is not None]
    if len(valid) >= 2:
        # Resample to common grid for band
        t_min = max(v[0].min() for v in valid)
        t_max = min(v[0].max() for v in valid)
        grid = np.linspace(t_min, t_max, 500)
        ys = np.array([np.interp(grid, t, y) for t, y in valid])
        ax.fill_between(grid, ys.min(axis=0), ys.max(axis=0),
                        color="gray", alpha=0.15, label="min-max band")
    if ref_value is not None:
        ax.axhline(ref_value, ls="--", color="red", lw=1,
                   label=ref_label or f"5IJ0 ref = {ref_value}")
    ax.set_xlabel("Time (ns)")
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    if ymin is not None or ymax is not None:
        ax.set_ylim(ymin, ymax)
    ax.legend(loc="best", fontsize=8)
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(f"{out_dir}/plots/{fname}", dpi=200)
    plt.close(fig)
    print(f"  → plots/{fname}")


def build_fel(rmsd_path, rg_path, t_min_ns=0, kT=0.5961):
    """
    Boltzmann inversion of concatenated (RMSD, Rg) joint distribution.
    Returns (X, Y, dG) on a 2D grid, all in nm and kcal/mol.
    """
    t_r, rmsd = read_xvg(rmsd_path)
    t_g, rg = read_xvg(rg_path)
    if t_r is None or t_g is None:
        return None
    # Align lengths
    n = min(len(rmsd), len(rg))
    rmsd, rg = rmsd[:n], rg[:n]
    # Histogram
    H, x_edges, y_edges = np.histogram2d(rmsd, rg, bins=40, density=True)
    H = H.T
    H_smooth = H + 1e-12
    dG = -kT * np.log(H_smooth / H_smooth.max())
    dG = np.clip(dG, 0, 5.0)   # cap at 5 kcal/mol like 5IJ0 plots
    Xc = 0.5 * (x_edges[:-1] + x_edges[1:])
    Yc = 0.5 * (y_edges[:-1] + y_edges[1:])
    X, Y = np.meshgrid(Xc, Yc)
    # Find min
    idx = np.unravel_index(np.argmin(dG), dG.shape)
    min_rmsd, min_rg = Xc[idx[1]], Yc[idx[0]]
    return X, Y, dG, (min_rmsd, min_rg)


def plot_fel(out_dir, fel_data):
    if fel_data is None:
        print("  FEL skipped (concat data missing)")
        return
    X, Y, dG, (mr, mg) = fel_data
    fig, ax = plt.subplots(figsize=(7, 5.5))
    cs = ax.contourf(X, Y, dG, levels=20, cmap=FEL_CMAP, vmin=0, vmax=5)
    ax.contour(X, Y, dG, levels=10, colors="white", alpha=0.4, lw=0.4)
    ax.plot(mr, mg, "r*", markersize=18, label=f"min: ({mr:.2f}, {mg:.2f})")
    cb = fig.colorbar(cs, ax=ax)
    cb.set_label("ΔG (kcal/mol)")
    ax.set_xlabel("Backbone RMSD (nm)")
    ax.set_ylabel("Rg (nm)")
    ax.set_title("6E7B Free Energy Landscape (3 reps concatenated)")
    ax.legend(loc="best")
    fig.tight_layout()
    fig.savefig(f"{out_dir}/plots/fel_6e7b_2d.png", dpi=200)
    plt.close(fig)
    print(f"  → plots/fel_6e7b_2d.png")


def write_summary(out_dir, n_reps):
    """Write summary.md with all numbers needed for Response Letter [TBD]."""
    lines = []
    lines.append("# 6E7B Analysis Summary\n")
    lines.append(f"**Replicates analyzed:** {n_reps} × 200 ns\n")
    lines.append(f"**5IJ0 reference:** {IJ0_REF['n_reps']} reps × {IJ0_REF['duration_ns']} ns\n\n")
    lines.append("---\n\n")

    lines.append("## Table 1 — Backbone RMSD (last 50 ns, 150–200 ns)\n\n")
    lines.append("| Rep | Mean (nm) | Std (nm) | Status |\n")
    lines.append("|-----|-----------|----------|--------|\n")
    rmsd_means = []
    for i in range(1, n_reps + 1):
        t, y = read_xvg(f"{out_dir}/timeseries/rep{i}/rmsd_backbone.xvg")
        m, s, n = last_window_stats(t, y)
        if m is None:
            lines.append(f"| rep{i} | — | — | missing |\n")
        else:
            rmsd_means.append(m)
            lines.append(f"| rep{i} | {m:.3f} | {s:.3f} | {n} frames |\n")
    if rmsd_means:
        lines.append(f"\n**6E7B across-rep mean: {np.mean(rmsd_means):.3f} ± {np.std(rmsd_means):.3f} nm**\n")
        lines.append(f"**5IJ0 main-text per-rep: {IJ0_REF['rmsd_last100_mean']} nm**\n\n")

    lines.append("---\n\n## Table 2 — min(CPPF–protein) (last 50 ns)\n\n")
    lines.append("| Rep | Mean (nm) | Std (nm) | n frames |\n")
    lines.append("|-----|-----------|----------|----------|\n")
    md_means = []
    for i in range(1, n_reps + 1):
        t, y = read_xvg(f"{out_dir}/timeseries/rep{i}/mindist.xvg")
        m, s, n = last_window_stats(t, y)
        if m is None:
            lines.append(f"| rep{i} | — | — | missing |\n")
        else:
            md_means.append(m)
            lines.append(f"| rep{i} | {m:.3f} | {s:.3f} | {n} |\n")
    if md_means:
        lines.append(f"\n**6E7B across-rep mean: {np.mean(md_means):.3f} ± {np.std(md_means):.3f} nm**\n")
        lines.append(f"**5IJ0 main-text: ~{IJ0_REF['mindist_last100_mean']} nm (0.14–0.24 range)**\n\n")

    lines.append("---\n\n## Table 3 — Pocket residue distances (last 50 ns)\n\n")
    lines.append("| Rep | VAL236 (nm) | LEU253 (nm) | ALA314 (nm) |\n")
    lines.append("|-----|-------------|-------------|-------------|\n")
    for i in range(1, n_reps + 1):
        row = [f"rep{i}"]
        for res in ("VAL236", "LEU253", "ALA314"):
            path = f"{out_dir}/pocket/rep{i}_{res}_mindist.xvg"
            t, y = read_xvg(path)
            if t is None:
                row.append("—")
            else:
                row.append(f"{y.mean():.3f} ± {y.std():.3f}")
        lines.append("| " + " | ".join(row) + " |\n")

    lines.append("\n*5IJ0 monomer ref: LEU253 0.64–1.36 nm, ALA314 0.90–1.59 nm (partial disengagement in monomers).*\n")
    lines.append("*5IJ0 dimer ref: stable interfacial contact 0.14–0.24 nm.*\n\n")

    lines.append("---\n\n## Table 4 — FEL global minimum\n\n")
    rmsd_path = f"{out_dir}/fel/concat_rmsd.xvg"
    rg_path = f"{out_dir}/fel/concat_rg.xvg"
    fel = build_fel(rmsd_path, rg_path)
    if fel is not None:
        _, _, _, (mr, mg) = fel
        lines.append(f"| System | Rg min (nm) | RMSD min (nm) |\n")
        lines.append(f"|--------|-------------|---------------|\n")
        lines.append(f"| **6E7B (this work)** | {mg:.2f} | {mr:.2f} |\n")
        lines.append(f"| 5IJ0 β (main text)   | {IJ0_REF['fel_min_rg']} | {IJ0_REF['fel_min_rmsd']} |\n\n")
    else:
        lines.append("FEL: not generated (missing data)\n\n")

    lines.append("---\n\n## Verdict — for Response Letter Comment 4.2\n\n")
    if rmsd_means and md_means:
        rmsd_overall = np.mean(rmsd_means)
        md_overall = np.mean(md_means)
        verdict = "STABLE" if (rmsd_overall < 0.5 and md_overall < 0.30) else "PARTIAL"
        lines.append(f"**Binding stability verdict: {verdict}**\n\n")
        if verdict == "STABLE":
            lines.append("> Across all 3 replicates of 200 ns MD on the 6E7B β-GTP/microtubule-lattice "
                         f"conformation, CPPF remained stably bound: backbone RMSD plateaued at "
                         f"{rmsd_overall:.3f} ± {np.std(rmsd_means):.3f} nm and the minimum CPPF–protein "
                         f"distance was {md_overall:.3f} ± {np.std(md_means):.3f} nm (last 50 ns mean ± "
                         f"across-replicate s.d.). This is comparable to the 5IJ0 main-text dimer simulations "
                         f"(min distance 0.14–0.24 nm) and indicates that CPPF retains a stable binding mode "
                         f"in the alternative β-tubulin conformational state.\n")
    lines.append("\n---\n")
    lines.append("*Generated by `make_plots.py`. Numbers ready to paste into `RESPONSE_TO_REVIEWERS.md` "
                 "Comment 4.2 `[TO BE FILLED IN]` block and `main.tex` 6E7B Results subsection.*\n")

    with open(f"{out_dir}/summary.md", "w") as f:
        f.writelines(lines)
    print(f"  → summary.md")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--reps", type=int, default=3)
    args = ap.parse_args()

    OUT = args.out
    N = args.reps
    print(f"Plotting from {OUT}, {N} replicates")

    # Per-metric panels
    print("\n[1/4] Time-series panels...")
    plot_timeseries_panel(
        OUT, load_rep_series(OUT, N, "rmsd_backbone"),
        "Backbone RMSD (nm)", "6E7B Backbone RMSD",
        "ts_rmsd_backbone.png", ymin=0, ymax=0.8,
    )
    plot_timeseries_panel(
        OUT, load_rep_series(OUT, N, "rmsd_ligand"),
        "Ligand RMSD (nm)", "6E7B CPPF Ligand RMSD",
        "ts_rmsd_ligand.png", ymin=0, ymax=0.6,
    )
    plot_timeseries_panel(
        OUT, load_rep_series(OUT, N, "mindist"),
        "min(CPPF–protein) (nm)", "6E7B Minimum CPPF–Protein Distance",
        "ts_mindist.png", ymin=0.1, ymax=0.35,
        ref_value=IJ0_REF["mindist_last100_mean"],
        ref_label=f"5IJ0 ref = {IJ0_REF['mindist_last100_mean']} nm",
    )
    plot_timeseries_panel(
        OUT, load_rep_series(OUT, N, "rg"),
        "Rg (nm)", "6E7B Radius of Gyration",
        "ts_rg.png",
    )
    plot_timeseries_panel(
        OUT, load_rep_series(OUT, N, "hbond_num"),
        "H-bond count", "6E7B CPPF–Protein H-bonds",
        "ts_hbond.png", ymin=0,
    )

    # FEL
    print("\n[2/4] Free energy landscape...")
    fel = build_fel(f"{OUT}/fel/concat_rmsd.xvg", f"{OUT}/fel/concat_rg.xvg")
    plot_fel(OUT, fel)

    # Summary numbers
    print("\n[3/4] Summary statistics + summary.md...")
    write_summary(OUT, N)

    # Combined 5IJ0 vs 6E7B comparison panel (placeholder)
    print("\n[4/4] 5IJ0 vs 6E7B comparison panel...")
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    # 6E7B mindist
    series = load_rep_series(OUT, N, "mindist")
    for i, (t, y) in enumerate(series):
        if t is not None:
            axes[0].plot(t, y, color=COLORS[i], alpha=0.7, label=f"6E7B rep{i+1}")
    axes[0].axhline(IJ0_REF["mindist_last100_mean"], ls="--", color="red",
                    label=f"5IJ0 ref ({IJ0_REF['mindist_last100_mean']} nm)")
    axes[0].set_xlabel("Time (ns)")
    axes[0].set_ylabel("min(CPPF–protein) (nm)")
    axes[0].set_title("CPPF–protein contact stability")
    axes[0].set_ylim(0.1, 0.35)
    axes[0].legend(fontsize=8)
    axes[0].grid(alpha=0.3)
    # 6E7B RMSD
    series = load_rep_series(OUT, N, "rmsd_backbone")
    for i, (t, y) in enumerate(series):
        if t is not None:
            axes[1].plot(t, y, color=COLORS[i], alpha=0.7, label=f"6E7B rep{i+1}")
    for i, ref in enumerate(IJ0_REF["rmsd_last100_mean"]):
        axes[1].axhline(ref, ls=":", color="red", alpha=0.5,
                       label=f"5IJ0 rep{i+1} ref" if i == 0 else None)
    axes[1].set_xlabel("Time (ns)")
    axes[1].set_ylabel("Backbone RMSD (nm)")
    axes[1].set_title("Backbone stability")
    axes[1].set_ylim(0, 0.8)
    axes[1].legend(fontsize=8)
    axes[1].grid(alpha=0.3)
    fig.suptitle("6E7B (this work) vs 5IJ0 main-text reference", fontweight="bold")
    fig.tight_layout()
    fig.savefig(f"{OUT}/plots/compare_5ij0_vs_6e7b.png", dpi=200)
    plt.close(fig)
    print(f"  → plots/compare_5ij0_vs_6e7b.png")

    print("\nDone.")


if __name__ == "__main__":
    main()
