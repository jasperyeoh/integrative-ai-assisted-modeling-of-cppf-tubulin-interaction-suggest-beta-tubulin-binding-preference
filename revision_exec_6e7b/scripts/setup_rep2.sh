#!/bin/bash
# ============================================================
# 6E7B Rep2 Setup — same system, different velocity seed
# ============================================================
set -euo pipefail

REPO="/root/autodl-tmp/tubulin-cppf-md"
WORK="${REPO}/revision_exec_6e7b"
PREP="${WORK}/prep"
REP2="${WORK}/md/rep2"

eval "$(conda shell.bash hook)"
conda activate gmx-lite

mkdir -p "${REP2}"

# Create modified NVT MDP with different seed for rep2
sed 's/gen_seed.*=.*-1/gen_seed    = 42/' "${PREP}/nvt.mdp" > "${PREP}/nvt_rep2.mdp"

echo "===== Rep2: NVT with seed=42 ====="
cd "${PREP}"

gmx grompp \
    -f nvt_rep2.mdp \
    -c em.gro \
    -r em.gro \
    -p topol.top \
    -n index.ndx \
    -o nvt_rep2.tpr \
    -maxwarn 2

gmx mdrun -v -deffnm nvt_rep2 -ntmpi 1 -ntomp $(nproc) -nb gpu -gpu_id 0

echo "===== Rep2: NPT ====="
gmx grompp \
    -f npt.mdp \
    -c nvt_rep2.gro \
    -r nvt_rep2.gro \
    -t nvt_rep2.cpt \
    -p topol.top \
    -n index.ndx \
    -o npt_rep2.tpr \
    -maxwarn 2

gmx mdrun -v -deffnm npt_rep2 -ntmpi 1 -ntomp $(nproc) -nb gpu -gpu_id 0

echo "===== Rep2: Production TPR ====="
gmx grompp \
    -f md_prod_200ns.mdp \
    -c npt_rep2.gro \
    -t npt_rep2.cpt \
    -p topol.top \
    -n index.ndx \
    -o "${REP2}/md_200ns.tpr" \
    -maxwarn 2

echo ""
echo "Rep2 ready!"
echo "  cd ${REP2}"
echo "  gmx mdrun -v -deffnm md_200ns -ntmpi 1 -ntomp \$(nproc) -nb gpu -pme gpu -bonded gpu -gpu_id 0 -update gpu"
