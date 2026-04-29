#!/usr/bin/env bash
# Upload MD trajectories to Hugging Face Hub (Dataset repo, large files via Hub LFS).
#
# Prereq: pip install -U "huggingface_hub[cli]"  (provides both `hf` and `huggingface-cli`)
#
# Auth (pick one) — do NOT paste tokens into chat; run on the server only:
#   hf auth login
#   or: huggingface-cli login
#   or: export HF_TOKEN='hf_...'
#   or: ~/.huggingface_token (chmod 600)
#
# Repo: export HF_DATASET_REPO='HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers'
#
# Usage:
#   HF_DATASET_REPO=YourUser/cppf-tubulin-md bash .../huggingface_upload_trajectories.sh --dry-run
#   HF_DATASET_REPO=... bash .../huggingface_upload_trajectories.sh --bundle monomer
#   HF_DATASET_REPO=... bash .../huggingface_upload_trajectories.sh --bundle dimer
#   HF_DATASET_REPO=... bash .../huggingface_upload_trajectories.sh --bundle all
#   HF_DATASET_REPO=... bash .../huggingface_upload_trajectories.sh --create-repo   # create empty dataset repo first
#
# Use tmux/screen; multi-GiB uploads take a long time.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOKEN_FILE="${HF_TOKEN_FILE:-$HOME/.huggingface_token}"
DRY_RUN=0
BUNDLE="all"
CREATE_REPO=0

HF_REPO="${HF_DATASET_REPO:-${HF_REPO:-}}"

run_hf() {
  if command -v hf >/dev/null 2>&1; then
    hf "$@"
  else
    huggingface-cli "$@"
  fi
}

hf_upload() {
  local local_path="$1" path_in_repo="$2" msg="$3"
  if [[ -n "${HF_TOKEN:-}" ]]; then
    run_hf upload "$HF_REPO" "$local_path" "$path_in_repo" \
      --repo-type dataset \
      --token "$HF_TOKEN" \
      --commit-message "$msg"
  else
    run_hf upload "$HF_REPO" "$local_path" "$path_in_repo" \
      --repo-type dataset \
      --commit-message "$msg"
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
  return 0
}

# Same keys as Zenodo script (unique per replicate).
remote_name() {
  local f="$1"
  if [[ "$f" =~ /(monomer_[^/]+)/prod/([^/]+)$ ]]; then
    echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
    return
  fi
  if [[ "$f" =~ /rep([0-9]+)/prod/([^/]+)$ ]]; then
    echo "dimer_rep${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
    return
  fi
  basename "$f"
}

MONOMER_RELS=(
  revision_exec/monomer_alpha_rep1/prod/md_200ns.xtc
  revision_exec/monomer_alpha_rep2/prod/md_200ns.xtc
  revision_exec/monomer_beta_rep1/prod/md_200ns.xtc
)
DIMER_RELS=(
  revision_exec/rep1/prod/md_200ns.xtc
  revision_exec/rep2/prod/md_200ns.xtc
  revision_exec/rep3/prod/md_200ns.xtc
  revision_exec/rep1/prod/md_350ns.part0004.xtc
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --bundle)
      BUNDLE="$2"
      shift 2
      ;;
    --create-repo) CREATE_REPO=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$BUNDLE" in
  all|monomer|dimer) ;;
  *) echo "ERROR: --bundle must be all, monomer, or dimer" >&2; exit 2 ;;
esac

if ! command -v hf >/dev/null 2>&1 && ! command -v huggingface-cli >/dev/null 2>&1; then
  echo "ERROR: Install: pip install -U 'huggingface_hub[cli]'" >&2
  exit 1
fi

if [[ -z "$HF_REPO" ]]; then
  echo "ERROR: Set HF_DATASET_REPO (or HF_REPO) to e.g. YourHFUser/cppf-tubulin-md-trajectories" >&2
  exit 1
fi

FILES=()
if [[ "$BUNDLE" == "all" || "$BUNDLE" == "monomer" ]]; then
  for rel in "${MONOMER_RELS[@]}"; do FILES+=("$ROOT/$rel"); done
fi
if [[ "$BUNDLE" == "all" || "$BUNDLE" == "dimer" ]]; then
  for rel in "${DIMER_RELS[@]}"; do FILES+=("$ROOT/$rel"); done
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "=== Hugging Face upload dry-run (bundle=$BUNDLE, repo=$HF_REPO) ==="
  total=0
  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || { echo "MISSING: $f" >&2; exit 1; }
    sz=$(stat -c%s "$f")
    total=$((total + sz))
    echo "  $(remote_name "$f")  <=  $f  ($sz bytes)"
  done
  echo "Total ~ $(( total / 1024 / 1024 / 1024 )) GiB (approx)"
  exit 0
fi

load_hf_token

if [[ "$CREATE_REPO" -eq 1 ]]; then
  echo "Creating dataset repo $HF_REPO (if missing)..."
  if [[ -n "${HF_TOKEN:-}" ]]; then
    run_hf repo create "$HF_REPO" --repo-type dataset --exist-ok --token "$HF_TOKEN"
  else
    run_hf repo create "$HF_REPO" --repo-type dataset --exist-ok
  fi
fi

SUMS="$ROOT/revision_exec/HF_UPLOAD_SHA256SUMS_${BUNDLE}.txt"
: >"$SUMS"
for f in "${FILES[@]}"; do
  key="$(remote_name "$f")"
  echo "sha256sum $key ..."
  sha256sum "$f" | awk -v k="$key" '{print $1"  "k}' >>"$SUMS"
done

SUM_KEY="HF_UPLOAD_SHA256SUMS_${BUNDLE}.txt"
echo "Uploading $SUM_KEY ..."
hf_upload "$SUMS" "$SUM_KEY" "Add SHA256 checksums (bundle=$BUNDLE)"

for f in "${FILES[@]}"; do
  key="$(remote_name "$f")"
  echo "=== Uploading $key ($(du -h "$f" | cut -f1)) ==="
  hf_upload "$f" "$key" "Add $key"
done

echo "Done. Dataset: https://huggingface.co/datasets/$HF_REPO"
echo "Add a README on the Hub (see docs/HUGGINGFACE_DATASET.md) and cite this URL in the paper."
