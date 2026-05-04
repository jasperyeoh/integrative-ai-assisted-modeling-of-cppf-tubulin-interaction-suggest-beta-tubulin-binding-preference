#!/usr/bin/env bash
# Step 2: Export full-length xvg for all 9 MD systems → raw_xvg/<system_id>/
# Prerequisites: GROMACS (gmx), revision_exec trajectories and md_400ns.tpr / md_200ns.tpr.
#
# Usage:
#   bash run_export_all.sh              # all 9 systems
#   ONLY_SYSTEM=dimer_rep1 bash run_export_all.sh   # single system (debug)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REV="$(cd "$SCRIPT_DIR/.." && pwd)"
NDX="$REV/input/index.ndx"
GMX="${GMX:-${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx}"
OUT_ROOT="$SCRIPT_DIR/raw_xvg"
WORK_ROOT="$SCRIPT_DIR/work"
MERGE_PY="$SCRIPT_DIR/merge_xvg_for_sham.py"

# Index groups (see `printf q | gmx make_ndx -f *.tpr -n index.ndx`): 4=Backbone, 13=CPP, 1=Protein
# trjconv center: 21=Protein_CPP, output 0=System

SYSTEMS=(
  dimer_rep1
  dimer_rep2
  dimer_rep3
  monomer_alpha_rep1
  monomer_alpha_rep2
  monomer_alpha_rep3
  monomer_beta_rep1
  monomer_beta_rep2
  monomer_beta_rep3
)

prod_for_id() {
  case "$1" in
    dimer_rep1) echo "$REV/rep1/prod" ;;
    dimer_rep2) echo "$REV/rep2/prod" ;;
    dimer_rep3) echo "$REV/rep3/prod" ;;
    monomer_alpha_rep1) echo "$REV/monomer_alpha_rep1/prod" ;;
    monomer_alpha_rep2) echo "$REV/monomer_alpha_rep2/prod" ;;
    monomer_alpha_rep3) echo "$REV/monomer_alpha_rep3/prod" ;;
    monomer_beta_rep1) echo "$REV/monomer_beta_rep1/prod" ;;
    monomer_beta_rep2) echo "$REV/monomer_beta_rep2/prod" ;;
    monomer_beta_rep3) echo "$REV/monomer_beta_rep3/prod" ;;
    *) echo ""; return 1 ;;
  esac
}

is_dimer() { [[ "$1" == dimer_rep* ]]; }

merge_dimer_xtc() {
  local sid="$1" prod="$2" work="$3"
  local out="$work/merged_cat.xtc"
  case "$sid" in
    dimer_rep1)
      # stdout must stay clean — prep_trajectory captures this function's stdout as the xtc path
      "$GMX" trjcat -f "$prod/md_200ns.xtc" "$prod/md_350ns.part0004.xtc" "$prod/md_400ns.part0005.xtc" -o "$out" -cat &>/dev/null
      ;;
    dimer_rep2|dimer_rep3)
      "$GMX" trjcat -f "$prod/md_200ns.xtc" "$prod/md_350ns.part0003.xtc" "$prod/md_400ns.part0004.xtc" -o "$out" -cat &>/dev/null
      ;;
    *)
      echo "ERROR: unknown dimer system $sid" >&2
      return 1
      ;;
  esac
  echo "$out"
}

prep_trajectory() {
  local sid="$1" prod="$2" work="$3"
  mkdir -p "$work"
  local raw merged cleaned tpr

  cleaned="$work/clean_pbc.xtc"
  if [[ -f "$cleaned" && "${FORCE_TRJCONV:-0}" != "1" ]]; then
    if is_dimer "$sid"; then
      tpr="$prod/md_400ns.tpr"
    else
      tpr="$prod/md_200ns.tpr"
    fi
    echo "NOTE: reusing existing clean trajectory $cleaned (FORCE_TRJCONV=1 to rerun trjcat/trjconv)" >&2
  else
    if is_dimer "$sid"; then
      merged=$(merge_dimer_xtc "$sid" "$prod" "$work")
      tpr="$prod/md_400ns.tpr"
      raw="$merged"
    else
      raw="$prod/md_200ns.xtc"
      tpr="$prod/md_200ns.tpr"
    fi
    # trjconv prompts must not enter $(prep_trajectory) capture
    printf '21\n0\n' | "$GMX" trjconv -s "$tpr" -f "$raw" -n "$NDX" -pbc mol -center -o "$cleaned" &>"$work/trjconv.log"
  fi
  echo "$cleaned|$tpr"
}

run_one() {
  local sid="$1"
  local prod tpr xtc outdir work info

  prod="$(prod_for_id "$sid")" || return 1
  outdir="$OUT_ROOT/$sid"
  work="$WORK_ROOT/$sid"
  mkdir -p "$outdir" "$work"

  echo "=== [$sid] ==="
  info="$(prep_trajectory "$sid" "$prod" "$work")"
  xtc="${info%%|*}"
  tpr="${info##*|}"

  cd "$outdir"

  # 1) RMSD backbone (ref=4, sel=4)
  printf '4\n4\n' | "$GMX" rms -s "$tpr" -f "$xtc" -n "$NDX" -o rmsd_backbone.xvg -tu ns

  # 2) RMSD ligand: fit backbone, RMSD CPP
  printf '4\n13\n' | "$GMX" rms -s "$tpr" -f "$xtc" -n "$NDX" -o rmsd_ligand.xvg -tu ns

  # 3) Minimum distance Protein–CPP
  printf '1\n13\n' | "$GMX" mindist -s "$tpr" -f "$xtc" -n "$NDX" -od mindist_pl.xvg -tu ns

  # 4) H-bonds (Protein vs CPP). Use hbond-legacy: new gmx hbond (2024+) rejects donor/acceptor
  # typing for many CGenFF ligands ("CPP has no acceptors"); legacy uses geometric OH/NH–O/N rules.
  printf '1\n13\n' | "$GMX" hbond-legacy -f "$xtc" -s "$tpr" -n "$NDX" -num hbond_num.xvg -tu ns

  # 5) Rg (Protein)
  printf '1\n' | "$GMX" gyrate -f "$xtc" -s "$tpr" -n "$NDX" -o rg.xvg -tu ns

  # 6) SASA + volume
  printf '1\n' | "$GMX" sasa -s "$tpr" -f "$xtc" -n "$NDX" -o sasa.xvg -tv sasa_volume.xvg -tu ns

  # 7) RMSF per residue (x-axis is residue index, not time — no -tu)
  printf '1\n' | "$GMX" rmsf -f "$xtc" -s "$tpr" -n "$NDX" -o rmsf_residue.xvg -res

  # rg + backbone RMSD for later gmx sham (inner join if lengths/times differ)
  python3 "$MERGE_PY" "$outdir/rg.xvg" "$outdir/rmsd_backbone.xvg" \
    -o "$outdir/gsham_input_rg_rmsdBB_plain.xvg" --plain

  echo "OK $sid → $outdir"
}

main() {
  [[ -x "$GMX" ]] || { echo "ERROR: GMX not executable: $GMX"; exit 1; }
  [[ -f "$NDX" ]] || { echo "ERROR: missing $NDX"; exit 1; }

  local s
  for s in "${SYSTEMS[@]}"; do
    if [[ -n "${ONLY_SYSTEM:-}" && "$ONLY_SYSTEM" != "$s" ]]; then
      continue
    fi
    run_one "$s"
  done
}

main "$@"
