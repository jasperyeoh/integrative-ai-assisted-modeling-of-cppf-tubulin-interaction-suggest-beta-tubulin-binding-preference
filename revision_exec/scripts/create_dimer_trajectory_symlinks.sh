#!/usr/bin/env bash
# Optional human-readable symlinks for dimer prod/*.xtc (canonical filenames unchanged).
# See docs/DIMER_TRAJECTORY_NAMING.md
set -euo pipefail

REV="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

link_pair() {
  local prod="$1" alias="$2" target="$3"
  (
    cd "$prod"
    if [[ ! -f "$target" ]]; then
      echo "SKIP missing $prod/$target"
      return 0
    fi
    ln -sf "$target" "$alias"
    echo "OK $prod/$alias -> $target"
  )
}

for rep in rep1 rep2 rep3; do
  prod="$REV/$rep/prod"
  [[ -d "$prod" ]] || { echo "SKIP no dir $prod"; continue; }

  link_pair "$prod" "segment_0-300ns.xtc" "md_200ns.xtc"

  case "$rep" in
    rep1)
      link_pair "$prod" "segment_300-350ns.xtc" "md_350ns.part0004.xtc"
      link_pair "$prod" "segment_350-400ns.xtc" "md_400ns.part0005.xtc"
      ;;
    rep2|rep3)
      link_pair "$prod" "segment_300-350ns.xtc" "md_350ns.part0003.xtc"
      link_pair "$prod" "segment_350-400ns.xtc" "md_400ns.part0004.xtc"
      ;;
  esac
done

echo "Done. Symlinks are extras only; workflows still use md_200ns.xtc / md_*part*.xtc."
