#!/usr/bin/env bash
# Upload 6E7B reproducibility bundle to Hugging Face (beyond production .xtc).
#
# Uploads:
#   - 6e7b_rep{N}_md_200ns.tpr          (pair with .xtc for re-analysis)
#   - 6e7b_rep{N}_md_200ns_last50ns_sub.xtc  (MM-PBSA / lightweight re-analysis)
#   - analysis_6e7b/                    (plots, timeseries XVG, FEL — from repo or autodl-tmp)
#   - analysis_6e7b/traj/               (PBC-corrected trajectories, ~14 GB each)
#   - revision_exec_6e7b/               (scripts, prep, analysis; excludes md/*.xtc)
#
# Prereq: hf CLI + ~/.huggingface_token (or HF_TOKEN)
# Usage:
#   bash .../huggingface_upload_6e7b_reproducibility.sh --dry-run
#   bash .../huggingface_upload_6e7b_reproducibility.sh --pbc
#   bash .../huggingface_upload_6e7b_reproducibility.sh --tpr --analysis
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HF_REPO="${HF_DATASET_REPO:-HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers}"
TOKEN_FILE="${HF_TOKEN_FILE:-$HOME/.huggingface_token}"
ANALYSIS_SRC="${ANALYSIS_6E7B_SRC:-$ROOT/revision_exec_6e7b/analysis}"
TRAJ_SRC="${ANALYSIS_6E7B_TRAJ:-/root/autodl-tmp/analysis_6e7b/traj}"
# Fallback to autodl-tmp if repo copy missing plots
[[ -d "$ANALYSIS_SRC/plots" ]] || ANALYSIS_SRC="/root/autodl-tmp/analysis_6e7b"

DRY_RUN=0
DO_TPR=0
DO_LAST50=0
DO_ANALYSIS=0
DO_PBC=0
DO_MIRROR=0

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --tpr) DO_TPR=1; shift ;;
    --last50ns) DO_LAST50=1; shift ;;
    --analysis) DO_ANALYSIS=1; shift ;;
    --pbc) DO_PBC=1; shift ;;
    --mirror) DO_MIRROR=1; shift ;;
    --all) DO_TPR=1; DO_LAST50=1; DO_ANALYSIS=1; DO_PBC=1; DO_MIRROR=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ "$DO_TPR" -eq 0 && "$DO_LAST50" -eq 0 && "$DO_ANALYSIS" -eq 0 && "$DO_PBC" -eq 0 && "$DO_MIRROR" -eq 0 ]]; then
  echo "ERROR: pass --tpr, --last50ns, --analysis, --pbc, --mirror, or --all" >&2
  exit 2
fi

if ! command -v hf >/dev/null 2>&1 && ! command -v huggingface-cli >/dev/null 2>&1; then
  echo "ERROR: pip install -U huggingface_hub" >&2
  exit 1
fi

echo "=== 6E7B reproducibility upload (repo=$HF_REPO) ==="
echo "Analysis source: $ANALYSIS_SRC"

if [[ "$DRY_RUN" -eq 1 ]]; then
  [[ "$DO_TPR" -eq 1 ]] && for r in 1 2 3; do
    f="$ROOT/revision_exec_6e7b/md/rep${r}/md_200ns.tpr"
    [[ -f "$f" ]] && echo "  6e7b_rep${r}_md_200ns.tpr <= $f ($(du -h "$f" | cut -f1))"
  done
  [[ "$DO_LAST50" -eq 1 ]] && for r in 1 2 3; do
    f="$ROOT/revision_exec_6e7b/md/rep${r}/md_200ns_last50ns_sub.xtc"
    [[ -f "$f" ]] && echo "  6e7b_rep${r}_md_200ns_last50ns_sub.xtc <= $f ($(du -h "$f" | cut -f1))"
  done
  [[ "$DO_ANALYSIS" -eq 1 && -d "$ANALYSIS_SRC" ]] && \
    echo "  analysis_6e7b/ <= $ANALYSIS_SRC ($(du -sh "$ANALYSIS_SRC" | cut -f1), no traj/)"
  [[ "$DO_PBC" -eq 1 ]] && for r in 1 2 3; do
    f="$TRAJ_SRC/rep${r}_pbc.xtc"
    [[ -f "$f" ]] && echo "  analysis_6e7b/traj/6e7b_rep${r}_pbc.xtc <= $f ($(du -h "$f" | cut -f1))"
  done
  [[ "$DO_MIRROR" -eq 1 ]] && \
    echo "  revision_exec_6e7b/ <= $ROOT/revision_exec_6e7b (exclude md/*.xtc)"
  exit 0
fi

load_hf_token

SUMS="$ROOT/revision_exec_6e7b/HF_UPLOAD_SHA256SUMS_6e7b.txt"
touch "$SUMS"

append_sha() {
  local f="$1" key="$2"
  sha256sum "$f" | awk -v k="$key" '{print $1"  "k}' >>"$SUMS"
}

if [[ "$DO_TPR" -eq 1 ]]; then
  for r in 1 2 3; do
    f="$ROOT/revision_exec_6e7b/md/rep${r}/md_200ns.tpr"
    key="6e7b_rep${r}_md_200ns.tpr"
    [[ -f "$f" ]] || { echo "NOTE: skip $key — missing $f" >&2; continue; }
    echo "=== Uploading $key ==="
    hf_upload "$f" "$key" "Add 6E7B rep${r} production TPR (200 ns run input)"
    grep -q "$key" "$SUMS" 2>/dev/null || append_sha "$f" "$key"
  done
fi

if [[ "$DO_LAST50" -eq 1 ]]; then
  for r in 1 2 3; do
    f="$ROOT/revision_exec_6e7b/md/rep${r}/md_200ns_last50ns_sub.xtc"
    key="6e7b_rep${r}_md_200ns_last50ns_sub.xtc"
    [[ -f "$f" ]] || { echo "NOTE: skip $key — missing $f" >&2; continue; }
    echo "=== Uploading $key ==="
    hf_upload "$f" "$key" "Add 6E7B rep${r} last-50ns subsampled XTC (MM-PBSA input)"
    grep -q "$key" "$SUMS" 2>/dev/null || append_sha "$f" "$key"
  done
fi

if [[ "$DO_ANALYSIS" -eq 1 ]]; then
  if [[ ! -d "$ANALYSIS_SRC" ]]; then
    echo "ERROR: analysis source missing: $ANALYSIS_SRC" >&2
    exit 1
  fi
  # Upload plots, timeseries, fel, summary — skip traj/ (regenerate from raw xtc)
  for sub in plots timeseries fel; do
    if [[ -d "$ANALYSIS_SRC/$sub" ]]; then
      echo "=== Uploading analysis_6e7b/$sub ==="
      if [[ -n "${HF_TOKEN:-}" ]]; then
        run_hf upload "$HF_REPO" "$ANALYSIS_SRC/$sub" "analysis_6e7b/$sub" \
          --repo-type dataset --token "$HF_TOKEN" \
          --commit-message "Add 6E7B analysis $sub"
      else
        run_hf upload "$HF_REPO" "$ANALYSIS_SRC/$sub" "analysis_6e7b/$sub" \
          --repo-type dataset --commit-message "Add 6E7B analysis $sub"
      fi
    fi
  done
  for f in summary.md; do
    [[ -f "$ANALYSIS_SRC/$f" ]] || [[ -f "$ROOT/revision_exec_6e7b/analysis/summary.md" ]] || continue
    src="${ANALYSIS_SRC}/$f"
    [[ -f "$src" ]] || src="$ROOT/revision_exec_6e7b/analysis/summary.md"
    hf_upload "$src" "analysis_6e7b/$f" "Add 6E7B analysis summary"
  done
fi

if [[ "$DO_PBC" -eq 1 ]]; then
  for r in 1 2 3; do
    f="$TRAJ_SRC/rep${r}_pbc.xtc"
    key="analysis_6e7b/traj/6e7b_rep${r}_pbc.xtc"
    [[ -f "$f" ]] || { echo "NOTE: skip $key — missing $f" >&2; continue; }
    echo "=== Uploading $key ($(du -h "$f" | cut -f1)) ==="
    hf_upload "$f" "$key" "Add 6E7B rep${r} PBC-corrected trajectory (~14 GB)"
    grep -q "6e7b_rep${r}_pbc.xtc" "$SUMS" 2>/dev/null || append_sha "$f" "analysis_6e7b/traj/6e7b_rep${r}_pbc.xtc"
  done
fi

if [[ "$DO_MIRROR" -eq 1 ]]; then
  echo "=== Uploading revision_exec_6e7b/ mirror (no md/*.xtc) ==="
  EX=(--exclude "**/md/**/*.xtc" --exclude "**/logs/**" --exclude "**/work_*/*"
      --exclude "**/prep/*.trr" --exclude "**/prep/*.gro" --exclude "**/prep/*.edr"
      --exclude "**/prep/*.cpt" --exclude "**/prep/*.tpr" --exclude "**/prep/*.log"
      --exclude "**/full_analysis.log" --exclude "step*.pdb" --exclude "**/.git/**")
  if [[ -n "${HF_TOKEN:-}" ]]; then
    run_hf upload "$HF_REPO" "$ROOT/revision_exec_6e7b" "revision_exec_6e7b" \
      --repo-type dataset --token "$HF_TOKEN" \
      "${EX[@]}" \
      --commit-message "Mirror revision_exec_6e7b scripts/prep/analysis (no production xtc)"
  else
    run_hf upload "$HF_REPO" "$ROOT/revision_exec_6e7b" "revision_exec_6e7b" \
      --repo-type dataset "${EX[@]}" \
      --commit-message "Mirror revision_exec_6e7b scripts/prep/analysis (no production xtc)"
  fi
fi

# Refresh checksum sidecar (keep existing xtc lines)
if [[ -f "$SUMS" ]]; then
  hf_upload "$SUMS" "HF_UPLOAD_SHA256SUMS_6e7b.txt" "Update 6E7B SHA256 checksums (tpr/last50ns)"
fi

echo "Done. https://huggingface.co/datasets/$HF_REPO"
