#!/usr/bin/env bash
# Upload 6E7B supplementary MD trajectories to the existing HF dataset repo.
#
# Prereq: pip install -U "huggingface_hub[cli]"
# Auth: hf auth login  OR  export HF_TOKEN  OR  ~/.huggingface_token
# Repo: export HF_DATASET_REPO='HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers'
#
# Usage:
#   bash .../huggingface_upload_6e7b_trajectories.sh --dry-run
#   bash .../huggingface_upload_6e7b_trajectories.sh --rep 1
#   bash .../huggingface_upload_6e7b_trajectories.sh --all
#   bash .../huggingface_upload_6e7b_trajectories.sh --update-readme
#
# Trajectories may live on autodl-tmp during production; set REP*_XTC overrides if needed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HF_REPO="${HF_DATASET_REPO:-HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers}"
TOKEN_FILE="${HF_TOKEN_FILE:-$HOME/.huggingface_token}"
DRY_RUN=0
UPDATE_README=0
REPS=()

REP1_XTC="${REP1_XTC:-$ROOT/revision_exec_6e7b/md/rep1/md_200ns.xtc}"
REP2_XTC="${REP2_XTC:-/root/autodl-tmp/rep2_md/md_200ns.xtc}"
REP3_XTC="${REP3_XTC:-/root/autodl-tmp/rep3_md/md_200ns.xtc}"

run_hf() {
  if command -v hf >/dev/null 2>&1; then
    hf "$@"
  else
    huggingface-cli "$@"
  fi
}

load_hf_token() {
  if [[ -n "${HF_TOKEN:-}" ]]; then
    return 0
  fi
  if [[ -f "$TOKEN_FILE" ]]; then
    HF_TOKEN="$(head -1 "$TOKEN_FILE" | tr -d '\r\n')"
    export HF_TOKEN
  fi
}

hf_upload() {
  local local_path="$1" path_in_repo="$2" msg="$3"
  if [[ -n "${HF_TOKEN:-}" ]]; then
    run_hf upload "$HF_REPO" "$local_path" "$path_in_repo" \
      --repo-type dataset --token "$HF_TOKEN" --commit-message "$msg"
  else
    run_hf upload "$HF_REPO" "$local_path" "$path_in_repo" \
      --repo-type dataset --commit-message "$msg"
  fi
}

md_200ns_complete() {
  local prod_dir="$1"
  command -v gmx >/dev/null 2>&1 || return 1
  [[ -f "${prod_dir}/md_200ns.cpt" ]] || return 1
  gmx check -f "${prod_dir}/md_200ns.cpt" 2>&1 | grep -qE 'time 200000(\.[0-9]+)?[[:space:]]'
}

remote_name() {
  local rep="$1"
  echo "6e7b_rep${rep}_md_200ns.xtc"
}

rep_xtc() {
  case "$1" in
    1) printf '%s' "$REP1_XTC" ;;
    2) printf '%s' "$REP2_XTC" ;;
    3) printf '%s' "$REP3_XTC" ;;
    *) return 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --rep) REPS+=("$2"); shift 2 ;;
    --all) REPS=(1 2 3); shift ;;
    --update-readme) UPDATE_README=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ${#REPS[@]} -eq 0 && "$UPDATE_README" -eq 0 ]]; then
  echo "ERROR: pass --rep N, --all, and/or --update-readme" >&2
  exit 2
fi

if ! command -v hf >/dev/null 2>&1 && ! command -v huggingface-cli >/dev/null 2>&1; then
  echo "ERROR: pip install -U 'huggingface_hub[cli]'" >&2
  exit 1
fi

FILES=()
for rep in "${REPS[@]}"; do
  xtc="$(rep_xtc "$rep")"
  prod="$(dirname "$xtc")"
  if [[ ! -f "$xtc" ]]; then
    echo "NOTE: skip rep${rep} — missing $xtc" >&2
    continue
  fi
  if ! md_200ns_complete "$prod"; then
    echo "NOTE: skip rep${rep} — md_200ns.cpt not at 200 ns yet" >&2
    continue
  fi
  FILES+=("$rep:$xtc")
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "=== 6E7B HF upload dry-run (repo=$HF_REPO) ==="
  for entry in "${FILES[@]}"; do
    rep="${entry%%:*}"
    xtc="${entry#*:}"
    echo "  $(remote_name "$rep")  <=  $xtc  ($(du -h "$xtc" | cut -f1))"
  done
  [[ "$UPDATE_README" -eq 1 ]] && echo "  README.md  <=  revision_exec/HF_DATASET_CARD_README.md"
  exit 0
fi

load_hf_token

if [[ "$UPDATE_README" -eq 1 ]]; then
  echo "Uploading dataset card README ..."
  hf_upload "$ROOT/revision_exec/HF_DATASET_CARD_README.md" "README.md" \
    "Update dataset card: add 6E7B supplementary trajectories"
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "NOTE: no 6E7B trajectories ready to upload." >&2
  exit 0
fi

SUMS="$ROOT/revision_exec_6e7b/HF_UPLOAD_SHA256SUMS_6e7b.txt"
: >"$SUMS"
for entry in "${FILES[@]}"; do
  rep="${entry%%:*}"
  xtc="${entry#*:}"
  key="$(remote_name "$rep")"
  sha256sum "$xtc" | awk -v k="$key" '{print $1"  "k}' >>"$SUMS"
done

hf_upload "$SUMS" "HF_UPLOAD_SHA256SUMS_6e7b.txt" "Add 6E7B SHA256 checksums"

for entry in "${FILES[@]}"; do
  rep="${entry%%:*}"
  xtc="${entry#*:}"
  key="$(remote_name "$rep")"
  echo "=== Uploading $key ==="
  hf_upload "$xtc" "$key" "Add 6E7B lattice-state MD replicate $rep (200 ns)"
done

echo "Done. https://huggingface.co/datasets/$HF_REPO"
