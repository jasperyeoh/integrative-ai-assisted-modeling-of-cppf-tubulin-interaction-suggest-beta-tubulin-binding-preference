#!/usr/bin/env bash
# ============================================================
# MM-PBSA-GB for 6E7B supplementary MD (rep1/rep2/rep3, last 50 ns)
# ============================================================
# Mirrors the 5IJ0 main-text protocol:
#   - gmx_MMPBSA v1.5+
#   - GB-OBC2 (igb=5), intdiel=1.0, extdiel=78.5
#   - AMBER99SB-ILDN protein + GAFF for CPPF
#   - last 50 ns of each 200 ns rep, ~50 snapshots/rep
#
# Output: per-rep FINAL_RESULTS + a 6e7b_mmpbsa_summary.csv parallel to
#         revision_exec/analysis/mmpbsa/mmpbsa_summary.csv
#
# Usage:
#   cd /root/tubulin-cppf-md/revision_exec_6e7b
#   bash analysis/mmpbsa/run_6e7b_mmpbsa.sh                  # all 3 reps
#   REP=rep1 bash analysis/mmpbsa/run_6e7b_mmpbsa.sh          # single rep
#   MMPBSA_MODE=smoke REP=rep1 bash analysis/mmpbsa/run_6e7b_mmpbsa.sh   # smoke test
#
# Notes:
# - Trajectories are the PBC-corrected ones produced by run_full_analysis.sh.
#   Falls back to the raw md_200ns.xtc if pbc-corrected version is absent.
# - Default conda env: mmpbsa_py311. Override via MMPBSA_ENV=...
# ============================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYSIS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK6E7B="$(cd "$ANALYSIS_DIR/.." && pwd)"
PREP="$WORK6E7B/prep"

MMPBSA_MODE="${MMPBSA_MODE:-full}"
MMPBSA_ENV="${MMPBSA_ENV:-mmpbsa_py311}"
REPS_ARG="${REP:-all}"
PBC_DIR="${PBC_DIR:-/root/autodl-tmp/analysis_6e7b/traj}"

# ── Locate the mmpbsa env ─────────────────────────────────
eval "$(conda shell.bash hook)"
if ! conda env list | awk '{print $1}' | grep -qx "${MMPBSA_ENV}"; then
    echo "ERROR: conda env '${MMPBSA_ENV}' not found."
    echo "Create it with:"
    echo "  CONDA_SOLVER=classic conda create -n ${MMPBSA_ENV} -c conda-forge -c bioconda \\"
    echo "    python=3.11 gmx_mmpbsa ambertools mpi4py -y"
    exit 1
fi
conda activate "${MMPBSA_ENV}"

GMX_MMPBSA="$(which gmx_MMPBSA)"
CPPTRAJ="$(which cpptraj)"
GMX="$(which gmx || which gmx_mpi || true)"

[[ -x "$GMX_MMPBSA" ]] || { echo "ERROR: gmx_MMPBSA not found in env ${MMPBSA_ENV}"; exit 1; }
[[ -x "$CPPTRAJ"    ]] || { echo "ERROR: cpptraj not found in env ${MMPBSA_ENV}"; exit 1; }

# Ensure gmx is findable (gmx_path="" in input file -> uses $PATH)
if [[ -z "$GMX" ]]; then
    # Try gmx-lite env explicitly
    GMX_BIN="/root/autodl-tmp/miniconda3/envs/gmx-lite/bin"
    if [[ -x "$GMX_BIN/gmx" ]]; then
        export PATH="$GMX_BIN:$PATH"
    elif [[ -x "$GMX_BIN/gmx_mpi" ]]; then
        export PATH="$GMX_BIN:$PATH"
        # gmx_MMPBSA expects 'gmx' name
        if [[ ! -x "$GMX_BIN/gmx" ]]; then
            ln -sf "$GMX_BIN/gmx_mpi" "$GMX_BIN/gmx" 2>/dev/null || true
        fi
    else
        echo "ERROR: gmx not findable; install in gmx-lite or set PATH"; exit 1
    fi
fi

echo "gmx_MMPBSA: $GMX_MMPBSA"
echo "cpptraj:    $CPPTRAJ"
echo "gmx:        $(which gmx 2>/dev/null || echo 'via symlink')"
echo ""

# ── Pre-flight: shared inputs ─────────────────────────────
TOP="$PREP/topol.top"
[[ -f "$TOP" ]] || { echo "ERROR: $TOP missing"; exit 1; }

# Index file with Protein + CPP groups must exist or be created
NDX="$PREP/index.ndx"
if [[ ! -f "$NDX" ]]; then
    echo "Creating index.ndx with Protein + Other(=CPP) groups..."
    cat << 'NDXEOF' | gmx make_ndx -f "$PREP/em.gro" -o "$NDX"
q
NDXEOF
fi

# Verify Protein and Other (CPP) groups present; find their indices
PROT_IDX="$(gmx make_ndx -f "$PREP/em.gro" -n "$NDX" -o /dev/null 2>&1 <<< "q" | \
            awk '/Protein +:/ {print $1; exit}')"
CPP_IDX="$(gmx make_ndx -f "$PREP/em.gro" -n "$NDX" -o /dev/null 2>&1 <<< "q" | \
           awk '/Other +:/ {print $1; exit}')"

# Sanity: GROMACS default groups put Protein=1, Other=13 for protein+ligand+solvent systems.
# Fall back to defaults if extraction failed.
PROT_IDX="${PROT_IDX:-1}"
CPP_IDX="${CPP_IDX:-13}"
echo "Group indices: Protein=${PROT_IDX}  CPP (Other)=${CPP_IDX}"

# Decide which reps to run
case "$REPS_ARG" in
    all) REPS=("rep1" "rep2" "rep3") ;;
    rep1|rep2|rep3) REPS=("$REPS_ARG") ;;
    *) echo "ERROR: REP must be rep1/rep2/rep3/all"; exit 1 ;;
esac

# ── Run per rep ───────────────────────────────────────────
for REP in "${REPS[@]}"; do
    echo ""
    echo "============================================"
    echo " MM-PBSA-GB: 6E7B ${REP}"
    echo "============================================"

    REP_DIR="$WORK6E7B/md/${REP}"
    TPR="$REP_DIR/md_200ns.tpr"
    PBC_XTC="$PBC_DIR/${REP}_pbc.xtc"
    RAW_XTC="$REP_DIR/md_200ns.xtc"

    if [[ -f "$PBC_XTC" ]]; then
        TRJ="$PBC_XTC"
        echo "Using PBC-corrected trajectory: $TRJ"
    elif [[ -f "$RAW_XTC" ]]; then
        TRJ="$RAW_XTC"
        echo "WARNING: PBC-corrected xtc missing, using raw: $TRJ"
        echo "         (gmx_MMPBSA does its own cpptraj-based pbc handling, usually OK.)"
    else
        echo "ERROR: no trajectory found at $PBC_XTC or $RAW_XTC"
        exit 1
    fi
    [[ -f "$TPR" ]] || { echo "ERROR: $TPR missing"; exit 1; }

    if [[ "$MMPBSA_MODE" == "smoke" ]]; then
        INFILE="$SCRIPT_DIR/mmpbsa_6e7b_smoke_gb.in"
        if [[ ! -f "$INFILE" ]]; then
            # Build a smoke variant on the fly: just a handful of frames
            sed 's/interval *= *100/interval = 500/' \
                "$SCRIPT_DIR/mmpbsa_6e7b_last50ns_gb.in" > "$INFILE"
        fi
        OUTTAG="${REP}_smoke_gb"
    else
        INFILE="$SCRIPT_DIR/mmpbsa_6e7b_last50ns_gb.in"
        OUTTAG="${REP}_last50ns_gb"
    fi

    WORKDIR="$SCRIPT_DIR/work_${REP}_${MMPBSA_MODE}"
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    LOG="$WORKDIR/mmpbsa_${OUTTAG}_$(date +%Y%m%d_%H%M%S).log"
    echo "WORKDIR=$WORKDIR" | tee "$LOG"
    echo "INFILE=$INFILE"   | tee -a "$LOG"
    echo "TPR=$TPR"         | tee -a "$LOG"
    echo "TRJ=$TRJ"         | tee -a "$LOG"
    echo "Groups: ${PROT_IDX} ${CPP_IDX}" | tee -a "$LOG"

    set +e
    "$GMX_MMPBSA" -O -nogui \
        -i "$INFILE" \
        -cs "$TPR" \
        -ci "$NDX" \
        -cg "${PROT_IDX}" "${CPP_IDX}" \
        -cp "$TOP" \
        -ct "$TRJ" \
        -eo "${OUTTAG}_perframe.csv" \
        -o  "${OUTTAG}_FINAL_RESULTS.dat" \
        2>&1 | tee -a "$LOG"
    rc=${PIPESTATUS[0]}
    set -e

    if [[ "$rc" -ne 0 ]]; then
        echo "ERROR: ${REP} MM-PBSA failed (exit ${rc}). See $LOG"
        exit "$rc"
    fi
    echo "${REP}: FINAL_RESULTS at $WORKDIR/${OUTTAG}_FINAL_RESULTS.dat"
done

# ── Summarize across reps ────────────────────────────────
echo ""
echo "============================================"
echo " Summarizing across replicates"
echo "============================================"

# Reuse 5IJ0 summarize script (settings identical, format identical)
SUMMARIZE_PY="$WORK6E7B/../revision_exec/analysis/mmpbsa/summarize_mmpbsa_gb_last50ns.py"
SUMMARY_CSV="$SCRIPT_DIR/6e7b_mmpbsa_summary.csv"

if [[ -f "$SUMMARIZE_PY" ]] && [[ "${MMPBSA_MODE}" == "full" ]] && [[ "${REPS_ARG}" == "all" ]]; then
    python3 "$SUMMARIZE_PY" \
        --rep1 "$SCRIPT_DIR/work_rep1_full/rep1_last50ns_gb_FINAL_RESULTS.dat" \
        --rep2 "$SCRIPT_DIR/work_rep2_full/rep2_last50ns_gb_FINAL_RESULTS.dat" \
        --rep3 "$SCRIPT_DIR/work_rep3_full/rep3_last50ns_gb_FINAL_RESULTS.dat" \
        --out-csv "$SUMMARY_CSV" \
        --n-frames 51

    echo ""
    echo "Summary CSV: $SUMMARY_CSV"
    cat "$SUMMARY_CSV"
else
    echo "(Skipping summary: not all reps were run or mode is smoke.)"
fi

echo ""
echo "============================================"
echo " 6E7B MM-PBSA done."
echo "============================================"
echo ""
echo "Compare with 5IJ0 main-text:"
echo "  5IJ0 ΔTOTAL = -31.19 ± 4.04 kcal/mol  (rep1/2/3: -27.92/-29.94/-35.71)"
echo "  6E7B ΔTOTAL = (see $SUMMARY_CSV)"
