#!/usr/bin/env bash
# Serial queue: rep1 → rep2 prep → rep2 → rep3 prep → rep3 (outputs on autodl-tmp)
set -eo pipefail

REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORK="${REPO}/revision_exec_6e7b"
PREP="${WORK}/prep"
REP2_MD="/root/autodl-tmp/rep2_md"
REP3_MD="/root/autodl-tmp/rep3_md"
NTOMP=$(nproc)
GMX_PROD="-nb gpu -pme gpu -bonded gpu -gpu_id 0"
LOG="${WORK}/logs/md_queue.log"
export TMPDIR=/root/autodl-tmp/tmp

eval "$(conda shell.bash hook)"
conda activate gmx-lite
mkdir -p "${WORK}/md/rep2" "${WORK}/md/rep3" "${WORK}/logs" "${REP2_MD}" "${REP3_MD}" "${TMPDIR}"
cd "${WORK}"

log() { echo "[$(date '+%F %T')] $*" | tee -a "${LOG}"; }

run_rep1() {
  log "=== rep1 production (200 ns) ==="
  cd "${WORK}/md/rep1"
  local cmd=(gmx mdrun -v -deffnm md_200ns -ntomp "${NTOMP}" ${GMX_PROD})
  if [[ -f md_200ns.cpt ]]; then
    log "Resuming rep1 from md_200ns.cpt"
    cmd+=(-cpi md_200ns.cpt -append)
  else
    log "Starting rep1 fresh"
  fi
  "${cmd[@]}" 2>&1 | tee -a md_rep1.log
  log "rep1 finished"
}

run_rep2_prep() {
  log "=== rep2 prep: NVT/NPT from EM (new velocities) ==="
  cd "${PREP}"
  cp -f em.gro em_for_rep2.gro

  gmx grompp -f mdp/nvt.mdp -c em_for_rep2.gro -r em_for_rep2.gro \
    -p topol.top -n index.ndx -o nvt_rep2.tpr -maxwarn 2
  gmx mdrun -v -deffnm nvt_rep2 -ntomp "${NTOMP}"

  gmx grompp -f mdp/npt.mdp -c nvt_rep2.gro -r nvt_rep2.gro -t nvt_rep2.cpt \
    -p topol.top -n index.ndx -o npt_rep2.tpr -maxwarn 2
  gmx mdrun -v -deffnm npt_rep2 -ntomp "${NTOMP}"

  gmx grompp -f mdp/md_prod_200ns.mdp -c npt_rep2.gro -t npt_rep2.cpt \
    -p topol.top -n index.ndx -o "${WORK}/md/rep2/md_200ns.tpr" -maxwarn 2
  log "rep2 TPR ready: md/rep2/md_200ns.tpr"
}

run_rep2() {
  log "=== rep2 production (200 ns) on autodl-tmp ==="
  cp -f "${WORK}/md/rep2/md_200ns.tpr" "${REP2_MD}/"
  cd "${REP2_MD}"
  gmx mdrun -v -deffnm md_200ns -ntomp "${NTOMP}" ${GMX_PROD} \
    2>&1 | tee md_rep2.log
  log "rep2 finished"
}

run_rep3_prep() {
  log "=== rep3 prep ==="
  bash "${WORK}/scripts/setup_rep3.sh"
}

run_rep3() {
  log "=== rep3 production (200 ns) on autodl-tmp ==="
  cd "${REP3_MD}"
  gmx mdrun -v -deffnm md_200ns -ntomp "${NTOMP}" ${GMX_PROD} \
    2>&1 | tee md_rep3.log
  log "rep3 finished"
}

log "MD queue started (rep1 → rep2 prep → rep2 → rep3 prep → rep3)"
run_rep1
run_rep2_prep
run_rep2
run_rep3_prep
run_rep3
log "MD queue complete (3 × 200 ns)"
