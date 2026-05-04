#!/usr/bin/env bash
# Poll monomer_alpha_rep3 / monomer_beta_rep3; when md_200ns reaches 200 ns, upload XTC once to HF.
# Uses flag files so we never re-upload the same replicate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HF_REPO="${HF_DATASET_REPO:-HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers}"
export HF_DATASET_REPO="$HF_REPO"

TOKEN_FILE="${HF_TOKEN_FILE:-$HOME/.huggingface_token}"
if [[ -z "${HF_TOKEN:-}" && -f "$TOKEN_FILE" ]]; then
  HF_TOKEN="$(head -1 "$TOKEN_FILE" | tr -d '\r\n')"
  export HF_TOKEN
fi

resolve_gmx() {
  if [[ -n "${GMX:-}" && -x "${GMX}" ]]; then printf '%s' "${GMX}"; return 0; fi
  if command -v gmx >/dev/null 2>&1; then command -v gmx; return 0; fi
  local c
  for c in \
    "${CONDA_PREFIX:-}/bin.AVX2_256/gmx" \
    "${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx"; do
    [[ -x "$c" ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

GMX_BIN="$(resolve_gmx)" || { echo "ERROR: gmx not found; set GMX=..." >&2; exit 1; }

FLAGDIR="$ROOT/revision_exec/logs/hf_upload_done_flags"
mkdir -p "$FLAGDIR"

run_hf() {
  if command -v hf >/dev/null 2>&1; then hf "$@"; else huggingface-cli "$@"; fi
}

is_200ns_done() {
  local prod="$1"
  [[ -f "$prod/md_200ns.cpt" ]] || return 1
  "${GMX_BIN}" check -f "$prod/md_200ns.cpt" 2>&1 | grep -q 'time 200000'
}

upload_rep() {
  local rep="$1"
  local prod="$ROOT/revision_exec/$rep/prod"
  local xtc="$prod/md_200ns.xtc"
  local flag="$FLAGDIR/${rep}.uploaded"
  local key="${rep}_md_200ns.xtc"
  [[ -f "$flag" ]] && return 0
  if ! is_200ns_done "$prod"; then
    return 0
  fi
  [[ -f "$xtc" ]] || { echo "WARN: $rep done but missing $xtc" >&2; return 0; }
  echo "[$(date -Is)] uploading $key ..."
  if [[ -n "${HF_TOKEN:-}" ]]; then
    run_hf upload "$HF_REPO" "$xtc" "$key" --repo-type dataset --token "$HF_TOKEN" \
      --commit-message "Add ${key} (200 ns production)"
  else
    run_hf upload "$HF_REPO" "$xtc" "$key" --repo-type dataset \
      --commit-message "Add ${key} (200 ns production)"
  fi
  : >"$flag"
  echo "[$(date -Is)] done $key"
}

echo "HF poll uploader: repo=$HF_REPO (Ctrl+C to stop)"
while true; do
  upload_rep monomer_alpha_rep3 || true
  upload_rep monomer_beta_rep3 || true
  if [[ -f "$FLAGDIR/monomer_alpha_rep3.uploaded" && -f "$FLAGDIR/monomer_beta_rep3.uploaded" ]]; then
    echo "[$(date -Is)] all incremental monomers uploaded; exiting."
    exit 0
  fi
  sleep 600
done
