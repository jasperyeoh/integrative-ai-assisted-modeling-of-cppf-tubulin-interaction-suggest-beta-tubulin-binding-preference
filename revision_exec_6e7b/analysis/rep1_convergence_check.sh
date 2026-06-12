#!/bin/bash
# ============================================================
# rep1 Convergence Health Check
# ============================================================
# Purpose: Determine if rep1 (200 ns) has reached a stable plateau
#          in backbone RMSD and CPPF binding contact. Output:
#          - Time-series XVG files for inspection
#          - A printed VERDICT block with quantitative criteria
#
# Safe to run while rep2 is still running on the GPU
# (this only uses CPU + reads existing rep1 files).
#
# Usage:
#   cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b
#   bash analysis/rep1_convergence_check.sh
# ============================================================
set -e

eval "$(conda shell.bash hook)"
conda activate gmx-lite

REP1="md/rep1"
OUT="analysis/rep1_health"
mkdir -p "${OUT}"

cd "${REP1}"
TRJ="md_200ns.xtc"
TPR="md_200ns.tpr"

if [ ! -f "${TRJ}" ] || [ ! -f "${TPR}" ]; then
    echo "ERROR: missing ${TRJ} or ${TPR} in $(pwd)"
    exit 1
fi

OUT_ABS="$(cd ../../${OUT} && pwd)"
echo "============================================"
echo " rep1 Convergence Check"
echo "============================================"
echo "Trajectory: $(pwd)/${TRJ}"
echo "Output:     ${OUT_ABS}/"
echo ""

# ------ 1. PBC correction (whole + center + cluster) ------
echo "[1/6] PBC correction (nojump → cluster -center)..."
echo -e "Protein\nSystem" | gmx trjconv \
    -s "${TPR}" -f "${TRJ}" \
    -o "${OUT_ABS}/rep1_nojump.xtc" \
    -pbc nojump -center 2>&1 | tail -3

echo -e "Protein\nSystem" | gmx trjconv \
    -s "${TPR}" -f "${OUT_ABS}/rep1_nojump.xtc" \
    -o "${OUT_ABS}/rep1_pbc.xtc" \
    -pbc cluster -center 2>&1 | tail -3

CLEAN_TRJ="${OUT_ABS}/rep1_pbc.xtc"

# ------ 2. Backbone RMSD ------
echo ""
echo "[2/6] Backbone RMSD..."
echo -e "Backbone\nBackbone" | gmx rms \
    -s "${TPR}" -f "${CLEAN_TRJ}" \
    -o "${OUT_ABS}/rep1_rmsd_backbone.xvg" \
    -tu ns 2>&1 | tail -3

# ------ 3. Ligand (CPPF) RMSD after backbone fit ------
echo ""
echo "[3/6] CPPF ligand RMSD (least-squares fit on backbone)..."
echo -e "Backbone\nOther" | gmx rms \
    -s "${TPR}" -f "${CLEAN_TRJ}" \
    -o "${OUT_ABS}/rep1_rmsd_ligand.xvg" \
    -tu ns 2>&1 | tail -3

# ------ 4. Min protein–CPPF distance ------
echo ""
echo "[4/6] Minimum protein–CPPF distance..."
echo -e "Protein\nOther" | gmx mindist \
    -s "${TPR}" -f "${CLEAN_TRJ}" \
    -od "${OUT_ABS}/rep1_mindist.xvg" \
    -tu ns 2>&1 | tail -3

# ------ 5. Radius of gyration ------
echo ""
echo "[5/6] Radius of gyration (Rg)..."
echo "Backbone" | gmx gyrate \
    -s "${TPR}" -f "${CLEAN_TRJ}" \
    -o "${OUT_ABS}/rep1_rg.xvg" \
    -tu ns 2>&1 | tail -3

# ------ 6. H-bond count (CPPF–protein) ------
echo ""
echo "[6/6] CPPF–protein H-bonds..."
echo -e "Other\nProtein" | gmx hbond-legacy \
    -s "${TPR}" -f "${CLEAN_TRJ}" \
    -num "${OUT_ABS}/rep1_hbond_num.xvg" \
    -tu ns 2>&1 | tail -3 || \
echo -e "Other\nProtein" | gmx hbond \
    -s "${TPR}" -f "${CLEAN_TRJ}" \
    -num "${OUT_ABS}/rep1_hbond_num.xvg" \
    -tu ns 2>&1 | tail -3

# ============================================================
# VERDICT — Python summary
# ============================================================
echo ""
echo "============================================"
echo " CONVERGENCE VERDICT"
echo "============================================"

python3 << PYEOF
import numpy as np
import os

OUT = "${OUT_ABS}"

def read_xvg(path):
    """Read xvg, returning (time_ns, value) arrays."""
    if not os.path.exists(path):
        return None, None
    data = []
    with open(path) as f:
        for line in f:
            if line.startswith(('#', '@', '&')):
                continue
            parts = line.split()
            if len(parts) >= 2:
                try:
                    data.append((float(parts[0]), float(parts[1])))
                except ValueError:
                    continue
    if not data:
        return None, None
    arr = np.array(data)
    return arr[:, 0], arr[:, 1]

def block_stats(t, y, blocks=10):
    """Split into N equal blocks; return mean of each block."""
    n = len(t)
    if n < blocks * 5:
        return None
    block_size = n // blocks
    means = []
    for i in range(blocks):
        s, e = i * block_size, (i + 1) * block_size
        means.append((t[s], t[e-1], np.mean(y[s:e]), np.std(y[s:e])))
    return means

def converged(block_means, threshold_frac=0.15):
    """
    Heuristic: take last 5 blocks (last 100 ns of a 200 ns run).
    If the spread (max-min of block means) < threshold * overall mean → converged.
    """
    if block_means is None or len(block_means) < 6:
        return None, None, None
    last5 = [m[2] for m in block_means[-5:]]
    overall_mean = np.mean(last5)
    spread = max(last5) - min(last5)
    rel_spread = spread / abs(overall_mean) if overall_mean != 0 else float('inf')
    return rel_spread < threshold_frac, rel_spread, overall_mean

def trend_slope(t, y, last_frac=0.5):
    """Linear slope over the last fraction of the trajectory."""
    n = len(t)
    s = int(n * (1 - last_frac))
    slope, intercept = np.polyfit(t[s:], y[s:], 1)
    return slope  # units per ns

print()
print("Metric          | Last-100ns mean | Block spread | Slope(last 100ns) | Verdict")
print("-" * 88)

metrics = [
    ("Backbone RMSD",  "rep1_rmsd_backbone.xvg", "nm",  0.15),
    ("Ligand RMSD",    "rep1_rmsd_ligand.xvg",   "nm",  0.20),
    ("min(CPPF-prot)", "rep1_mindist.xvg",       "nm",  0.20),
    ("Rg",             "rep1_rg.xvg",            "nm",  0.05),
    ("H-bond count",   "rep1_hbond_num.xvg",     "",    0.50),
]

verdicts = {}
for label, fname, unit, thresh in metrics:
    path = os.path.join(OUT, fname)
    t, y = read_xvg(path)
    if t is None:
        print(f"{label:15s} | (missing file)")
        continue
    blocks = block_stats(t, y, blocks=10)
    conv, rel_spread, mean = converged(blocks, threshold_frac=thresh)
    slope = trend_slope(t, y, last_frac=0.5)
    slope_per_100ns = slope * 100
    verdict = "CONVERGED" if conv else ("UNCERTAIN" if rel_spread < thresh*1.5 else "DRIFTING")
    verdicts[label] = (conv, mean, rel_spread, slope_per_100ns)
    print(f"{label:15s} | {mean:>7.3f} {unit:3s}    | {rel_spread*100:>5.1f}% rel  | {slope_per_100ns:+.3f} /100ns | {verdict}")

print()
print("=" * 88)
# Overall verdict
critical = ["Backbone RMSD", "min(CPPF-prot)"]
crit_conv = [verdicts[k][0] for k in critical if k in verdicts]

if all(crit_conv):
    print(">>> OVERALL: rep1 has CONVERGED on the binding-relevant metrics.")
    print(">>> RECOMMENDATION: 200 ns is sufficient. No extension needed.")
    print(">>>                 Wait for rep2 to finish, then run full analysis.")
elif any(crit_conv):
    print(">>> OVERALL: rep1 PARTIALLY converged.")
    print(">>> RECOMMENDATION: Acceptable. Wait for rep2. If rep2 shows similar")
    print(">>>                 partial convergence, results are still defensible.")
else:
    print(">>> OVERALL: rep1 has NOT converged on binding-relevant metrics.")
    print(">>> RECOMMENDATION: Consider extending rep1 to 400 ns AFTER rep2 finishes.")
    print(">>>                 Command:")
    print(">>>   gmx convert-tpr -s md/rep1/md_200ns.tpr -extend 200000 -o md/rep1/md_400ns.tpr")
    print(">>>   gmx mdrun -v -deffnm md_400ns -cpi md/rep1/md_200ns.cpt -noappend ...")

print()
print("Files generated in ${OUT_ABS}/:")
for f in os.listdir(OUT):
    if f.endswith(('.xvg', '.xtc')):
        size = os.path.getsize(os.path.join(OUT, f)) / 1e6
        print(f"  {f:35s} {size:>6.1f} MB")
PYEOF

echo ""
echo "============================================"
echo " Quick visual: gnuplot ASCII RMSD"
echo "============================================"
if command -v gnuplot &> /dev/null; then
    gnuplot << GPLEOF 2>/dev/null
set terminal dumb 100 24
set title "rep1 Backbone RMSD (nm) vs time (ns)"
set xlabel "time (ns)"
set ylabel "RMSD (nm)"
plot "${OUT_ABS}/rep1_rmsd_backbone.xvg" using 1:2 with lines notitle
GPLEOF
else
    echo "(gnuplot not installed — view XVG files locally or install with: apt-get install gnuplot-nox)"
fi

echo ""
echo "Done. To copy files locally for plotting:"
echo "  scp -P 36037 -r root@connect.nmb1.seetacloud.com:/root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/analysis/rep1_health ."
