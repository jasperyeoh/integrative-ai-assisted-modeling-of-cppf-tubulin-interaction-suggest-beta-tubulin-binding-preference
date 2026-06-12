#!/usr/bin/env bash
# 6E7B supplementary MD — system prep through NPT + rep1 production TPR
set -eo pipefail

REPO="/root/autodl-tmp/tubulin-cppf-md"
WORK="${REPO}/revision_exec_6e7b"
PREP="${WORK}/prep"
MAIN="${REPO}/revision_exec"
NTOMP=$(nproc)

eval "$(conda shell.bash hook)"
conda activate gmx-lite

cd "${WORK}"
mkdir -p prep md/rep1 scripts logs

echo "============================================"
echo " 6E7B MD pipeline — system preparation"
echo "============================================"

# --- Step A: CIF → aligned complex PDB (no cofactors) ---
echo ""
echo "[A] Align Protenix sample_0 to 6E7B template..."
python scripts/prepare_6e7b_complex.py \
  --cif input/protenix_predictions/predictions/protenix_prediction_6E7B_250526_sample_0.cif \
  --template input/6E7B.pdb \
  --out prep/complex_start.pdb | tee prep/align.log

cp prep/complex_start.pdb prep/complex_start_clean.pdb

python "${MAIN}/scripts/validate_complex_pdb.py" \
  --pdb prep/complex_start_clean.pdb \
  --require-chains A B C \
  --require-resnames l01 \
  --report logs/complex_validation_report.txt

# --- Step B: protein-only pdb2gmx ---
echo ""
echo "[B] pdb2gmx (protein only, amber99sb-ildn)..."
python "${MAIN}/scripts/extract_protein_only_pdb.py" \
  --in prep/complex_start_clean.pdb \
  --out prep/protein_only_ab.pdb

echo "1" | gmx pdb2gmx \
  -f prep/protein_only_ab.pdb \
  -o prep/processed.gro \
  -p prep/topol.top \
  -ff amber99sb-ildn \
  -water tip3p \
  -ignh

# --- Step C: topology — add CPPF_RESP2 (same as 5IJ0 gate) ---
echo ""
echo "[C] Patch topology for CPPF_RESP2..."
python3 - <<'PY'
from pathlib import Path
top = Path("prep/topol.top")
text = top.read_text()
ligand_include = '#include "../../revision_exec/input/ligand/CPPF_RESP2.itp"\n'
posres_include = '#ifdef POSRES\n#include "../../revision_exec/input/ligand/posre_CPPF_RESP2.itp"\n#endif\n'
if "CPPF_RESP2.itp" not in text:
    text = text.replace(
        '; Include chain topologies\n',
        '; Include CPPF ligand topology (GAFF2 + RESP2)\n' + ligand_include + '\n; Include chain topologies\n',
        1,
    )
if "posre_CPPF_RESP2.itp" not in text:
    text = text.replace(
        '; Include water topology\n',
        posres_include + '\n; Include water topology\n',
        1,
    )
if "CPPF_RESP2" not in text.split("[ molecules ]")[-1]:
    text = text.rstrip() + "\nCPPF_RESP2          1\n"
top.write_text(text)
print("Updated prep/topol.top")
PY

grep -A6 '\[ molecules \]' prep/topol.top | tee prep/molecules_check.txt

# --- Step D: fit ligand GRO to pose, merge with protein ---
echo ""
echo "[D] Fit CPPF coordinates and merge with protein..."
python "${MAIN}/scripts/fit_ligand_gro_to_pose_pdb.py" \
  --pose-pdb prep/complex_start_clean.pdb \
  --pose-resname l01 \
  --pose-chain C \
  --ligand-gro "${MAIN}/input/ligand/CPPF_GAFF2_bcc.gro" \
  --out-gro prep/CPPF_pose_fitted.gro \
  --fit-heavy-only

python scripts/merge_protein_ligand_gro.py \
  --protein prep/processed.gro \
  --ligand prep/CPPF_pose_fitted.gro \
  --out prep/complex_with_cppf.gro \
  --ligand-resname CPP \
  --ligand-resnr 452

# --- Step E: solvate + ionize ---
echo ""
echo "[E] Solvate and add ions (0.15 M)..."
mkdir -p prep/mdp
cp "${MAIN}/input/mdp/"*.mdp prep/mdp/

gmx editconf -f prep/complex_with_cppf.gro -o prep/newbox.gro -bt dodecahedron -d 1.5 -c
gmx solvate -cp prep/newbox.gro -cs spc216.gro -o prep/solv.gro -p prep/topol.top
gmx grompp -f prep/mdp/ions.mdp -c prep/solv.gro -p prep/topol.top -o prep/ions.tpr -maxwarn 2
echo "SOL" | gmx genion -s prep/ions.tpr -o prep/solv_ions.gro -p prep/topol.top -pname NA -nname CL -neutral

grep -A8 '\[ molecules \]' prep/topol.top | tee prep/molecules_after_ions.txt

# --- Step F: index groups ---
echo ""
echo "[F] Build index.ndx (Protein_CPP + CPP)..."
printf "q\n" | gmx make_ndx -f prep/solv_ions.gro -o prep/index.ndx
LIG_NUM=$(grep -n '^\[ UNL \]' prep/index.ndx | head -1 | cut -d: -f1 || true)
if [[ -z "${LIG_NUM}" ]]; then
  LIG_NUM=$(grep -n '^\[ CPP \]' prep/index.ndx | head -1 | cut -d: -f1 || true)
fi
if [[ -z "${LIG_NUM}" ]]; then
  LIG_NUM=$(grep -n '^\[ MOL \]' prep/index.ndx | head -1 | cut -d: -f1 || true)
fi
if [[ -z "${LIG_NUM}" ]]; then
  echo "ERROR: Could not find ligand group (UNL/CPP/MOL) in index.ndx"; exit 1
fi
# Default make_ndx groups are 0-19; merged Protein|ligand becomes group 20.
printf "1 | 13\nname 20 Protein_CPP\nname 13 CPP\nq\n" | \
  gmx make_ndx -f prep/solv_ions.gro -n prep/index.ndx -o prep/index.ndx

# pdb2gmx writes posre_*.itp to the working dir; copy into prep/ for grompp.
cp -f posre_Protein_chain_{A,B}.itp prep/ 2>/dev/null || true

# --- Step G: EM → NVT → NPT ---
echo ""
echo "[G] EM / NVT / NPT (GPU)..."
GMX_GPU_EQ=""
GMX_GPU_PROD="-nb gpu -pme gpu -bonded gpu -update gpu -gpu_id 0"

gmx grompp -f prep/mdp/em.mdp -c prep/solv_ions.gro -p prep/topol.top \
  -o prep/em.tpr -n prep/index.ndx -maxwarn 2
# EM uses steepest descent; PME GPU is not supported for non-dynamic integrators.
gmx mdrun -v -deffnm prep/em -ntomp "${NTOMP}"

grep -E "Maximum force|Potential Energy" prep/em.log | tail -3

gmx grompp -f prep/mdp/nvt.mdp -c prep/em.gro -r prep/em.gro \
  -p prep/topol.top -n prep/index.ndx -o prep/nvt.tpr -maxwarn 2
gmx mdrun -v -deffnm prep/nvt -ntomp "${NTOMP}" ${GMX_GPU_EQ}

grep "Temperature" prep/nvt.log | tail -3

gmx grompp -f prep/mdp/npt.mdp -c prep/nvt.gro -r prep/nvt.gro -t prep/nvt.cpt \
  -p prep/topol.top -n prep/index.ndx -o prep/npt.tpr -maxwarn 2
gmx mdrun -v -deffnm prep/npt -ntomp "${NTOMP}" ${GMX_GPU_EQ}

grep -E "Density|Pressure" prep/npt.log | tail -4

# --- Step H: production TPR for rep1 ---
echo ""
echo "[H] grompp production (200 ns) for rep1..."
cp prep/mdp/md_prod_200ns.mdp prep/mdp/
gmx grompp -f prep/mdp/md_prod_200ns.mdp -c prep/npt.gro -t prep/npt.cpt \
  -p prep/topol.top -n prep/index.ndx -o md/rep1/md_200ns.tpr -maxwarn 2

echo ""
echo "============================================"
echo " Pipeline complete."
echo " Production TPR: md/rep1/md_200ns.tpr"
echo " Next: screen -S md_rep1 && gmx mdrun -v -deffnm md_200ns ..."
echo "============================================"
