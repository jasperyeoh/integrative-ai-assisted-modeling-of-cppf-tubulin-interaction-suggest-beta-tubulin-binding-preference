#!/usr/bin/env bash
#
# Compute contact-defined pocket residues for monomer systems (last 50 ns)
# and per-residue RMSF for that pocket only.
#
# Pocket definition (per system):
#   Protein atoms within 0.45 nm of ligand CPP at any time in [150,200] ns.
#
# Outputs (per system under raw_xvg/<sid>/):
#   - contact_pocket_residues_last50ns.txt  (n_residues + residue_ids list)
#   - rmsf_contact_pocket_last50ns.xvg      (gmx rmsf -res for the pocket group)
#
# Logs (per system under work/<sid>/):
#   - gmx_select_contact_pocket.log
#   - rmsf_contact_pocket_last50ns.log
#
# Usage:
#   cd revision_exec/analysis_revision
#   bash make_contact_pocket_rmsf_monomers.sh
#   ONLY_SYSTEM=monomer_alpha_rep1 bash make_contact_pocket_rmsf_monomers.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REV="$(cd "$SCRIPT_DIR/.." && pwd)"
GMX="${GMX:-${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx}"

RAW_ROOT="$SCRIPT_DIR/raw_xvg"
WORK_ROOT="$SCRIPT_DIR/work"

SYSTEMS=(
  monomer_alpha_rep1
  monomer_alpha_rep2
  monomer_alpha_rep3
  monomer_beta_rep1
  monomer_beta_rep2
  monomer_beta_rep3
)

for sid in "${SYSTEMS[@]}"; do
  if [[ -n "${ONLY_SYSTEM:-}" && "${ONLY_SYSTEM}" != "$sid" ]]; then
    continue
  fi

  out="$RAW_ROOT/$sid"
  work="$WORK_ROOT/$sid"
  xtc="$WORK_ROOT/$sid/clean_pbc.xtc"
  tpr="$REV/$sid/prod/md_200ns.tpr"
  ndx="$REV/$sid/prep/index.ndx"

  [[ -d "$out" ]] || { echo "ERROR: missing $out" >&2; exit 1; }
  [[ -f "$xtc" ]] || { echo "ERROR: missing $xtc (run run_export_all.sh first)" >&2; exit 1; }
  [[ -f "$tpr" ]] || { echo "ERROR: missing $tpr" >&2; exit 1; }
  [[ -f "$ndx" ]] || { echo "ERROR: missing $ndx" >&2; exit 1; }

  mkdir -p "$work"
  echo "=== [$sid] contact-defined pocket (0.45 nm, 150–200 ns) ==="

  pushd "$out" >/dev/null

  # gmx select: write a dynamic index for atoms satisfying the selection per frame.
  # -oi writes the selection index per frame (dat). -on writes an index file for the selection.
  "$GMX" select -s "$tpr" -f "$xtc" -n "$ndx" \
    -b 150000 -e 200000 \
    -select 'group "Protein" and within 0.45 of group "CPP"' \
    -oi contact_pocket_oi.dat \
    -on contact_pocket.ndx \
    &>"$work/gmx_select_contact_pocket.log"

  # RMSF for the selected pocket group only (index 0 in the generated ndx).
  printf '0\n' | "$GMX" rmsf -f "$xtc" -s "$tpr" -n contact_pocket.ndx \
    -o rmsf_contact_pocket_last50ns.xvg -res -b 150000 -e 200000 \
    &>"$work/rmsf_contact_pocket_last50ns.log"

  python3 - <<'PY'
from pathlib import Path

xvg = Path("rmsf_contact_pocket_last50ns.xvg")
out = Path("contact_pocket_residues_last50ns.txt")

res: list[int] = []
for line in xvg.read_text(errors="replace").splitlines():
    s = line.strip()
    if not s or s[0] in "#@&":
        continue
    parts = s.split()
    if len(parts) < 2:
        continue
    try:
        res.append(int(float(parts[0])))
    except ValueError:
        continue

res_u = sorted(set(res))
out.write_text(
    "\n".join(
        [
            f"n_residues={len(res_u)}",
            "residue_ids=" + ",".join(map(str, res_u)),
            "",
        ]
    )
)
print(f"Wrote {out} (n_residues={len(res_u)})")
PY

  popd >/dev/null
done

echo "DONE"

