#!/usr/bin/env bash
# FEL upstream: inner-join rg.xvg + rmsd_backbone.xvg → gsham_input_rg_rmsdBB_plain.xvg
# (three numeric columns, no #/@ — suitable for `gmx sham -f`).
#
# Usage:
#   bash prepare_fel_gsham_input.sh dimer_rep1
#   bash prepare_fel_gsham_input.sh /abs/path/to/raw_xvg/dimer_rep1
#
# Requires: merge_xvg_for_sham.py alongside this script; Python 3 + NumPy.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGE="$SCRIPT_DIR/merge_xvg_for_sham.py"

arg="${1:?usage: $0 <system_id | raw_xvg_dir>}"
if [[ -d "$arg" ]]; then
  DIR="$(cd "$arg" && pwd)"
else
  DIR="$SCRIPT_DIR/raw_xvg/$arg"
fi
[[ -d "$DIR" ]] || { echo "ERROR: not a directory: $DIR" >&2; exit 1; }
RG="$DIR/rg.xvg"
BB="$DIR/rmsd_backbone.xvg"
OUT="$DIR/gsham_input_rg_rmsdBB_plain.xvg"
[[ -f "$RG" && -f "$BB" ]] || { echo "ERROR: need $RG and $BB" >&2; exit 1; }

python3 "$MERGE" "$RG" "$BB" -o "$OUT" --plain
echo "OK: $OUT"
