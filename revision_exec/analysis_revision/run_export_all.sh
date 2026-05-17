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

ndx_for_id() {
  local sid="$1"
  if is_dimer "$sid"; then
    # Dimer analyses use the shared index prepared under revision_exec/input.
    echo "$NDX"
  else
    # Monomer systems need their own atom-number-consistent index.
    echo "$REV/$sid/prep/index.ndx"
  fi
}

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
  local sid="$1" prod="$2" work="$3" ndx="$4"
  mkdir -p "$work"
  local raw merged cleaned tpr
  local tmp_nojump

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

    # IMPORTANT: two-step PBC cleaning to avoid RMSD/Rg jump artefacts:
    #  1) -pbc nojump (remove frame-to-frame discontinuities)
    #  2) -pbc mol -ur compact (wrap molecules; keep compact unit cell) + -center
    #
    # Keep all stdout/stderr out of function stdout (captured by caller).
    tmp_nojump="$work/nojump.xtc"
    {
      echo "=== trjconv PBC cleanup for $sid ==="
      echo "raw: $raw"
      echo "tpr: $tpr"
      echo "ndx: $ndx"
      echo
      echo "[1/2] trjconv -pbc nojump -> $tmp_nojump"
    } >"$work/trjconv.log"

    if is_dimer "$sid"; then
      # center group: Protein_CPP (21), output group: System (0)
      printf '0\n' | "$GMX" trjconv -s "$tpr" -f "$raw" -n "$ndx" -pbc nojump -o "$tmp_nojump" >>"$work/trjconv.log" 2>&1
      {
        echo
        echo "[2/2] trjconv -pbc cluster -center -> $cleaned"
      } >>"$work/trjconv.log"
      # Dimer has multiple protein molecules (chains); use -pbc cluster to keep the complex together.
      # cluster trjconv prompts: (1) clustering group, (2) centering group, (3) output group
      printf '21\n21\n0\n' | "$GMX" trjconv -s "$tpr" -f "$tmp_nojump" -n "$ndx" -pbc cluster -center -o "$cleaned" >>"$work/trjconv.log" 2>&1
    else
      # monomer center group: Protein (1), output group: System (0)
      printf '0\n' | "$GMX" trjconv -s "$tpr" -f "$raw" -n "$ndx" -pbc nojump -o "$tmp_nojump" >>"$work/trjconv.log" 2>&1
      {
        echo
        echo "[2/2] trjconv -pbc mol -ur compact -center -> $cleaned"
      } >>"$work/trjconv.log"
      printf '1\n0\n' | "$GMX" trjconv -s "$tpr" -f "$tmp_nojump" -n "$ndx" -pbc mol -ur compact -center -o "$cleaned" >>"$work/trjconv.log" 2>&1
    fi
  fi
  echo "$cleaned|$tpr"
}

run_one() {
  local sid="$1"
  local prod tpr xtc outdir work info ndx

  prod="$(prod_for_id "$sid")" || return 1
  ndx="$(ndx_for_id "$sid")"
  [[ -f "$ndx" ]] || { echo "ERROR: missing index file for $sid: $ndx" >&2; return 1; }
  outdir="$OUT_ROOT/$sid"
  work="$WORK_ROOT/$sid"
  mkdir -p "$outdir" "$work"

  echo "=== [$sid] ==="
  info="$(prep_trajectory "$sid" "$prod" "$work" "$ndx")"
  xtc="${info%%|*}"
  tpr="${info##*|}"

  cd "$outdir"

  # 1) RMSD backbone (ref=4, sel=4)
  printf '4\n4\n' | "$GMX" rms -s "$tpr" -f "$xtc" -n "$ndx" -o rmsd_backbone.xvg -tu ns

  # 2) RMSD ligand: fit backbone, RMSD CPP
  printf '4\n13\n' | "$GMX" rms -s "$tpr" -f "$xtc" -n "$ndx" -o rmsd_ligand.xvg -tu ns

  # 3) Minimum distance Protein–CPP
  printf '1\n13\n' | "$GMX" mindist -s "$tpr" -f "$xtc" -n "$ndx" -od mindist_pl.xvg -tu ns

  # 4) H-bonds (Protein vs CPP). Use hbond-legacy: new gmx hbond (2024+) rejects donor/acceptor
  # typing for many CGenFF ligands ("CPP has no acceptors"); legacy uses geometric OH/NH–O/N rules.
  printf '1\n13\n' | "$GMX" hbond-legacy -f "$xtc" -s "$tpr" -n "$ndx" -num hbond_num.xvg -tu ns

  # 5) Rg (Protein)
  printf '1\n' | "$GMX" gyrate -f "$xtc" -s "$tpr" -n "$ndx" -o rg.xvg -tu ns

  # 6) SASA + volume
  printf '1\n' | "$GMX" sasa -s "$tpr" -f "$xtc" -n "$ndx" -o sasa.xvg -tv sasa_volume.xvg -tu ns

  # 7) RMSF per residue (x-axis is residue index, not time — no -tu)
  printf '1\n' | "$GMX" rmsf -f "$xtc" -s "$tpr" -n "$ndx" -o rmsf_residue.xvg -res

  # 7b) Monomer: RMSF per residue on the last 50 ns only (for binding-pocket summary figure).
  # T_end_ns=200 for all monomer systems in T_end_registry.yaml → window [150,200] ns.
  # Note: gmx rmsf (2024.x here) does not accept -tu; use ps for -b/-e.
  if [[ "$sid" == monomer_* ]]; then
    printf '1\n' | "$GMX" rmsf -f "$xtc" -s "$tpr" -n "$ndx" -o rmsf_binding_site_last50ns.xvg -res \
      -b 150000 -e 200000
  fi

  # 7c) Monomer: contact-defined pocket residues (last 50 ns).
  # Define pocket as protein residues within 0.45 nm of ligand (CPPF) at ANY time in [150,200] ns.
  # We (1) write the residue list for sanity checks and (2) compute per-residue RMSF restricted to that pocket.
  if [[ "$sid" == monomer_* ]]; then
    # Create an index group "contact_pocket" containing protein atoms within cutoff of CPP (group 13).
    # Use -oi to get a time-independent mask; threshold 0.5 means "selected at least once".
    "$GMX" select -s "$tpr" -f "$xtc" -n "$ndx" \
      -b 150000 -e 200000 \
      -select 'group "Protein" and within 0.45 of group "CPP"' \
      -oi contact_pocket_oi.dat \
      -on contact_pocket.ndx \
      &>"$work/gmx_select_contact_pocket.log"

    # RMSF per residue for the contact pocket group (index in contact_pocket.ndx).
    printf '0\n' | "$GMX" rmsf -f "$xtc" -s "$tpr" -n contact_pocket.ndx \
      -o rmsf_contact_pocket_last50ns.xvg -res -b 150000 -e 200000 \
      &>"$work/rmsf_contact_pocket_last50ns.log"

    # Dump residue ids selected (from RMSF xvg first column).
    python3 - <<'PY'
from pathlib import Path

in_xvg = Path("rmsf_contact_pocket_last50ns.xvg")
out_txt = Path("contact_pocket_residues_last50ns.txt")

res = []
for line in in_xvg.read_text(errors="replace").splitlines():
    s = line.strip()
    if not s or s[0] in "#@&":
        continue
    parts = s.split()
    if len(parts) < 2:
        continue
    try:
        r = int(float(parts[0]))
    except ValueError:
        continue
    res.append(r)

res_u = sorted(set(res))
out_txt.write_text(
    "\n".join(
        [
            f"n_residues={len(res_u)}",
            "residue_ids=" + ",".join(map(str, res_u)),
            "",
        ]
    )
)
print(f"Wrote {out_txt} (n={len(res_u)})")
PY
  fi

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
