# RUNBOOK: Heterodimer-CPPF MD Revision Workflow

## 0) Scope and Locked Inputs
- MD engine environment: `gmx-lite` (`gmx 2024.5-conda_forge`)
- Protein template: `revision_exec/5IJ0.pdb`
- Starting complex pose (Protenix dimer pose1):
  - `Protenix/CPPF/ab Tub-CPPF/AlphaFold3_abTub_CPPF_pose1_V236_ptm0.96802771091.pdb`
- Locked method choices:
  - protein force field: `amber99sb-ildn`
  - ligand force field: `GAFF2`
  - water model: `TIP3P`
  - cofactors retained: `GTP/GDP/MG2+`
  - ligand charge route: `RESP2(0.5)` for CPPF

This runbook is command-oriented and assumes execution from:
- `/hpc2hdd/home/jyang577/jasperyeoh/TUB-CPPF/tubulin-cppf-md`

Current directory layout (cleaned):
- `docs/`: documentation (this runbook, plan, progress log)
- `inputs/`: raw downloads / provenance (e.g. PubChem SDF, supplement zip)
- `work/`: execution outputs and run directories
- `legacy/`: archived references from `yfeng494`

Top-level working directories (real directories, no symlinks):
- `revision_exec/`: main execution workspace (scripts, prep, reps, analysis)
- `cppf/`: PubChem CPPF assets (SDF, etc.)
- `reference_from_yfeng494/`: archived legacy templates (mdp, examples)

## 1) Directory Setup
Create execution directories:

```bash
mkdir -p revision_exec/{input,prep,scripts,logs,analysis}
mkdir -p revision_exec/rep{1,2,3}/{em,nvt,npt,md}
mkdir -p revision_exec/input/{ligand,ligand_sources,mdp,cofactors}
```

Copy fixed source files into `revision_exec/input`:

```bash
cp "revision_exec/5IJ0.pdb" "revision_exec/input/5IJ0.pdb"
cp "Protenix/CPPF/ab Tub-CPPF/AlphaFold3_abTub_CPPF_pose1_V236_ptm0.96802771091.pdb" \
   "revision_exec/input/protenix_pose1_abTub_CPPF.pdb"
# CPPF structure provenance (PubChem):
# - CID: 763830
# - InChIKey: AMHSJSHPHZOWHW-UHFFFAOYSA-N
# - Canonical SMILES: C1=CC(=CC(=C1)Cl)C2=CC=C(O2)C(=O)NC3=CN=CC=C3
cp "cppf/Conformer3D_COMPOUND_CID_763830.sdf" "revision_exec/input/ligand_sources/CPPF_PubChem_CID_763830_3D.sdf"

# Legacy template ligand files (optional; use only as templates, not as final charge source):
cp "reference_from_yfeng494/common/CPPF.mol2" "revision_exec/input/ligand/CPPF_legacy_template.mol2"
cp "reference_from_yfeng494/common/ions.mdp" "revision_exec/input/mdp/ions.mdp"
cp "reference_from_yfeng494/alpha_template/em.mdp" "revision_exec/input/mdp/em.mdp"
cp "reference_from_yfeng494/alpha_template/nvt.mdp" "revision_exec/input/mdp/nvt.mdp"
cp "reference_from_yfeng494/alpha_template/npt.mdp" "revision_exec/input/mdp/npt.mdp"
```

## 2) Build `md_200ns.mdp` From Legacy Template
Use legacy `md.mdp` as base and create upgraded production control file:

```bash
cp "reference_from_yfeng494/alpha_template/md.mdp" "revision_exec/input/mdp/md_200ns.mdp"
```

Then edit `revision_exec/input/mdp/md_200ns.mdp`:
- set `dt = 0.002`
- set `nsteps = 100000000`  (200 ns)
- keep `gen_vel = no` in production
- keep PME/LINCS consistent with equilibration

Replicate-specific seeds are controlled in NVT stage (`gen_seed`) not in production stage.

## 3) RESP2(0.5) for CPPF (Charge Fix)
Current legacy `CPPF.itp` is not accepted as final charge source.

Target output files:
- `revision_exec/input/ligand/CPPF_RESP2.mol2`
- `revision_exec/input/ligand/CPPF_RESP2.itp`
- `revision_exec/input/ligand/CPPF_RESP2.gro`

### CPPF structure provenance (locked)
Use PubChem as the structure definition for CPPF:
- PubChem CID: `763830`
- InChIKey: `AMHSJSHPHZOWHW-UHFFFAOYSA-N`
- Canonical SMILES: `C1=CC(=CC(=C1)Cl)C2=CC=C(O2)C(=O)NC3=CN=CC=C3`
- Downloaded 3D conformer file: `revision_exec/input/ligand_sources/CPPF_PubChem_CID_763830_3D.sdf`

### Locked implementation route for RESP2
Use **AmberTools + Multiwfn + Sobtop** as the default practical route:
1. geometry optimization (QM)
2. ESP in gas and water
3. fit RESP charges for both environments in Multiwfn
4. average charge vectors 0.5/0.5
5. write mixed charges into `CPPF_RESP2.mol2`
6. generate GAFF2 topology from RESP2-updated mol2

### Concrete command skeleton
Assume current directory is `tubulin-cppf-md/revision_exec/input/ligand`.

#### QM program requirement (execution blocker)
Multiwfn RESP/RESP2 fitting requires QM outputs (e.g. Gaussian `.fchk` or Molden `.molden`).

Current server status (checked on this machine):
- Gaussian: **not installed**
- ORCA: **not installed**

Practical options:
- **Use an open-source QM installed locally**: `Psi4` is supported via conda and works well with a Molden export.
- **Run QM elsewhere** (Gaussian/ORCA) and copy the resulting `.fchk/.molden` back into this folder, then continue with Multiwfn.
- **Use AmberTools `sqm`** as the QM backend (available in the `mdprep` env) to produce ESP data for charge fitting.

1) prepare QM inputs for gas and water (example names):
- `cppf_gas.*`
- `cppf_water.*`

2) run QM and export a Multiwfn-readable file:
- Gaussian: `.fchk`
- ORCA: `.molden`
- AmberTools: `sqm` route (if you choose it)

#### Concrete Psi4 route (recommended open-source option)
Psi4 is available in the `mdprep` conda env.

Prepare starting structure (3D) from the locked PubChem SDF:

```bash
conda run -n mdprep obabel \
  -isdf "../ligand_sources/CPPF_PubChem_CID_763830_3D.sdf" \
  -omol2 -O "cppf_pubchem_3d.mol2"
```

Example Psi4 inputs (HF/6-31G* for RESP-like ESP, gas vs water using PCM):
- `cppf_gas.dat`
- `cppf_water.dat`

Run (writes Molden files for Multiwfn):

```bash
conda run -n mdprep psi4 -n 8 cppf_gas.dat cppf_gas.out
conda run -n mdprep psi4 -n 8 cppf_water.dat cppf_water.out
```

Expected outputs for Multiwfn:
- `cppf_gas.molden`
- `cppf_water.molden`

3) run Multiwfn twice to fit RESP-like charges:
- gas-phase charges -> `charges_gas.txt`
- water-phase charges -> `charges_water.txt`

4) mix charges (0.5 each) with a small helper script:
```bash
python "../../scripts/mix_resp2_charges.py" \
  --gas charges_gas.txt \
  --water charges_water.txt \
  --out charges_resp2_05.txt
```

5) inject mixed charges into base mol2 and produce RESP2 mol2:
```bash
python "../../scripts/write_mol2_charges.py" \
  --in CPPF.mol2 \
  --charges charges_resp2_05.txt \
  --out CPPF_RESP2.mol2
```

6) generate GAFF2 topology from `CPPF_RESP2.mol2` using your chosen ligand-topology toolchain and produce:
- `CPPF_RESP2.itp`
- `CPPF_RESP2.gro`

Keep a method record:
- `revision_exec/logs/RESP2_method_record.md`

## 4) Prepare Starting Complex (Pose1 + 5IJ0)
Goal: produce one clean starting complex with:
- protein chains from `5IJ0`
- CPPF coordinates from Protenix pose1
- retained cofactors `GTP/GDP/MG`

Outputs:
- `revision_exec/prep/complex_start.pdb`
- `revision_exec/prep/complex_start_clean.pdb`

Required checks:
1. chain IDs stable (`A`, `B`)
2. ligand residue name consistent with topology
3. no atom naming collisions
4. cofactors present and explicitly tracked
5. ligand chain naming locked as `C` for this workflow

### Concrete scripted procedure
Run the provided script:
```bash
python "revision_exec/scripts/prepare_complex_from_pose1.py" \
  --template "revision_exec/input/5IJ0.pdb" \
  --pose "revision_exec/input/protenix_pose1_abTub_CPPF.pdb" \
  --out "revision_exec/prep/complex_start.pdb"
```

What this script does:
1. loads template (`5IJ0`) and pose1 PDB
2. aligns pose protein to template protein using CA atoms (chains A/B overlap)
3. keeps ligand coordinates from aligned pose
4. appends cofactors (`GTP/GDP/MG`) from 5IJ0
5. writes merged complex PDB

Then run a cleanup/validation pass:
```bash
python "revision_exec/scripts/validate_complex_pdb.py" \
  --pdb "revision_exec/prep/complex_start.pdb" \
  --require-chains A B \
  --require-resnames GTP GDP MG \
  --report "revision_exec/logs/complex_validation_report.txt"
```

## 5) Generate Topology-Compatible Protein Structure
Activate environment:

```bash
conda activate gmx-lite
```

Run `pdb2gmx` on **protein-only** structure (recommended and validated in gate test):

```bash
python "revision_exec/scripts/extract_protein_only_pdb.py" \
  --in "revision_exec/prep/complex_start_clean.pdb" \
  --out "revision_exec/prep/protein_only_ab.pdb"
```

Then run `pdb2gmx` on protein-only input:

```bash
gmx pdb2gmx \
  -f "revision_exec/prep/protein_only_ab.pdb" \
  -o "revision_exec/prep/processed.gro" \
  -p "revision_exec/input/topol.top" \
  -ff amber99sb-ildn \
  -water tip3p
```

Then integrate:
- ligand include (`CPPF_RESP2.itp`)
- cofactor includes (GTP/GDP/MG from validated parameter source; see main route below)
- molecule counts in `[ molecules ]`

Critical cofactor topology note:
- `pdb2gmx` is **protein-only** in this workflow.
- **Main route (recommended): parameterize cofactors via AmberTools (`tleap`) and convert to GROMACS (`acpype`).**
  - Rationale: `pdb2gmx` commonly fails on nucleotides/metal cofactors with “missing residue topology”.
  - This keeps the protein force field unchanged while making cofactor handling deterministic/reproducible.

### 5.1) Cofactor main route (tleap → acpype)
This produces GROMACS-ready `GDP/GTP/MG` includes that you can add to the GROMACS `topol.top`.

1) Extract cofactors from the merged complex PDB:

```bash
conda run -n mdprep python "revision_exec/scripts/extract_cofactors_pdb.py" \
  --in  "revision_exec/prep/complex_start_clean.pdb" \
  --out "revision_exec/prep/cofactors_gtp_gdp_mg.pdb" \
  --resnames GTP GDP MG
```

2) Run `tleap` on the cofactor-only PDB.

Important reality check:
- For PLOS Comp Biol review, **do not “improvise” nucleotide parameters** if you can avoid it.
- Use an established, peer-reviewed polyphosphate/nucleotide parameter set.
- `MG2+` is handled as a standard ion in GROMACS (`MG` in `amber99sb-ildn.ff/ions.itp`) and does not need `tleap`.

#### Recommended (reviewer-proof) nucleotide parameters
Use the AMBER Parameter Database polyphosphate parameters (Meagher/Redman/Carlson, JCC 2003):
- `revision_exec/input/cofactors_params/ADP.prep`
- `revision_exec/input/cofactors_params/ATP.prep`
- `revision_exec/input/cofactors_params/frcmod.phos`

These libraries use `*` in sugar atom names (e.g. `O5*`) while PDBs often use prime (e.g. `O5'`).
Convert atom names before LEaP:

```bash
conda run -n mdprep python "revision_exec/scripts/rename_nucleotide_prime_to_star.py" \
  --in  "revision_exec/prep/complex_start_clean.pdb" \
  --out "revision_exec/prep/complex_start_clean_ambernames.pdb" \
  --resnames GTP GDP
```

2) Split and parameterize `GTP` and `GDP` via GAFF2 (AmberTools).

Split the cofactor PDB into separate residue-instance PDBs:

```bash
conda run -n mdprep python "revision_exec/scripts/split_pdb_by_residue.py" \
  --in "revision_exec/prep/cofactors_gtp_gdp_mg.pdb" \
  --outdir "revision_exec/prep/cofactors_split" \
  --resnames GTP GDP MG
```

Then, in a clean working directory (example: `revision_exec/prep/cofactor_params/`):
- `GTP`: net charge typically `-4`
- `GDP`: net charge typically `-3`

If you cannot obtain/validate a dedicated nucleotide parameter set in time, GAFF2 is a last-resort fallback:
**Attempt AM1-BCC first** (may fail to converge for highly-charged polyphosphates):

```bash
antechamber -i GTP.pdb -fi pdb -o GTP_gaff2_bcc.mol2 -fo mol2 -at gaff2 -c bcc -nc -4 -rn GTP
parmchk2    -i GTP_gaff2_bcc.mol2 -f mol2 -o GTP.frcmod -s gaff2

antechamber -i GDP.pdb -fi pdb -o GDP_gaff2_bcc.mol2 -fo mol2 -at gaff2 -c bcc -nc -3 -rn GDP
parmchk2    -i GDP_gaff2_bcc.mol2 -f mol2 -o GDP.frcmod -s gaff2
```

If AM1-BCC fails (SQM SCF non-convergence), **fall back to gas charges** just to unblock MD (document this and later replace charges with RESP2):

```bash
antechamber -i GTP.pdb -fi pdb -o GTP_gaff2_gas.mol2 -fo mol2 -at gaff2 -c gas -nc -4 -rn GTP
parmchk2    -i GTP_gaff2_gas.mol2 -f mol2 -o GTP.frcmod -s gaff2

antechamber -i GDP.pdb -fi pdb -o GDP_gaff2_gas.mol2 -fo mol2 -at gaff2 -c gas -nc -3 -rn GDP
parmchk2    -i GDP_gaff2_gas.mol2 -f mol2 -o GDP.frcmod -s gaff2
```

3) Build Amber prmtop/inpcrd for each nucleotide in `tleap`, then convert via `acpype`:

```bash
source leaprc.gaff2
source leaprc.water.tip3p

GTP = loadmol2 GTP_gaff2_*.mol2
loadamberparams GTP.frcmod
saveamberparm GTP GTP.prmtop GTP.inpcrd

GDP = loadmol2 GDP_gaff2_*.mol2
loadamberparams GDP.frcmod
saveamberparm GDP GDP.prmtop GDP.inpcrd
quit
```

Convert:

```bash
acpype -p GTP.prmtop -x GTP.inpcrd -b GTP -o gmx -f
acpype -p GDP.prmtop -x GDP.inpcrd -b GDP -o gmx -f
```

## 6) Solvate and Ionize
Define box:

```bash
gmx editconf \
  -f "revision_exec/prep/processed.gro" \
  -o "revision_exec/prep/newbox.gro" \
  -bt dodecahedron -d 1.5
```

Solvate:

```bash
gmx solvate \
  -cp "revision_exec/prep/newbox.gro" \
  -cs spc216.gro \
  -o "revision_exec/prep/solv.gro" \
  -p "revision_exec/input/topol.top"
```

Note:
- `spc216.gro` is used as a solvent placement template.
- actual water model physics is controlled by topology/force-field choice (locked as TIP3P here).

Pre-ion grompp:

```bash
gmx grompp \
  -f "revision_exec/input/mdp/ions.mdp" \
  -c "revision_exec/prep/solv.gro" \
  -p "revision_exec/input/topol.top" \
  -o "revision_exec/prep/ions.tpr"
```

Ionize:

```bash
gmx genion \
  -s "revision_exec/prep/ions.tpr" \
  -o "revision_exec/prep/solv_ions.gro" \
  -p "revision_exec/input/topol.top" \
  -pname NA -nname CL -neutral
```

## 7) Build Index and Replicate Seeds
Build a reusable index file.

Important: the provided `nvt.mdp/npt.mdp` assume these groups exist:
- `Protein_CPP` (for `tc-grps`)
- `CPP` (for `energygrps = Protein CPP`)

Minimal index workflow (creates `Protein_CPP` and renames ligand group to `CPP`):

```bash
# 1) Generate a default index (creates Protein, Water_and_ions, and a ligand group often named MOL)
printf "q\n" | gmx make_ndx \
  -f "revision_exec/prep/solv_ions.gro" \
  -o "revision_exec/input/index.ndx"

# 2) Create Protein_CPP = Protein | CPP (the ligand group is commonly #13 before renaming)
printf "1 | 13\nname 21 Protein_CPP\nq\n" | gmx make_ndx \
  -f "revision_exec/prep/solv_ions.gro" \
  -n "revision_exec/input/index.ndx" \
  -o "revision_exec/input/index.ndx"

# 3) Rename ligand group (typically "MOL") to "CPP" to match energygrps in MDP
printf "name 13 CPP\nq\n" | gmx make_ndx \
  -f "revision_exec/prep/solv_ions.gro" \
  -n "revision_exec/input/index.ndx" \
  -o "revision_exec/input/index.ndx"
```

Create replicate-specific NVT MDP files:
- `rep1`: `gen_seed = 11001`
- `rep2`: `gen_seed = 22002`
- `rep3`: `gen_seed = 33003`

## 7.5) Position Restraints for Equilibration Stability
For NVT/NPT stages, ensure not only protein but also ligand/cofactors have explicit restraint strategy where needed.

Generate restraint templates (example):
```bash
gmx genrestr -f "revision_exec/input/ligand/CPPF_RESP2.gro" -o "revision_exec/input/ligand/posre_CPPF.itp" -fc 1000 1000 1000
```

If cofactor restraints are required by your equilibration protocol, generate analogous files and include under `#ifdef POSRES` blocks in topology.

Gate topology expectation (to avoid common “file not found” traps):
- Protein `posre_Protein_chain_{A,B}.itp` must be reachable by the chain `.itp` includes.
  - For the current gate setup, keep them in `revision_exec/prep/` alongside `gate_topol_Protein_chain_{A,B}.itp`.
- Ensure ligand restraint is actually included under `#ifdef POSRES`.
  - In this workspace, `revision_exec/prep/gate_topol.top` includes `revision_exec/input/ligand/posre_CPPF.itp` under `#ifdef POSRES`.

Rationale:
- Without explicit ligand/cofactor restraint policy, early equilibration can introduce avoidable ligand drift.

## 8) Phase 1.5 Gate Test (Short Run)
Before full 3x200 ns, run short gate on `rep1` (e.g., 2-5 ns).

Gate success criteria:
1. no unresolved critical grompp warnings
2. stable temperature/pressure behavior
3. no immediate ligand escape from obvious setup artifact
4. RMSD/Rg/H-bond scripts run without manual patching

If gate fails, stop and fix root cause before launching full replicates.

## 9) Full Replicate Workflow (rep1/rep2/rep3)
Use a real loop (no `repX` placeholder during execution):

```bash
for rep in rep1 rep2 rep3; do
  gmx grompp -f "revision_exec/input/mdp/em.mdp" \
    -c "revision_exec/prep/solv_ions.gro" \
    -p "revision_exec/input/topol.top" \
    -o "revision_exec/${rep}/em/em.tpr" \
    -n "revision_exec/input/index.ndx"
  gmx mdrun -deffnm "revision_exec/${rep}/em/em"

  gmx grompp -f "revision_exec/${rep}/nvt/nvt_${rep}.mdp" \
    -c "revision_exec/${rep}/em/em.gro" \
    -r "revision_exec/${rep}/em/em.gro" \
    -p "revision_exec/input/topol.top" \
    -o "revision_exec/${rep}/nvt/nvt.tpr" \
    -n "revision_exec/input/index.ndx"
  gmx mdrun -deffnm "revision_exec/${rep}/nvt/nvt"

  gmx grompp -f "revision_exec/input/mdp/npt.mdp" \
    -c "revision_exec/${rep}/nvt/nvt.gro" \
    -r "revision_exec/${rep}/nvt/nvt.gro" \
    -t "revision_exec/${rep}/nvt/nvt.cpt" \
    -p "revision_exec/input/topol.top" \
    -o "revision_exec/${rep}/npt/npt.tpr" \
    -n "revision_exec/input/index.ndx"
  gmx mdrun -deffnm "revision_exec/${rep}/npt/npt"

  gmx grompp -f "revision_exec/input/mdp/md_200ns.mdp" \
    -c "revision_exec/${rep}/npt/npt.gro" \
    -t "revision_exec/${rep}/npt/npt.cpt" \
    -p "revision_exec/input/topol.top" \
    -o "revision_exec/${rep}/md/md_200ns.tpr" \
    -n "revision_exec/input/index.ndx"
  # Production GPU flags:
  # - Only use GPU flags if a GPU is visible (check with `nvidia-smi`).
  # - Avoid `-update gpu` during restrained equilibration stages; keep it for unrestrained production if supported.
  gmx mdrun -deffnm "revision_exec/${rep}/md/md_200ns"
done
```

GPU offload note:
- This `gmx-lite` build may not detect GPUs on this login node; run production on the GPU node.
- Start with `-nb gpu -pme gpu` (if available).
- **NVT/NPT (with POSRES)**: avoid `-update gpu`. Prefer `-nb gpu -pme gpu` only.
- **Production**: optionally add `-bonded gpu -update gpu` *only if supported* by your build (CUDA) and the run is unrestrained.

### EM
```bash
# Example only for rep1:
gmx grompp -f "revision_exec/input/mdp/em.mdp" \
  -c "revision_exec/prep/solv_ions.gro" \
  -p "revision_exec/input/topol.top" \
  -o "revision_exec/rep1/em/em.tpr" \
  -n "revision_exec/input/index.ndx"
gmx mdrun -deffnm "revision_exec/rep1/em/em"
```

### NVT
```bash
gmx grompp -f "revision_exec/rep1/nvt/nvt_rep1.mdp" \
  -c "revision_exec/rep1/em/em.gro" \
  -r "revision_exec/rep1/em/em.gro" \
  -p "revision_exec/input/topol.top" \
  -o "revision_exec/rep1/nvt/nvt.tpr" \
  -n "revision_exec/input/index.ndx"
gmx mdrun -deffnm "revision_exec/rep1/nvt/nvt"
```

### NPT
```bash
gmx grompp -f "revision_exec/input/mdp/npt.mdp" \
  -c "revision_exec/rep1/nvt/nvt.gro" \
  -r "revision_exec/rep1/nvt/nvt.gro" \
  -t "revision_exec/rep1/nvt/nvt.cpt" \
  -p "revision_exec/input/topol.top" \
  -o "revision_exec/rep1/npt/npt.tpr" \
  -n "revision_exec/input/index.ndx"
gmx mdrun -deffnm "revision_exec/rep1/npt/npt"
```

### Production 200 ns
```bash
gmx grompp -f "revision_exec/input/mdp/md_200ns.mdp" \
  -c "revision_exec/rep1/npt/npt.gro" \
  -t "revision_exec/rep1/npt/npt.cpt" \
  -p "revision_exec/input/topol.top" \
  -o "revision_exec/rep1/md/md_200ns.tpr" \
  -n "revision_exec/input/index.ndx"
gmx mdrun -deffnm "revision_exec/rep1/md/md_200ns" -nb gpu -pme gpu -bonded gpu -update gpu
```

Resume if interrupted:

```bash
gmx mdrun -deffnm "revision_exec/rep1/md/md_200ns" -cpi "revision_exec/rep1/md/md_200ns.cpt"
```

## 10) Logging and Reproducibility
Maintain:
- `revision_exec/logs/run_manifest.csv`
- `revision_exec/logs/method_changes.md`

For each major command, append:
- timestamp
- replicate ID
- command
- output file prefix
- notes on warnings/errors

## 11) Analysis Deliverables
Required outputs (per replicate + aggregate):
- RMSD (backbone + ligand)
- RMSF
- Rg
- H-bond occupancy/persistence
- contact frequency
- interaction energy trends (vdW + electrostatic if available)

Output paths:
- `revision_exec/analysis/core_metrics/`
- `revision_exec/analysis/figures/`

## 12) MM-PBSA Stage (After Environment Confirmation)
When MM-PBSA environment is confirmed:
1. select consistent analysis windows across replicates
2. run MM-PBSA per replicate
3. aggregate mean/spread
4. run per-residue decomposition

Output paths:
- `revision_exec/analysis/mmpbsa/mmpbsa_summary.csv`
- `revision_exec/analysis/mmpbsa/mmpbsa_per_residue.csv`

If `gmx_MMPBSA` is missing, use an isolated environment:
```bash
conda create -n mmpbsa -c conda-forge -c bioconda gmx_mmpbsa mpi4py ambertools
conda activate mmpbsa
gmx_MMPBSA -h
```

Keep `gmx-lite` untouched for simulation runs and use `mmpbsa` only for post-processing.

## 13) Definition of Completion
This runbook execution is complete when:
1. 3 replicate trajectories are produced (or explicit justified partial with transparency)
2. all core metrics and figures pass QC
3. MM-PBSA summary and per-residue decomposition are available
4. manuscript text can be updated with one-to-one method/data traceability

