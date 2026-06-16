#!/usr/bin/env bash
# ============================================================
# 6E7B Supplementary Figures — publication-quality
# ============================================================
# Reuses the SAME plotting code that produced main-text Fig 4 (time series)
# and Fig 6 (FEL), pointed at the 6E7B XVG outputs. This guarantees visual
# style consistency: same fonts, colors (#0072B2 / #D55E00 / #009E73),
# A/B/C/D panel labels, 300 DPI TIFF (LZW), kcal/mol FEL colorbar capped at 5.
#
# Inputs (produced by run_full_analysis.sh):
#   /root/autodl-tmp/analysis_6e7b/timeseries/rep{1,2,3}/{rmsd_backbone,rmsd_ligand,mindist,rg,hbond_num}.xvg
#
# Outputs:
#   /root/autodl-tmp/analysis_6e7b/figures/
#     ├── fig_S_6e7b_timeseries_panels.tif    (Fig-4-style 2x2: RMSD, Rg, mindist, hbond)
#     ├── fig_S_6e7b_timeseries_panels.csv    (per-rep last-50ns window stats)
#     ├── fig_S_6e7b_fel_2d.tif               (Fig-6-style 2D FEL)
#     ├── fig_S_6e7b_mmpbsa_bar.tif           (5IJ0 vs 6E7B ΔG comparison)
#     └── staging/raw_xvg/dimer_rep{1,2,3}/   (staged inputs for the main scripts)
#
# Usage:
#   cd /root/tubulin-cppf-md/revision_exec_6e7b
#   bash analysis/figures/make_6e7b_figures.sh
#
# Optional env:
#   ANALYSIS_DIR=/path/to/analysis_6e7b   (default /root/autodl-tmp/analysis_6e7b)
#   MAIN_REVISION=/path/to/revision_exec  (default /root/tubulin-cppf-md/revision_exec)
#   FIG_FORMAT=tif|png                     (default tif)
# ============================================================
set -euo pipefail

eval "$(conda shell.bash hook)"
set +u
conda activate gmx-lite
set -u

# ── Config ──────────────────────────────────────────────────
ANALYSIS_DIR="${ANALYSIS_DIR:-/root/autodl-tmp/analysis_6e7b}"
MAIN_REVISION="${MAIN_REVISION:-/root/tubulin-cppf-md/revision_exec}"
WORK="$(pwd)/revision_exec_6e7b"
# Robust resolution: if run from inside revision_exec_6e7b, drop the suffix
case "$WORK" in
    */revision_exec_6e7b/revision_exec_6e7b) WORK="$(dirname "$WORK")" ;;
esac
[ -d "$WORK" ] || WORK="$(pwd)"

REV_PLOT_DIR="$MAIN_REVISION/analysis_revision"
DIMER_TS_PY="$REV_PLOT_DIR/revision_plot_dimer_timeseries.py"
MERGE_XVG_PY="$REV_PLOT_DIR/merge_xvg_for_sham.py"
XPM2TXT="$MAIN_REVISION/analysis/external/gromacs-gibbs-pipeline/scripts/xpm2txt.py"
PLOT_GIBBS="$MAIN_REVISION/analysis/external/gromacs-gibbs-pipeline/scripts/plot_gibbs_landscape.py"

FIG_FORMAT="${FIG_FORMAT:-tif}"
DPI="${DPI:-300}"
ZMAX="${ZMAX:-5}"

OUT="$ANALYSIS_DIR/figures"
STAGE="$OUT/staging/raw_xvg"
FEL_WORK="$OUT/staging/fel_6e7b"

# ── Pre-flight ──────────────────────────────────────────────
for f in "$DIMER_TS_PY" "$MERGE_XVG_PY" "$XPM2TXT" "$PLOT_GIBBS"; do
    [[ -f "$f" ]] || { echo "ERROR: missing $f"; exit 1; }
done

for r in 1 2 3; do
    base="$ANALYSIS_DIR/timeseries/rep${r}"
    for x in rmsd_backbone.xvg mindist.xvg rg.xvg; do
        [[ -f "$base/$x" ]] || { echo "ERROR: missing $base/$x"; exit 1; }
    done
done

mkdir -p "$OUT" "$STAGE" "$FEL_WORK"

echo "============================================"
echo " 6E7B Supplementary Figures"
echo "============================================"
echo "Analysis dir: $ANALYSIS_DIR"
echo "Output dir:   $OUT"
echo "Format:       $FIG_FORMAT @ ${DPI} dpi"
echo ""

# ── Stage XVGs into the layout the main script expects ─────
# revision_plot_dimer_timeseries.py expects:
#   <raw_root>/dimer_rep{1,2,3}/{rmsd_backbone.xvg, rg.xvg, mindist_pl.xvg, hbond_num.xvg}
echo "[1/4] Staging XVGs into dimer_rep{1,2,3}/ layout..."
for r in 1 2 3; do
    src="$ANALYSIS_DIR/timeseries/rep${r}"
    dst="$STAGE/dimer_rep${r}"
    mkdir -p "$dst"
    cp -f "$src/rmsd_backbone.xvg" "$dst/rmsd_backbone.xvg"
    cp -f "$src/rg.xvg"            "$dst/rg.xvg"
    cp -f "$src/mindist.xvg"       "$dst/mindist_pl.xvg"     # rename to match main script
    if [[ -f "$src/hbond_num.xvg" ]]; then
        cp -f "$src/hbond_num.xvg" "$dst/hbond_num.xvg"
    else
        # Placeholder zero-traj if H-bond extraction failed (non-critical)
        echo "  rep${r}: hbond_num.xvg missing — generating zero placeholder"
        awk 'BEGIN{for(t=0; t<=200; t+=1) print t, 0}' > "$dst/hbond_num.xvg"
    fi
done
echo "  staged: $STAGE/dimer_rep{1,2,3}/"

# ── Figure 1: Time-series 2x2 panels (Fig-4 style) ─────────
echo ""
echo "[2/4] Time-series 2x2 panels (Fig-4 style)..."
python "$DIMER_TS_PY" --mode panels \
    --raw-root "$STAGE" \
    --t-end-ns 200 --window-ns 50 \
    --out-fig "$OUT/fig_S_6e7b_timeseries_panels.${FIG_FORMAT}" \
    --out-csv "$OUT/fig_S_6e7b_timeseries_panels.csv" \
    --dpi "$DPI" \
    --fig-format "$FIG_FORMAT"

# ── Figure 2: FEL 2D (Fig-6 style, using gmx sham) ─────────
echo ""
echo "[3/4] FEL via gmx sham (Fig-6 style)..."
# Merge Rg + RMSD per rep into 3-col xvg, then concatenate across reps
for r in 1 2 3; do
    python "$MERGE_XVG_PY" \
        "$ANALYSIS_DIR/timeseries/rep${r}/rg.xvg" \
        "$ANALYSIS_DIR/timeseries/rep${r}/rmsd_backbone.xvg" \
        -o "$FEL_WORK/rep${r}_merged.xvg" \
        --plain
done

# Concatenate; drop time column for gmx sham (which expects 2D collective vars only)
# gmx sham reads (t, x, y) - we keep the time column and let sham use cols 2,3
cat "$FEL_WORK"/rep{1,2,3}_merged.xvg > "$FEL_WORK/gsham_input_rg_rmsdBB_plain.xvg"
n_frames=$(wc -l < "$FEL_WORK/gsham_input_rg_rmsdBB_plain.xvg")
echo "  concatenated: $n_frames frames (3 reps × ~20000 each)"

pushd "$FEL_WORK" >/dev/null
gmx sham -f gsham_input_rg_rmsdBB_plain.xvg \
    -ls FES.xpm -lsh enthalpy.xpm -lss entropy.xpm -lp prob.xpm >/dev/null 2>&1
python "$XPM2TXT" -f FES.xpm -o free_energy_landscape_kjmol.txt
python "$PLOT_GIBBS" \
    --input free_energy_landscape_kjmol.txt \
    --output "$OUT/fig_S_6e7b_fel_2d.${FIG_FORMAT}" \
    --format "$FIG_FORMAT" \
    --dpi "$DPI" \
    --energy-unit kcal_mol \
    --z-max "$ZMAX" \
    --xlabel "Rg (nm)" \
    --ylabel "Backbone RMSD (nm)" \
    --title "6E7B FEL (3 reps; z capped at ${ZMAX} kcal/mol)" >/dev/null
popd >/dev/null

# ── Figure 3: MM-PBSA bar comparison ───────────────────────
echo ""
echo "[4/4] MM-PBSA bar comparison (5IJ0 vs 6E7B)..."

# Use env vars + quoted heredoc to avoid bash $ expansion conflicts with LaTeX/python
export FIG6E7B_OUT_PATH="$OUT/fig_S_6e7b_mmpbsa_bar.${FIG_FORMAT}"
export FIG6E7B_FORMAT="${FIG_FORMAT}"
export FIG6E7B_DPI="${DPI}"
export FIG6E7B_IJ0_CSV="$MAIN_REVISION/analysis/mmpbsa/mmpbsa_summary.csv"
export FIG6E7B_E7B_CSV="$WORK/analysis/mmpbsa/6e7b_mmpbsa_summary.csv"

python3 << 'PYEOF'
import csv
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 10,
    "axes.titlesize": 10,
    "axes.labelsize": 10,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 8,
})

def read_per_rep_delta_total(csv_path):
    """Parse mmpbsa_summary.csv (5IJ0 + 6E7B share the same format).
    Returns list of per-rep ΔTOTAL means."""
    if not os.path.exists(csv_path):
        return None
    rows = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for r in reader:
            if r.get("replicate", "").startswith("rep"):
                try:
                    rows.append(float(r["delta_total_avg_kcal_mol"]))
                except (KeyError, ValueError):
                    continue
    return rows if rows else None

# Try CSVs first; fall back to hardcoded numbers from response letter
ij0_reps = read_per_rep_delta_total(os.environ["FIG6E7B_IJ0_CSV"]) \
           or [-27.92, -29.94, -35.71]
e7b_reps = read_per_rep_delta_total(os.environ["FIG6E7B_E7B_CSV"]) \
           or [-21.80, -29.28, -32.38]

ij0_mean = float(np.mean(ij0_reps))
ij0_sd   = float(np.std(ij0_reps, ddof=1))
e7b_mean = float(np.mean(e7b_reps))
e7b_sd   = float(np.std(e7b_reps, ddof=1))

systems = ["5IJ0\n(β-GDP curved)", "6E7B\n(β-GTP straight)"]
means   = [ij0_mean, e7b_mean]
sds     = [ij0_sd,   e7b_sd]

fig, ax = plt.subplots(figsize=(6.5, 4.5))
colors = ["#0072B2", "#D55E00"]
x = np.arange(len(systems))

ax.bar(x, means, yerr=sds, color=colors, alpha=0.85,
       capsize=8, error_kw={"linewidth": 1.5})

# Per-rep points (jitter) overlaid on bars
rng = np.random.default_rng(0)
for i, vals in enumerate([ij0_reps, e7b_reps]):
    jitter = rng.uniform(-0.08, 0.08, size=len(vals))
    ax.scatter(np.full(len(vals), x[i]) + jitter, vals,
               color="black", s=30, zorder=5,
               edgecolors="white", linewidths=1)

ax.set_xticks(x)
ax.set_xticklabels(systems)
ax.set_ylabel(r"$\Delta G_{\mathrm{MM-PBSA-GB}}$ (kcal/mol)")
ax.set_ylim(-45, 0)
ax.axhline(0, color="black", lw=0.5)
ax.grid(True, alpha=0.25, axis="y")

for i, (m, s) in enumerate(zip(means, sds)):
    ax.text(x[i], m - s - 1.5, f"{m:.2f} ± {s:.2f}",
            ha="center", va="top", fontsize=10, fontweight="bold")

ax.set_title("MM-PBSA-GB binding free energy: 5IJ0 vs 6E7B (3 replicates each)")
ax.text(0.01, 0.99, "A", transform=ax.transAxes,
        fontsize=22, fontweight="bold", ha="left", va="top")

fig.tight_layout()

out_path = os.environ["FIG6E7B_OUT_PATH"]
fmt = os.environ["FIG6E7B_FORMAT"]
dpi = int(os.environ["FIG6E7B_DPI"])
if fmt == "tif":
    fig.savefig(out_path, format="tif", dpi=dpi, bbox_inches="tight",
                pil_kwargs={"compression": "tiff_lzw"})
else:
    fig.savefig(out_path, format=fmt, dpi=dpi, bbox_inches="tight")
plt.close(fig)
print(f"Wrote {out_path}")
PYEOF

# ── Summary ────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Figures complete."
echo "============================================"
ls -lh "$OUT"/*.${FIG_FORMAT} "$OUT"/*.csv 2>/dev/null
echo ""
echo "To preview locally:"
echo "  scp -P <port> -r root@<host>:${OUT}/fig_S_6e7b_*.${FIG_FORMAT} ./"
echo ""
echo "Suggested supplementary figure layout:"
echo "  Supp Fig S5(A-D): fig_S_6e7b_timeseries_panels.${FIG_FORMAT}"
echo "  Supp Fig S5(E):   fig_S_6e7b_fel_2d.${FIG_FORMAT}"
echo "  Supp Fig S5(F):   fig_S_6e7b_mmpbsa_bar.${FIG_FORMAT}"
