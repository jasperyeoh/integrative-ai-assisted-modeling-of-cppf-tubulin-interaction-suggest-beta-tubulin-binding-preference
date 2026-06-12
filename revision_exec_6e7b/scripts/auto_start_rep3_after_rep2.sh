#!/usr/bin/env bash
# Wait for rep2 to finish, prep rep3, then launch 200 ns production on autodl-tmp.
set -eo pipefail

REPO="/root/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference"
WORK="${REPO}/revision_exec_6e7b"
SCRIPT_DIR="${WORK}/scripts"
REP2_MD="/root/autodl-tmp/rep2_md"
REP3_MD="/root/autodl-tmp/rep3_md"
LOG="${WORK}/logs/auto_start_rep3.log"
NTOMP=$(nproc)
GMX_PROD="-nb gpu -pme gpu -bonded gpu -gpu_id 0"

mkdir -p "${REP3_MD}" /root/autodl-tmp/tmp "${WORK}/logs"

log() { echo "[$(date '+%F %T')] $*" | tee -a "${LOG}"; }

rep2_finished() {
  for f in "${REP2_MD}/md_rep2_resume.log" "${REP2_MD}/md_200ns.log" "${REP2_MD}/md_rep2.log"; do
    if [[ -f "${f}" ]] && grep -q "Finished mdrun" "${f}"; then
      return 0
    fi
  done
  if ! pgrep -f "${REP2_MD}.*mdrun" >/dev/null 2>&1 && \
     ! pgrep -f "cd ${REP2_MD}.*mdrun" >/dev/null 2>&1 && \
     [[ -f "${REP2_MD}/md_200ns.cpt" ]]; then
    local last_step
    last_step=$(grep -oE 'step [0-9]+' "${REP2_MD}/md_200ns.log" 2>/dev/null | tail -1 | awk '{print $2}')
    if [[ -n "${last_step}" && "${last_step}" -ge 99000000 ]]; then
      return 0
    fi
  fi
  return 1
}

log "Watcher started — waiting for rep2 to finish"
while ! rep2_finished; do
  sleep 300
done
log "rep2 complete — starting rep3 prep"

bash "${SCRIPT_DIR}/setup_rep3.sh"

if screen -ls | grep -q '\.md_rep3'; then
  log "screen md_rep3 already exists — skip launch"
  exit 0
fi

screen -dmS md_rep3 bash -lc "
  set -eo pipefail
  export TMPDIR=/root/autodl-tmp/tmp
  source /root/miniconda3/etc/profile.d/conda.sh
  conda activate gmx-lite
  cd ${REP3_MD}
  gmx mdrun -v -deffnm md_200ns -ntomp ${NTOMP} ${GMX_PROD} \
    2>&1 | tee md_rep3.log
  echo EXIT:\$? >> md_rep3.log
"
log "rep3 production launched in screen md_rep3 (${REP3_MD})"
