#!/bin/bash
# ============================================================
# 6E7B Full Analysis Pipeline — 3 replicates + comparison plots
# ============================================================
# Purpose: After all 3 reps finish, generate the full analysis:
#   - PBC-corrected trajectories
#   - Time series: backbone RMSD, ligand RMSD, min(CPPF-protein), Rg, H-bond
#   - Final-50ns pocket residue distances (VAL236, LEU253, ALA314)
#   - Concatenated FEL (RMSD, Rg) via Boltzmann inversion
#   - Plots (PNG): per-rep panels + summary comparison
#   - summary.md with numbers ready to paste into Response Letter [TBD]
#
# Disk-safe: all outputs default to /root/autodl-tmp/analysis_6e7b/
# Idempotent: skips per-rep steps already done (checks for output files).
#
# Usage (after migration + rep3 complete):
#   cd /root/tubulin-cppf-md/revision_exec_6e7b
#   bash analysis/run_full_analysis.sh
#
# Optional environment overrides:
#   OUT=/path/to/custom/output       # default /root/autodl-tmp/analysis_6e7b
#   IJ0_DIR=/path/to/5ij0_xtc/       # if 5IJ0 trajectories are local
# ============================================================
set -euo pipefail

eval "$(conda shell.bash hook)"
set +u
conda activate gmx-lite
set -u

# ── Config ──────────────────────────────────────────────────
OUT="${OUT:-/root/autodl-tmp/analysis_6e7b}"
REPO="$(pwd)"
REP_DIRS_DEFAULT=("md/rep1" "md/rep2" "md/rep3")
NUM_REPS=3

# Fallback trajectory locations (pre-migration paths from rep2/rep3 incident)
declare -A FALLBACK_REP
FALLBACK_REP[rep1]="md/rep1"
FALLBACK_REP[rep2]="/root/autodl-tmp/rep2_md"
FALLBACK_REP[rep3]="/root/autodl-tmp/rep3_md"

# ── Pre-flight ──────────────────────────────────────────────
echo "============================================"
echo " 6E7B Full Analysis Pipeline"
echo "============================================"
echo "Working dir: ${REPO}"
echo "Output dir:  ${OUT}"
echo ""

mkdir -p "${OUT}"/{traj,timeseries,fel,pocket,plots,logs}
REAL_OUT="$(readlink -f "${OUT}")"
AVAIL_GB="$(df -BG "${REAL_OUT}" | tail -1 | awk '{print $4}' | tr -d 'G')"
echo "Output real path: ${REAL_OUT}"
echo "Available disk:   ${AVAIL_GB}G"

if [[ "${REAL_OUT}" != /root/autodl-tmp/* ]]; then
    echo "ERROR: Output path is not on /root/autodl-tmp/ (the data disk)."
    echo "       Each PBC-corrected xtc is ~12G; 3 reps × 2 intermediates = ~72G needed."
    exit 1
fi
if [ "${AVAIL_GB}" -lt 80 ]; then
    echo "ERROR: Only ${AVAIL_GB}G free. Need ~80G headroom for 3-rep PBC + FEL."
    exit 1
fi
echo "Disk check: OK."
echo ""

# ── Locate each rep ─────────────────────────────────────────
declare -A REP_PATH
for i in 1 2 3; do
    rep="rep${i}"
    std="${REPO}/md/${rep}"
    fb="${FALLBACK_REP[$rep]}"
    if [ -f "${std}/md_200ns.xtc" ] && [ -f "${std}/md_200ns.tpr" ]; then
        REP_PATH[$rep]="${std}"
    elif [ -f "${fb}/md_200ns.xtc" ] && [ -f "${fb}/md_200ns.tpr" ]; then
        REP_PATH[$rep]="${fb}"
        echo "NOTE: ${rep} found at fallback path ${fb} (pre-migration). Migration recommended."
    else
        echo "ERROR: ${rep} trajectory not found. Looked in:"
        echo "  ${std}/md_200ns.xtc"
        echo "  ${fb}/md_200ns.xtc"
        exit 1
    fi
done
echo "Trajectory locations:"
for i in 1 2 3; do
    echo "  rep${i}: ${REP_PATH[rep${i}]}"
done
echo ""

# ── Per-rep PBC + time series ───────────────────────────────
for i in 1 2 3; do
    rep="rep${i}"
    src="${REP_PATH[$rep]}"
    out="${OUT}/timeseries/${rep}"
    mkdir -p "${out}"

    TPR="${src}/md_200ns.tpr"
    XTC="${src}/md_200ns.xtc"
    PBC_XTC="${OUT}/traj/${rep}_pbc.xtc"

    echo "===== ${rep} ====="

    # PBC: nojump → cluster -center (dimer convention)
    if [ ! -f "${PBC_XTC}" ]; then
        echo "[${rep} 1/6] PBC correction (nojump → cluster -center)..."
        TMP_NOJUMP="${OUT}/traj/${rep}_nojump.xtc"
        echo -e "Protein\nSystem" | gmx trjconv \
            -s "${TPR}" -f "${XTC}" -o "${TMP_NOJUMP}" \
            -pbc nojump -center 2>"${OUT}/logs/${rep}_pbc1.log"
        echo -e "Protein\nProtein\nSystem" | gmx trjconv \
            -s "${TPR}" -f "${TMP_NOJUMP}" -o "${PBC_XTC}" \
            -pbc cluster -center 2>"${OUT}/logs/${rep}_pbc2.log"
        rm -f "${TMP_NOJUMP}"
    else
        echo "[${rep} 1/6] PBC already done: ${PBC_XTC}"
    fi

    # Backbone RMSD
    if [ ! -f "${out}/rmsd_backbone.xvg" ]; then
        echo "[${rep} 2/6] Backbone RMSD..."
        echo -e "Backbone\nBackbone" | gmx rms \
            -s "${TPR}" -f "${PBC_XTC}" \
            -o "${out}/rmsd_backbone.xvg" -tu ns \
            2>"${out}/.rmsd_bb.log"
    fi

    # Ligand RMSD (fit on backbone, RMSD of "Other")
    if [ ! -f "${out}/rmsd_ligand.xvg" ]; then
        echo "[${rep} 3/6] Ligand RMSD..."
        echo -e "Backbone\nOther" | gmx rms \
            -s "${TPR}" -f "${PBC_XTC}" \
            -o "${out}/rmsd_ligand.xvg" -tu ns \
            2>"${out}/.rmsd_lig.log"
    fi

    # min(CPPF–protein)
    if [ ! -f "${out}/mindist.xvg" ]; then
        echo "[${rep} 4/6] min(CPPF–protein)..."
        echo -e "Protein\nOther" | gmx mindist \
            -s "${TPR}" -f "${PBC_XTC}" \
            -od "${out}/mindist.xvg" -tu ns \
            2>"${out}/.mindist.log"
    fi

    # Rg
    if [ ! -f "${out}/rg.xvg" ]; then
        echo "[${rep} 5/6] Rg..."
        echo "Backbone" | gmx gyrate \
            -s "${TPR}" -f "${PBC_XTC}" \
            -o "${out}/rg.xvg" -tu ns \
            2>"${out}/.rg.log"
    fi

    # H-bond (legacy first, new API fallback, non-fatal)
    if [ ! -f "${out}/hbond_num.xvg" ]; then
        echo "[${rep} 6/6] H-bonds..."
        if echo -e "Protein\nOther" | gmx hbond-legacy \
            -s "${TPR}" -f "${PBC_XTC}" \
            -num "${out}/hbond_num.xvg" -tu ns 2>"${out}/.hbond.log"; then
            echo "  legacy OK"
        elif echo -e "Protein\nOther" | gmx hbond \
            -s "${TPR}" -f "${PBC_XTC}" \
            -num "${out}/hbond_num.xvg" -tu ns 2>>"${out}/.hbond.log"; then
            echo "  new API OK"
        else
            echo "  H-bond failed (non-critical)"
        fi
    fi
    echo ""
done

# ── Pocket residue distances (final 50 ns) ──────────────────
echo "===== Pocket residue distances (150-200 ns) ====="
POCKET_OUT="${OUT}/pocket"
for i in 1 2 3; do
    rep="rep${i}"
    src="${REP_PATH[$rep]}"
    TPR="${src}/md_200ns.tpr"
    PBC_XTC="${OUT}/traj/${rep}_pbc.xtc"

    # Make a per-rep index with residue selections
    NDX="${POCKET_OUT}/${rep}_pocket.ndx"
    if [ ! -f "${NDX}" ]; then
        cat << EOF | gmx make_ndx -f "${TPR}" -o "${NDX}" 2>/dev/null
r 236 & ! a H*
name 19 VAL236_heavy
r 253 & ! a H*
name 20 LEU253_heavy
r 314 & ! a H*
name 21 ALA314_heavy
q
EOF
    fi

    for res in VAL236 LEU253 ALA314; do
        out_file="${POCKET_OUT}/${rep}_${res}_mindist.xvg"
        if [ ! -f "${out_file}" ]; then
            echo "[${rep}] ${res} min distance..."
            echo -e "${res}_heavy\nOther" | gmx mindist \
                -s "${TPR}" -f "${PBC_XTC}" \
                -n "${NDX}" -b 150000 -e 200000 \
                -od "${out_file}" -tu ns 2>/dev/null || true
        fi
    done
done

# ── Concatenate for FEL ─────────────────────────────────────
echo ""
echo "===== Concatenated trajectory for FEL ====="
CONCAT_RMSD="${OUT}/fel/concat_rmsd.xvg"
CONCAT_RG="${OUT}/fel/concat_rg.xvg"
if [ ! -f "${CONCAT_RMSD}" ]; then
    # Use awk to concatenate xvg files with time offset
    python3 << 'PYEOF'
import os
OUT = os.environ.get("OUT", "/root/autodl-tmp/analysis_6e7b")
for metric in ["rmsd_backbone", "rg"]:
    suffix = "rmsd" if metric == "rmsd_backbone" else "rg"
    out_concat = f"{OUT}/fel/concat_{suffix}.xvg"
    rows = []
    offset = 0.0
    for i in range(1, 4):
        path = f"{OUT}/timeseries/rep{i}/{metric}.xvg"
        if not os.path.exists(path):
            continue
        with open(path) as f:
            last_t = 0.0
            for line in f:
                if line.startswith(("#", "@", "&")):
                    continue
                parts = line.split()
                if len(parts) < 2:
                    continue
                try:
                    t = float(parts[0])
                    v = float(parts[1])
                except ValueError:
                    continue
                rows.append((offset + t, v))
                last_t = t
            offset += last_t
    with open(out_concat, "w") as f:
        for t, v in rows:
            f.write(f"{t:.4f}  {v:.6f}\n")
    print(f"  {out_concat}: {len(rows)} frames")
PYEOF
fi

# ── Plotting + summary ─────────────────────────────────────
echo ""
echo "===== Generating plots + summary.md ====="
python3 "${REPO}/analysis/make_plots.py" \
    --out "${OUT}" \
    --reps "${NUM_REPS}" \
    2>&1 | tee "${OUT}/logs/plots.log"

# ── Done ────────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Analysis complete."
echo "============================================"
echo ""
echo "Outputs in ${OUT}/:"
echo "  traj/        PBC-corrected trajectories (~36 GB)"
echo "  timeseries/  Per-rep XVG files (RMSD, mindist, Rg, hbond)"
echo "  pocket/      Final-50ns pocket-residue distances"
echo "  fel/         Concatenated RMSD/Rg + FEL"
echo "  plots/       PNG figures"
echo "  summary.md   Numbers ready for Response Letter [TBD]"
echo ""
echo "To preview locally:"
echo "  scp -P <port> -r root@<host>:${REAL_OUT}/plots ./"
echo "  scp -P <port>    root@<host>:${REAL_OUT}/summary.md ./"
