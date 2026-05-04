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
#   HF_DATASET_REPO=... bash .../huggingface_upload_trajectories.sh --bundle monomer-incremental
#   HF_DATASET_REPO=... bash .../huggingface_upload_trajectories.sh --bundle dimer
#   HF_DATASET_REPO=... bash .../huggingface_upload_trajectories.sh --bundle dimer-extensions   # rep3 350 + 350–400 ns parts only
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

# Used to avoid uploading partially-written monomer XTC before md_200ns.cpt reaches 200 ns.
resolve_gmx() {
  if [[ -n "${GMX:-}" && -x "${GMX}" ]]; then
    printf '%s' "${GMX}"
    return 0
  fi
  if command -v gmx >/dev/null 2>&1; then
    command -v gmx
    return 0
  fi
  local c
  for c in \
    "${CONDA_PREFIX:-}/bin.AVX2_256/gmx" \
    "${CONDA_PREFIX:-}/bin/gmx" \
    "${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx"; do
    if [[ -x "${c}" ]]; then
      printf '%s' "${c}"
      return 0
    fi
  done
  return 1
}

monomer_md_200ns_complete() {
  local prod_dir="$1"
  local gmx_bin
  gmx_bin="$(resolve_gmx)" || return 1
  [[ -f "${prod_dir}/md_200ns.cpt" ]] || return 1
  "${gmx_bin}" check -f "${prod_dir}/md_200ns.cpt" 2>&1 | grep -qE 'time 200000(\.[0-9]+)?[[:space:]]'
}

MONOMER_RELS=(
  revision_exec/monomer_alpha_rep1/prod/md_200ns.xtc
  revision_exec/monomer_alpha_rep2/prod/md_200ns.xtc
  revision_exec/monomer_alpha_rep3/prod/md_200ns.xtc
  revision_exec/monomer_beta_rep1/prod/md_200ns.xtc
  revision_exec/monomer_beta_rep2/prod/md_200ns.xtc
  revision_exec/monomer_beta_rep3/prod/md_200ns.xtc
)

# Remaining new replicates (upload when each reaches 200 ns). Completed older reps stay in `monomer` / `all`.
MONOMER_INCREMENTAL_RELS=(
  revision_exec/monomer_alpha_rep3/prod/md_200ns.xtc
  revision_exec/monomer_beta_rep3/prod/md_200ns.xtc
)
# Core dimer trajectories (already deposited historically).
DIMER_RELS=(
  revision_exec/rep1/prod/md_200ns.xtc
  revision_exec/rep2/prod/md_200ns.xtc
  revision_exec/rep3/prod/md_200ns.xtc
  revision_exec/rep1/prod/md_350ns.part0004.xtc
  revision_exec/rep2/prod/md_350ns.part0003.xtc
)
# New extension segments (rep3 300–350; all reps 350–400). Use --bundle dimer-extensions to upload only these.
DIMER_EXTENSION_RELS=(
  revision_exec/rep3/prod/md_350ns.part0003.xtc
  revision_exec/rep1/prod/md_400ns.part0005.xtc
  revision_exec/rep2/prod/md_400ns.part0004.xtc
  revision_exec/rep3/prod/md_400ns.part0004.xtc
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
  all|monomer|monomer-incremental|dimer|dimer-extensions) ;;
  *) echo "ERROR: --bundle must be all, monomer, monomer-incremental, dimer, or dimer-extensions" >&2; exit 2 ;;
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
  for rel in "${MONOMER_RELS[@]}"; do
    f="$ROOT/$rel"
    if [[ ! -f "$f" ]]; then
      echo "NOTE: skip missing monomer xtc: $rel" >&2
      continue
    fi
    prod="$(dirname "$f")"
    if monomer_md_200ns_complete "$prod"; then
      FILES+=("$f")
    else
      echo "NOTE: skip monomer not completed to 200 ns yet: $rel" >&2
    fi
  done
fi
if [[ "$BUNDLE" == "monomer-incremental" ]]; then
  for rel in "${MONOMER_INCREMENTAL_RELS[@]}"; do
    f="$ROOT/$rel"
    if [[ ! -f "$f" ]]; then
      echo "NOTE: skip missing monomer xtc: $rel" >&2
      continue
    fi
    prod="$(dirname "$f")"
    if monomer_md_200ns_complete "$prod"; then
      FILES+=("$f")
    else
      echo "NOTE: skip monomer not completed to 200 ns yet: $rel" >&2
    fi
  done
fi
if [[ "$BUNDLE" == "all" || "$BUNDLE" == "dimer" ]]; then
  for rel in "${DIMER_RELS[@]}"; do FILES+=("$ROOT/$rel"); done
  for rel in "${DIMER_EXTENSION_RELS[@]}"; do FILES+=("$ROOT/$rel"); done
fi
if [[ "$BUNDLE" == "dimer-extensions" ]]; then
  for rel in "${DIMER_EXTENSION_RELS[@]}"; do FILES+=("$ROOT/$rel"); done
fi

if [[ "$DRY_RUN" -eq 1 && "$BUNDLE" == "monomer-incremental" && ${#FILES[@]} -eq 0 ]]; then
  echo "=== Hugging Face upload dry-run (bundle=$BUNDLE, repo=$HF_REPO) ==="
  echo "  (no files yet: incremental list has no 200 ns-complete trajectories)"
  exit 0
fi

if [[ "$BUNDLE" == "monomer" && ${#FILES[@]} -eq 0 ]]; then
  echo "ERROR: no completed monomer trajectories to upload (need md_200ns.cpt at 200 ns + md_200ns.xtc)" >&2
  exit 1
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

if [[ "$BUNDLE" == "monomer-incremental" && ${#FILES[@]} -eq 0 ]]; then
  echo "NOTE: monomer-incremental: nothing ready to upload yet." >&2
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

SUMS="$ROOT/revision_exec/HF_UPLOAD_SHA256SUMS_${BUNDLE//-/_}.txt"
: >"$SUMS"
for f in "${FILES[@]}"; do
  key="$(remote_name "$f")"
  echo "sha256sum $key ..."
  sha256sum "$f" | awk -v k="$key" '{print $1"  "k}' >>"$SUMS"
done

SUM_KEY="HF_UPLOAD_SHA256SUMS_${BUNDLE//-/_}.txt"
echo "Uploading $SUM_KEY ..."
hf_upload "$SUMS" "$SUM_KEY" "Add SHA256 checksums (bundle=$BUNDLE)"

for f in "${FILES[@]}"; do
  key="$(remote_name "$f")"
  echo "=== Uploading $key ($(du -h "$f" | cut -f1)) ==="
  hf_upload "$f" "$key" "Add $key"
done

echo "Done. Dataset: https://huggingface.co/datasets/$HF_REPO"
echo "Add a README on the Hub (see docs/HUGGINGFACE_DATASET.md) and cite this URL in the paper."
