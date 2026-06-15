#!/bin/bash
# ============================================================
# 6E7B CPPF-Tubulin MD Pipeline — Full System Preparation + Production
# ============================================================
# Run on AutoDL server (RTX 4090) with gmx-lite and mdprep envs.
# Follows the EXACT same protocol as 5IJ0 main-text:
#   AMBER99SB-ILDN (protein) + GAFF2/RESP2 (CPPF) + TIP3P water
#   NO cofactors (GTP/G2P/MG stripped by pdb2gmx — same as 5IJ0)
#
# Usage:
#   cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b
#   bash scripts/run_6e7b_md_pipeline.sh 2>&1 | tee pipeline.log
# ============================================================
set -euo pipefail

REPO="/root/autodl-tmp/tubulin-cppf-md"
WORK="${REPO}/revision_exec_6e7b"
PREP="${WORK}/prep"
INPUT="${WORK}/input"
SCRIPTS="${WORK}/scripts"
MDP_SRC="${REPO}/revision_exec/input/mdp"
LIG_SRC="${REPO}/revision_exec/input/ligand"

# ── Ensure conda is available ───────────────────────────────
eval "$(conda shell.bash hook)"

echo "============================================"
echo " 6E7B MD Pipeline — System Preparation"
echo "============================================"
echo "Start time: $(date)"
echo ""

# ============================================================
# STAGE 1: Prepare complex PDB from Protenix CIF
# ============================================================
echo "===== STAGE 1: CIF → aligned complex PDB ====="
conda activate gmx-lite   # numpy is here

CIF="${INPUT}/protenix_predictions/predictions/protenix_prediction_6E7B_250526_sample_0.cif"
TEMPLATE="${INPUT}/6E7B.pdb"

if [ ! -f "${CIF}" ]; then
    echo "ERROR: CIF not found: ${CIF}"
    exit 1
fi
if [ ! -f "${TEMPLATE}" ]; then
    echo "ERROR: Template not found: ${TEMPLATE}"
    exit 1
fi

mkdir -p "${PREP}"
python "${SCRIPTS}/prepare_6e7b_complex.py" \
    --cif "${CIF}" \
    --template "${TEMPLATE}" \
    --out "${PREP}/complex_start.pdb"

echo ""
echo "Checking output..."
head -5 "${PREP}/complex_start.pdb"
tail -5 "${PREP}/complex_start.pdb"
echo "Atom count: $(grep -c '^ATOM\|^HETATM' ${PREP}/complex_start.pdb)"
echo ""

# ============================================================
# STAGE 2: Extract protein-only PDB (chains A+B) for pdb2gmx
# ============================================================
echo "===== STAGE 2: Extract protein-only PDB ====="

python3 -c "
import sys
with open('${PREP}/complex_start.pdb') as f:
    lines = f.readlines()
with open('${PREP}/protein_only_ab.pdb', 'w') as out:
    for line in lines:
        if (line.startswith('ATOM') or line.startswith('HETATM')):
            chain = line[21:22]
            resn  = line[17:20].strip()
            # Only protein residues from chains A and B
            if chain in ('A','B') and resn not in ('CPP','l01','GTP','G2P','MG'):
                out.write(line)
    out.write('END\n')
print('Protein-only PDB written.')
print(f'  Atoms: {sum(1 for l in open(\"${PREP}/protein_only_ab.pdb\") if l.startswith(\"ATOM\"))}')
"

# ============================================================
# STAGE 3: Extract CPPF ligand PDB (chain C / CPP)
# ============================================================
echo ""
echo "===== STAGE 3: Extract CPPF ligand PDB ====="

python3 -c "
with open('${PREP}/complex_start.pdb') as f:
    lines = f.readlines()
with open('${PREP}/cppf_ligand.pdb', 'w') as out:
    for line in lines:
        if (line.startswith('ATOM') or line.startswith('HETATM')):
            resn = line[17:20].strip()
            if resn == 'CPP':
                out.write(line)
    out.write('END\n')
n = sum(1 for l in open('${PREP}/cppf_ligand.pdb') if l.startswith('ATOM') or l.startswith('HETATM'))
print(f'CPPF ligand PDB written: {n} atoms')
"

# ============================================================
# STAGE 4: pdb2gmx — process protein with AMBER99SB-ILDN
# ============================================================
echo ""
echo "===== STAGE 4: pdb2gmx (AMBER99SB-ILDN + TIP3P) ====="

cd "${PREP}"

# pdb2gmx: ff=amber99sb-ildn, water=tip3p
# This strips all non-protein residues (GTP, G2P, MG, etc.) — same as 5IJ0
gmx pdb2gmx \
    -f protein_only_ab.pdb \
    -o processed.gro \
    -p topol.top \
    -ff amber99sb-ildn \
    -water tip3p \
    -ignh \
    << 'EOF'
1
1
EOF

echo ""
echo "pdb2gmx complete. Topology files:"
ls -la topol*.itp topol.top 2>/dev/null || true

# ============================================================
# STAGE 5: Build topology — add CPPF ligand ITP
# ============================================================
echo ""
echo "===== STAGE 5: Modify topology to include CPPF ====="

# Copy ligand files from 5IJ0 (identical CPPF)
cp "${LIG_SRC}/CPPF_RESP2.itp" "${PREP}/"
cp "${LIG_SRC}/posre_CPPF_RESP2.itp" "${PREP}/"

# Modify topol.top:
# 1. Add CPPF_RESP2.itp include AFTER forcefield.itp but BEFORE moleculetype
# 2. Add CPPF position restraints
# 3. Add CPPF_RESP2 to [ molecules ]

python3 << 'PYEOF'
import re

with open("topol.top", "r") as f:
    content = f.read()

# 1. Insert CPPF_RESP2.itp after forcefield include, before first moleculetype
ff_include = '#include "amber99sb-ildn.ff/forcefield.itp"'
cppf_block = f"""{ff_include}

; Include CPPF ligand topology (GAFF2 + RESP2 charges)
; NOTE: defines [ atomtypes ], must come before any [ moleculetype ]
#include "CPPF_RESP2.itp"
"""
content = content.replace(ff_include, cppf_block)

# 2. Find the water topology include and add CPPF posres before it
water_include = '#include "amber99sb-ildn.ff/tip3p.itp"'
posres_block = f"""; Ligand position restraints (used in NVT/NPT when -DPOSRES)
#ifdef POSRES
#include "posre_CPPF_RESP2.itp"
#endif

{water_include}"""
content = content.replace(water_include, posres_block)

# 3. Add CPPF_RESP2 to [ molecules ] — after the last Protein_chain line
content = content.replace(
    "Protein_chain_B     1\n",
    "Protein_chain_B     1\nCPPF_RESP2          1\n"
)

with open("topol.top", "w") as f:
    f.write(content)

print("Topology updated with CPPF ligand.")
PYEOF

echo "Final topology [ molecules ] section:"
grep -A 10 '\[ molecules \]' topol.top

# ============================================================
# STAGE 6: Merge protein GRO + CPPF ligand → complex GRO
# ============================================================
echo ""
echo "===== STAGE 6: Merge protein + CPPF into complex GRO ====="

# Convert CPPF PDB to GRO
gmx editconf -f cppf_ligand.pdb -o cppf_ligand.gro 2>/dev/null

# Merge: take protein GRO, append CPPF atoms, update atom count
python3 << 'PYEOF'
# Read protein GRO
with open("processed.gro") as f:
    prot_lines = f.readlines()

# Read CPPF GRO
with open("cppf_ligand.gro") as f:
    lig_lines = f.readlines()

title = prot_lines[0].strip()
n_prot = int(prot_lines[1].strip())
prot_atoms = prot_lines[2:2+n_prot]
box = prot_lines[2+n_prot].strip()

n_lig = int(lig_lines[1].strip())
lig_atoms = lig_lines[2:2+n_lig]

# Fix ligand residue name to CPPF_RESP2 convention (UNL → CPP)
# GRO format: residue number (5), residue name (5), atom name (5), atom number (5), xyz
fixed_lig = []
for line in lig_atoms:
    # Replace residue name field (chars 5-10)
    resi_num = n_prot   # offset for renumbering
    fixed_lig.append(line)

n_total = n_prot + n_lig
with open("complex.gro", "w") as f:
    f.write(f"{title} + CPPF\n")
    f.write(f" {n_total}\n")
    for line in prot_atoms:
        f.write(line)
    for line in fixed_lig:
        f.write(line)
    f.write(f"{box}\n")

print(f"Complex GRO: {n_prot} protein + {n_lig} ligand = {n_total} total atoms")
PYEOF

# ============================================================
# STAGE 7: Solvation — editconf (box) + solvate + ions
# ============================================================
echo ""
echo "===== STAGE 7: Solvation + ions ====="

# Define box (dodecahedral, 1.0 nm distance to edge)
gmx editconf \
    -f complex.gro \
    -o newbox.gro \
    -c -d 1.0 -bt dodecahedron

# Solvate
gmx solvate \
    -cp newbox.gro \
    -cs spc216.gro \
    -o solv.gro \
    -p topol.top

# Copy MDP files from 5IJ0
cp "${MDP_SRC}/em.mdp" "${PREP}/"
cp "${MDP_SRC}/nvt.mdp" "${PREP}/"
cp "${MDP_SRC}/npt.mdp" "${PREP}/"
cp "${MDP_SRC}/md_prod_200ns.mdp" "${PREP}/"

# Add ions (neutralize + 0.15 M NaCl)
gmx grompp \
    -f em.mdp \
    -c solv.gro \
    -p topol.top \
    -o ions.tpr \
    -maxwarn 2

echo "SOL" | gmx genion \
    -s ions.tpr \
    -o solv_ions.gro \
    -p topol.top \
    -pname NA \
    -nname CL \
    -neutral \
    -conc 0.15

echo ""
echo "System composition after solvation + ions:"
grep -A 20 '\[ molecules \]' topol.top
echo ""

# ============================================================
# STAGE 8: Energy Minimization
# ============================================================
echo "===== STAGE 8: Energy Minimization ====="

gmx grompp \
    -f em.mdp \
    -c solv_ions.gro \
    -p topol.top \
    -o em.tpr \
    -maxwarn 2

gmx mdrun -v -deffnm em -ntmpi 1 -ntomp $(nproc) -nb gpu -gpu_id 0

echo ""
echo "EM potential energy:"
echo "10 0" | gmx energy -f em.edr -o em_potential.xvg 2>/dev/null | grep "Potential" || true
echo ""

# ============================================================
# STAGE 9: Create index file with combined groups
# ============================================================
echo "===== STAGE 9: Create index groups ====="

# We need Protein_CPP and Water_and_ions groups for tc-grps
# First, make an index with gmx make_ndx
cat << 'NDXEOF' | gmx make_ndx -f em.gro -o index.ndx
1 | 13
name 19 Protein_CPP
14 | 15 | 16
name 20 Water_and_ions
q
NDXEOF

echo ""
echo "Index groups created:"
gmx make_ndx -f em.gro -n index.ndx << 'NDXEOF2' 2>/dev/null | grep -E "^ *[0-9]+ " || true
q
NDXEOF2

# ============================================================
# STAGE 10: NVT Equilibration (100 ps)
# ============================================================
echo ""
echo "===== STAGE 10: NVT Equilibration (100 ps) ====="

gmx grompp \
    -f nvt.mdp \
    -c em.gro \
    -r em.gro \
    -p topol.top \
    -n index.ndx \
    -o nvt.tpr \
    -maxwarn 2

gmx mdrun -v -deffnm nvt -ntmpi 1 -ntomp $(nproc) -nb gpu -gpu_id 0

echo ""
echo "NVT temperature:"
echo "15 0" | gmx energy -f nvt.edr -o nvt_temperature.xvg 2>/dev/null | grep "Temperature" || true

# ============================================================
# STAGE 11: NPT Equilibration (100 ps)
# ============================================================
echo ""
echo "===== STAGE 11: NPT Equilibration (100 ps) ====="

gmx grompp \
    -f npt.mdp \
    -c nvt.gro \
    -r nvt.gro \
    -t nvt.cpt \
    -p topol.top \
    -n index.ndx \
    -o npt.tpr \
    -maxwarn 2

gmx mdrun -v -deffnm npt -ntmpi 1 -ntomp $(nproc) -nb gpu -gpu_id 0

echo ""
echo "NPT pressure:"
echo "17 0" | gmx energy -f npt.edr -o npt_pressure.xvg 2>/dev/null | grep "Pressure" || true
echo "NPT density:"
echo "22 0" | gmx energy -f npt.edr -o npt_density.xvg 2>/dev/null | grep "Density" || true

# ============================================================
# STAGE 12: Production MD Setup (Rep 1 — 200 ns)
# ============================================================
echo ""
echo "===== STAGE 12: Production MD Setup (rep1 — 200 ns) ====="

REP1="${WORK}/md/rep1"
mkdir -p "${REP1}"

gmx grompp \
    -f "${PREP}/md_prod_200ns.mdp" \
    -c "${PREP}/npt.gro" \
    -t "${PREP}/npt.cpt" \
    -p "${PREP}/topol.top" \
    -n "${PREP}/index.ndx" \
    -o "${REP1}/md_200ns.tpr" \
    -maxwarn 2

echo ""
echo "============================================"
echo " System Preparation Complete!"
echo "============================================"
echo ""
echo "End time: $(date)"
echo ""
echo "Files in prep/:"
ls -lh "${PREP}"/*.gro "${PREP}"/*.tpr "${PREP}"/*.top 2>/dev/null
echo ""
echo "Production TPR ready:"
ls -lh "${REP1}/md_200ns.tpr"
echo ""
echo "To start PRODUCTION MD (rep1):"
echo "  cd ${REP1}"
echo "  gmx mdrun -v -deffnm md_200ns -ntmpi 1 -ntomp \$(nproc) -nb gpu -pme gpu -bonded gpu -gpu_id 0 -update gpu"
echo ""
echo "For rep2 (different random seed), run:"
echo "  bash ${SCRIPTS}/setup_rep2.sh"
echo ""
echo "Estimated: ~50-55 ns/day on RTX 4090 → ~4 days per replicate"
echo "============================================"
