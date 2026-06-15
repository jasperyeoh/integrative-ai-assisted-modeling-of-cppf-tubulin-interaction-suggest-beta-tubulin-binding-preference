#!/bin/bash
# ============================================================
# Launch 6E7B Production MD (200 ns)
# Usage:
#   bash scripts/run_production.sh rep1   # starts rep1
#   bash scripts/run_production.sh rep2   # starts rep2
# ============================================================
set -euo pipefail

REP="${1:-rep1}"
REPO="/root/autodl-tmp/tubulin-cppf-md"
WORK="${REPO}/revision_exec_6e7b"
RUNDIR="${WORK}/md/${REP}"

eval "$(conda shell.bash hook)"
conda activate gmx-lite

if [ ! -f "${RUNDIR}/md_200ns.tpr" ]; then
    echo "ERROR: ${RUNDIR}/md_200ns.tpr not found."
    echo "Run the pipeline first: bash scripts/run_6e7b_md_pipeline.sh"
    exit 1
fi

cd "${RUNDIR}"

echo "============================================"
echo " Starting 6E7B Production MD — ${REP}"
echo " $(date)"
echo "============================================"

# Full GPU offload: NB + PME + bonded + update all on GPU
# RTX 4090: expect ~50-55 ns/day for tubulin dimer
gmx mdrun \
    -v \
    -deffnm md_200ns \
    -ntmpi 1 \
    -ntomp $(nproc) \
    -nb gpu \
    -pme gpu \
    -bonded gpu \
    -gpu_id 0 \
    -update gpu \
    -cpi md_200ns.cpt \
    -maxh 168

echo ""
echo "Production MD ${REP} finished at $(date)"
echo "Trajectory: ${RUNDIR}/md_200ns.xtc"
echo "============================================"
