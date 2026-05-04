#!/usr/bin/env bash
# Mirror-upload revision_exec/ to a Hugging Face Dataset repo, preserving relative paths:
#   local  tubulin-cppf-md/revision_exec/<anything>
#   remote <HF_REVISION_MIRROR_PREFIX>/<anything>   (default prefix: revision_exec)
#
# **Does not upload production trajectories again:** every **/prod/**/*.xtc** is excluded,
# because revision_exec/scripts/huggingface_upload_trajectories.sh already uploads those
# to the dataset (flat names at repo root). Other paths (tpr, gro, edr, logs, analysis xtc
# outside prod/, input/, prep/, etc.) are included.
#
# Size: still large (tens–100+ GiB typical); run --dry-run first. Use tmux/screen.
#
# Auth: same as huggingface_upload_trajectories.sh (hf auth login, HF_TOKEN, ~/.huggingface_token).
#
# Usage:
#   export HF_DATASET_REPO='HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers'
#   # optional: different dataset for mirror only
#   # export HF_MIRROR_REPO='HUB_NAMESPACE/...'
#   # optional: remote folder name (default revision_exec)
#   # export HF_REVISION_MIRROR_PREFIX='revision_exec'
#
#   bash revision_exec/scripts/huggingface_upload_revision_exec_mirror.sh --dry-run
#   bash revision_exec/scripts/huggingface_upload_revision_exec_mirror.sh --upload
#   bash revision_exec/scripts/huggingface_upload_revision_exec_mirror.sh --upload --only rep1
#   bash revision_exec/scripts/huggingface_upload_revision_exec_mirror.sh --upload --only analysis_revision
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/revision_exec"
TOKEN_FILE="${HF_TOKEN_FILE:-$HOME/.huggingface_token}"

PREFIX="${HF_REVISION_MIRROR_PREFIX:-revision_exec}"
REPO="${HF_MIRROR_REPO:-${HF_DATASET_REPO:-${HF_REPO:-}}}"

MODE="dry-run"
ONLY=""
# Glob excludes passed to `hf upload` (gitignore-style; see huggingface_hub docs).
EXCLUDES=(
  "**/prod/**/*.xtc"
  "**/#*#"
  "**/.#*"
  "**/__pycache__/**"
  "**/*.pyc"
  "**/.DS_Store"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --upload) MODE="upload"; shift ;;
    --only)
      ONLY="$2"
      shift 2
      ;;
    *) echo "Unknown arg: $1 (use --dry-run or --upload [--only DIR])" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: missing directory: $SRC" >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  echo "ERROR: set HF_MIRROR_REPO or HF_DATASET_REPO (or HF_REPO) to the target dataset id." >&2
  exit 1
fi

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
  return 0
}

dry_run_summary() {
  echo "=== revision_exec mirror dry-run ==="
  echo "Repo:     $REPO"
  echo "Prefix:   $PREFIX/"
  echo "Source:   $SRC"
  echo "Excludes: **/prod/**/*.xtc (already uploaded by huggingface_upload_trajectories.sh), junk globs"
  echo
  echo "Top-level disk usage (MiB):"
  du -sm "$SRC"/* 2>/dev/null | sort -n || true
  echo
  echo "File count that would be uploaded (excl. prod *.xtc + junk):"
  local total
  total="$(
    find "$SRC" -type f \
      ! -path '*/prod/*.xtc' \
      ! -name '#*#' ! -name '.#*' \
      ! -path '*/__pycache__/*' ! -name '*.pyc' ! -name '.DS_Store' \
      2>/dev/null | wc -l
  )"
  echo "  files: $total"
  du -sh "$SRC" 2>/dev/null || true
  echo
  echo "If this looks correct, run with --upload (optionally --only <subdir>)."
}

# Returns 0 => skip this top-level name (--only filter).
should_skip_name() {
  local base="$1"
  if [[ -n "$ONLY" && "$base" != "$ONLY" ]]; then
    return 0
  fi
  return 1
}

hf_upload_one() {
  local local_path="$1" remote_path="$2" msg="$3"
  local -a args=(upload "$REPO" "$local_path" "$remote_path" --repo-type dataset --commit-message "$msg")
  for g in "${EXCLUDES[@]}"; do
    args+=(--exclude "$g")
  done
  if [[ -n "${HF_TOKEN:-}" ]]; then
    args+=(--token "$HF_TOKEN")
  fi
  run_hf "${args[@]}"
}

if [[ "$MODE" == "dry-run" ]]; then
  dry_run_summary
  exit 0
fi

if ! command -v hf >/dev/null 2>&1 && ! command -v huggingface-cli >/dev/null 2>&1; then
  echo "ERROR: Install: pip install -U 'huggingface_hub[cli]'" >&2
  exit 1
fi

load_hf_token

echo "=== Uploading revision_exec mirror to $REPO (prefix=$PREFIX/) ==="

# Root-level files (mdp, pdb, checksum txt, gz, etc.)
shopt -s nullglob
for f in "$SRC"/*; do
  [[ -f "$f" ]] || continue
  bn="$(basename "$f")"
  if should_skip_name "$bn"; then
    continue
  fi
  remote="$PREFIX/$bn"
  echo ">>> file: $bn -> $remote"
  hf_upload_one "$f" "$remote" "Mirror revision_exec root file: $bn"
done

# Top-level directories
for d in "$SRC"/*; do
  [[ -d "$d" ]] || continue
  bn="$(basename "$d")"
  if should_skip_name "$bn"; then
    continue
  fi
  remote="$PREFIX/$bn"
  echo ">>> dir:  $bn/ -> $remote/"
  hf_upload_one "$d" "$remote" "Mirror revision_exec/$bn/"
done

echo "Done. Dataset: https://huggingface.co/datasets/$REPO"
echo "Production **/prod/**/*.xtc were skipped (already on Hub via huggingface_upload_trajectories.sh)."
