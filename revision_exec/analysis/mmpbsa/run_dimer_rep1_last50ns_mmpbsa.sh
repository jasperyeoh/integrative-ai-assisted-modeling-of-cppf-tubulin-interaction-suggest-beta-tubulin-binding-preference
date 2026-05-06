#!/usr/bin/env bash
# MM-PBSA (gmx_MMPBSA) for heterodimer rep1, trajectory window 350–400 ns only.
# Prerequisites: conda env `mmpbsa`, GROMACS in gmx-lite (path in mmpbsa input).
#
# Usage:
#   bash run_dimer_rep1_last50ns_mmpbsa.sh              # smoke (few frames)
#   MMPBSA_MODE=full bash run_dimer_rep1_last50ns_mmpbsa.sh   # subsampled full window
#
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REV="$(cd "$SCRIPT_DIR/../.." && pwd)"
MMPBSA_MODE="${MMPBSA_MODE:-smoke}"
MMPBSA_ENV="${MMPBSA_ENV:-mmpbsa}"
REP="${REP:-${1:-rep1}}"

MMPBSA_PREFIX="${HPC_WORKSPACE}/miniconda3/envs/${MMPBSA_ENV}"
GMX_MMPBSA="${MMPBSA_PREFIX}/bin/gmx_MMPBSA"
CPPTRAJ="${MMPBSA_PREFIX}/bin/cpptraj"

[[ -x "$GMX_MMPBSA" ]] || { echo "ERROR: missing executable $GMX_MMPBSA" >&2; exit 1; }
[[ -x "$CPPTRAJ" ]] || { echo "ERROR: missing executable $CPPTRAJ" >&2; exit 1; }

# Ensure external programs are discoverable via $PATH (gmx_MMPBSA uses $PATH
# when gmx_path="" in the input file).
export PATH="${MMPBSA_PREFIX}/bin:${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256:${PATH}"

PROD="$REV/$REP/prod"
NDX="$REV/input/index.ndx"
TPR="$PROD/md_400ns.tpr"

if [[ -f "$PROD/md_400ns.part0005.xtc" ]]; then
  TRJ="$PROD/md_400ns.part0005.xtc"
elif [[ -f "$PROD/md_400ns.part0004.xtc" ]]; then
  TRJ="$PROD/md_400ns.part0004.xtc"
else
  echo "ERROR: could not find last-segment xtc under $PROD (expected md_400ns.part0004/0005.xtc)" >&2
  exit 1
fi

# gmx_MMPBSA expects `-cp` to be a `.top`. Default to the preparation topology.
# If you want to use a different `.top`, set TOPOLOGY_FILE=/path/to/topol.top.
TOP_DEFAULT="$REV/prep/gate_topol.top"
TOP="${TOPOLOGY_FILE:-$TOP_DEFAULT}"

for f in "$NDX" "$TOP" "$TPR" "$TRJ"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
done

if [[ "$MMPBSA_MODE" == "full" ]]; then
  INFILE="$SCRIPT_DIR/mmpbsa_dimer_rep1_last50ns_gb.in"
  OUTTAG="last50ns_gb_subsample"
else
  INFILE="$SCRIPT_DIR/mmpbsa_dimer_rep1_smoke_gb.in"
  OUTTAG="smoke_gb"
fi

[[ -f "$INFILE" ]] || { echo "ERROR: missing input $INFILE" >&2; exit 1; }

WORKDIR="$SCRIPT_DIR/work_dimer_${REP}_last50ns_${MMPBSA_MODE}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

LOG="$WORKDIR/mmpbsa_${OUTTAG}_$(date +%Y%m%d_%H%M%S).log"

echo "WORKDIR=$WORKDIR" | tee "$LOG"
echo "INFILE=$INFILE" | tee -a "$LOG"
echo "TPR=$TPR" | tee -a "$LOG"
echo "TRJ=$TRJ" | tee -a "$LOG"

# Protein = index 1, CPP = 13 (0-based group order in index.ndx)
set +e
"$GMX_MMPBSA" -O -nogui \
  -i "$INFILE" \
  -cs "$TPR" \
  -ci "$NDX" \
  -cg 1 13 \
  -cp "$TOP" \
  -ct "$TRJ" \
  -eo "${OUTTAG}_perframe.csv" \
  -o "${OUTTAG}_FINAL_RESULTS.dat" \
  2>&1 | tee -a "$LOG"
rc=${PIPESTATUS[0]}
set -e
exit "$rc"
