#!/usr/bin/env bash
# Late-window (200-300 ns) GROMACS analysis for dimer reps, targeting extension decision criteria.
set -euo pipefail
BASE="${HPC_WORKSPACE}/GITHUB_NAMESPACE/TUB-CPPF/tubulin-cppf-md/revision_exec"
OUT="${BASE}/analysis_dimer_rep123_300ns"
# Use gmx binary directly: `conda run` does not forward stdin for interactive group selection.
GMX="${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx"

run_rep () {
  local rep="$1"
  local P="${BASE}/${rep}/prod"
  local O="${OUT}/${rep}"
  mkdir -p "$O"
  if [[ ! -s "${O}/rmsd_backbone.xvg" ]]; then
    echo "[${rep}] rms backbone (200-300 ns)"
    printf '4\n4\n' | "$GMX" rms -s "${P}/md_200ns.tpr" -f "${P}/md_200ns.xtc" -o "${O}/rmsd_backbone.xvg" -b 200 -tu ns
  fi
  if [[ ! -s "${O}/rmsd_ligand.xvg" ]]; then
    echo "[${rep}] rms ligand (UNL vs backbone fit)"
    printf '4\n13\n' | "$GMX" rms -s "${P}/md_200ns.tpr" -f "${P}/md_200ns.xtc" -o "${O}/rmsd_ligand.xvg" -fit rot+trans -b 200 -tu ns
  fi
  if [[ ! -s "${O}/rg_protein.xvg" ]]; then
    echo "[${rep}] gyrate protein"
    printf '1\n' | "$GMX" gyrate -s "${P}/md_200ns.tpr" -f "${P}/md_200ns.xtc" -o "${O}/rg_protein.xvg" -b 200 -tu ns
  fi
  if [[ ! -s "${O}/sasa_protein.xvg" ]]; then
    echo "[${rep}] sasa protein"
    printf '1\n' | "$GMX" sasa -s "${P}/md_200ns.tpr" -f "${P}/md_200ns.xtc" -o "${O}/sasa_protein.xvg" -b 200 -tu ns
  fi
  if [[ ! -s "${O}/mindist_protein_ligand.xvg" || ! -s "${O}/contacts_protein_ligand.xvg" ]]; then
    echo "[${rep}] mindist + contacts Protein-UNL"
    printf '1\n13\n' | "$GMX" mindist -s "${P}/md_200ns.tpr" -f "${P}/md_200ns.xtc" \
      -od "${O}/mindist_protein_ligand.xvg" -on "${O}/contacts_protein_ligand.xvg" -d 0.35 -b 200 -tu ns
  fi
  echo "[${rep}] rmsf C-alpha"
  if [[ ! -s "${O}/rmsf_ca.xvg" ]]; then
    # Disable fitting to avoid extra interactive prompt; per-residue C-alpha RMSF.
    printf '3\n' | "$GMX" rmsf -s "${P}/md_200ns.tpr" -f "${P}/md_200ns.xtc" -o "${O}/rmsf_ca.xvg" -res -fit no -b 200
  fi
  echo "[${rep}] done"
}

for rep in rep1 rep2 rep3; do
  run_rep "$rep"
done
