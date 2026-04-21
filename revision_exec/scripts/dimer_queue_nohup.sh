#!/usr/bin/env bash
set -euo pipefail

# Run selected replicas in order (each blocks until mdrun finishes).
#   Default: rep1 rep2 rep3
#   Examples:
#     bash dimer_queue_nohup.sh rep1                    # stop after rep1 for analysis, then run rep2/rep3 later
#     DIMER_QUEUE_REPS="rep2 rep3" bash dimer_queue_nohup.sh
# Note: a nohup/bash process already running will NOT re-read this file; change PIDs or start a new invocation.

ROOT="/hpc2hdd/home/jyang577/jasperyeoh/TUB-CPPF/tubulin-cppf-md/revision_exec"
cd "$ROOT"

if [[ $# -gt 0 ]]; then
  REPS=( "$@" )
elif [[ -n "${DIMER_QUEUE_REPS:-}" ]]; then
  read -r -a REPS <<< "${DIMER_QUEUE_REPS}"
else
  REPS=( rep1 rep2 rep3 )
fi

echo "[$(date '+%F %T')] Starting dimer production queue: ${REPS[*]}"

run_rep() {
  local rep="$1"
  local deffnm="${rep}/prod/md_200ns"
  local cmd=(conda run -n gmx-lite gmx mdrun -deffnm "$deffnm" -v -nb gpu -pme gpu -bonded gpu)

  if [[ -f "${deffnm}.cpt" ]]; then
    echo "[$(date '+%F %T')] Resuming ${rep} from checkpoint"
    cmd+=( -cpi "${deffnm}.cpt" )
  else
    echo "[$(date '+%F %T')] Starting fresh ${rep}"
  fi

  "${cmd[@]}"
  echo "[$(date '+%F %T')] Finished ${rep}"
}

for rep in "${REPS[@]}"; do
  run_rep "$rep"
done

echo "[$(date '+%F %T')] Dimer queue completed (${REPS[*]})"
