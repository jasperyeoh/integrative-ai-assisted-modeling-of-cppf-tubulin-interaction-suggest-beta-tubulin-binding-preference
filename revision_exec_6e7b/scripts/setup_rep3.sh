#!/usr/bin/env bash
# Prep rep3: NVT/NPT from EM (new velocities) → md_200ns.tpr on autodl-tmp.
set -eo pipefail

REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORK="${REPO}/revision_exec_6e7b"
PREP="${WORK}/prep"
REP3_MD="/root/autodl-tmp/rep3_md"
NTOMP=$(nproc)
LOG="${WORK}/logs/setup_rep3.log"

eval "$(conda shell.bash hook)"
conda activate gmx-lite
export TMPDIR=/root/autodl-tmp/tmp
mkdir -p "${WORK}/md/rep3" "${REP3_MD}" "${WORK}/logs" "${TMPDIR}"

log() { echo "[$(date '+%F %T')] $*" | tee -a "${LOG}"; }

log "=== rep3 prep: NVT/NPT from EM (new velocities) ==="
cd "${PREP}"
cp -f em.gro em_for_rep3.gro

gmx grompp -f mdp/nvt.mdp -c em_for_rep3.gro -r em_for_rep3.gro \
  -p topol.top -n index.ndx -o nvt_rep3.tpr -maxwarn 2
gmx mdrun -v -deffnm nvt_rep3 -ntomp "${NTOMP}"

gmx grompp -f mdp/npt.mdp -c nvt_rep3.gro -r nvt_rep3.gro -t nvt_rep3.cpt \
  -p topol.top -n index.ndx -o npt_rep3.tpr -maxwarn 2
gmx mdrun -v -deffnm npt_rep3 -ntomp "${NTOMP}"

gmx grompp -f mdp/md_prod_200ns.mdp -c npt_rep3.gro -t npt_rep3.cpt \
  -p topol.top -n index.ndx -o "${WORK}/md/rep3/md_200ns.tpr" -maxwarn 2

cp -f "${WORK}/md/rep3/md_200ns.tpr" "${REP3_MD}/md_200ns.tpr"
log "rep3 TPR ready: ${REP3_MD}/md_200ns.tpr"
