# CPPF–Tubulin Phase 1 Nextflow Pipeline

This directory contains a Phase 1 Nextflow implementation for the CPPF-tubulin MD workflow. It wraps the reproducible parts of the analysis:

1. prepared topology handoff from validated assets,
2. EM/NVT/NPT,
3. production MD for three replicates,
4. PBC correction,
5. XVG export,
6. MM-PBSA,
7. FEL calculation,
8. figure/table/report generation.

The workflow is intentionally conservative. It starts from the gate-validated topology and cofactor assets under `revision_exec/prep/` rather than re-running the full ligand/cofactor parameterization route by default. Full local docking integration with Protenix/RFAA/Umol is a Phase 2 extension.

## Files

- `main.nf`: Phase 1 workflow.
- `nextflow.config`: local and SLURM/HPC profiles.
- `smoke_test.config`: short-run overrides for wiring tests.

## Install Nextflow

```bash
CONDA_SOLVER=classic conda create -y -n nextflow -c conda-forge -c bioconda nextflow openjdk
export PATH=${HPC_WORKSPACE}/miniconda3/envs/nextflow/bin:$PATH
nextflow -version
```

This repository was tested with Nextflow installed in the isolated `nextflow` conda environment. Keep that environment on `PATH` when running the commands below.

## Run From Repository Root

```bash
cd ${HPC_WORKSPACE}/GITHUB_NAMESPACE/TUB-CPPF/tubulin-cppf-md
```

The workflow resolves relative input paths against the Nextflow launch directory. If you run it from another directory, pass `--repo_root ${HPC_WORKSPACE}/GITHUB_NAMESPACE/TUB-CPPF/tubulin-cppf-md`.

## Smoke Tests

The smoke tests are for command wiring only. They are not scientific production runs.

### Step 1: validate prepared topology handoff

```bash
nextflow run workflows/main.nf \
  -profile local \
  -c workflows/nextflow.config \
  -c workflows/smoke_test.config \
  --stage prepare_topology
```

### Step 2: test EM/NVT/NPT wiring

```bash
nextflow run workflows/main.nf \
  -profile local \
  -c workflows/nextflow.config \
  -c workflows/smoke_test.config \
  --stage prepare_and_equil \
  -resume
```

### Step 3: test full Phase 1 wiring with a very short production override

```bash
nextflow run workflows/main.nf \
  -profile local \
  -c workflows/nextflow.config \
  -c workflows/smoke_test.config \
  -resume
```

In smoke mode, `PRODUCTION_MD` runs only 5,000 steps (10 ps at 2 fs) to validate command wiring. `MMPBSA` writes a placeholder result when `params.skip_mmpbsa = true`, because a smoke trajectory cannot support the 350--400 ns last-window MM-PBSA calculation.

## Full Production Run

Use the HPC profile for the real replicate run:

```bash
nextflow run workflows/main.nf \
  -profile hpc \
  -c workflows/nextflow.config \
  --outdir revision_exec/nf_output \
  -resume
```

Default full-run settings:

- `params.replicates = [1, 2, 3]`
- seeds: `11001`, `22002`, `33003`
- production mdp: `revision_exec/input/mdp/md_prod_200ns.mdp`
- production override: `nsteps = 200000000` (400 ns at 2 fs)
- main system: `dimer`
- `grompp_maxwarn = 1` to pass the known gate-validated CPPF atom-name mismatch warning. Do not increase this without inspecting the new warning.

## Resume

Nextflow-level resume:

```bash
nextflow run workflows/main.nf -profile hpc -c workflows/nextflow.config -resume
```

The `PRODUCTION_MD` process also attempts GROMACS-level resume inside its work directory if `${params.production_prefix}.cpt` exists.

## Expected Output

Default output root:

```text
revision_exec/nf_output/
├── prep/
├── replicates/
│   ├── rep1/
│   │   ├── em/
│   │   ├── nvt/
│   │   ├── npt/
│   │   └── prod/
│   ├── rep2/
│   └── rep3/
├── analysis/
│   ├── pbc/
│   ├── raw_xvg/
│   ├── fel/
│   └── mmpbsa/
├── figures/
│   └── dimer_rep123_panels_0-400ns.tif
├── tables/
│   └── mmpbsa_summary.csv
└── summary.json
```

## Smoke-Test Status

Tested on this machine on 2026-05-12 with:

```bash
export PATH=${HPC_WORKSPACE}/miniconda3/envs/nextflow/bin:$PATH
nextflow run workflows/main.nf \
  -profile local \
  -c workflows/nextflow.config \
  -c workflows/smoke_test.config \
  --stage full \
  -resume
```

Observed result: all Phase 1 smoke-test processes completed with exit code 0:

- `PREPARE_TOPOLOGY_PROC`
- `ENERGY_MINIMIZE` for rep1--rep3
- `NVT_EQUIL` for rep1--rep3
- `NPT_EQUIL` for rep1--rep3
- `PRODUCTION_MD` for rep1--rep3 using the 5,000-step smoke override
- `PBC_CORRECTION` for rep1--rep3
- `EXPORT_XVG` for rep1--rep3
- `FEL_CALCULATION` for rep1--rep3
- `PLOT_DIMER_TIMESERIES`
- `MMPBSA` placeholder mode and `AGGREGATE_MMPBSA`
- `GENERATE_REPORT`

Smoke-test outputs were written under `revision_exec/nf_output_smoke/`. This directory is ignored by Git.

Nextflow runtime work directories are configured under `workflows/work/` and ignored by Git. Older root-level Nextflow hash work directories matching `work/[0-9a-f][0-9a-f]/` are also ignored.

## Important Parameters

Override any parameter with `--name value`:

```bash
nextflow run workflows/main.nf \
  -profile hpc \
  -c workflows/nextflow.config \
  --outdir revision_exec/nf_output_test \
  --repo_root ${HPC_WORKSPACE}/GITHUB_NAMESPACE/TUB-CPPF/tubulin-cppf-md \
  --production_nsteps 500000 \
  --mdrun_prod_flags ''
```

Common parameters:

- `--input_complex`: defaults to `revision_exec/prep/complex_start_clean.pdb`.
- `--prepared_gro`: defaults to `revision_exec/prep/solv_ions_cppf.gro`.
- `--topology_file`: defaults to `revision_exec/prep/gate_topol.top`.
- `--index_file`: defaults to `revision_exec/input/index.ndx`.
- `--mmpbsa_start_ps`: defaults to `350000`.
- `--mmpbsa_end_ps`: defaults to `400000`.
- `--skip_mmpbsa true`: useful for short smoke tests.
- `--grompp_maxwarn 0`: disable warning bypass if you want strict `grompp` failure behavior.

## Known Scope Boundaries

- `RESP2_CHARGES` is a documented stub in Phase 1. The current workflow uses locked RESP2/GAFF2 ligand assets and gate-validated cofactor topology handling.
- ProteinsPlus and PDBePISA are web-only and are not included as local Nextflow processes.
- Monomer analysis can be added by extending the same process patterns with monomer-specific topology/index paths. The current Phase 1 implementation focuses on the heterodimer workflow that supports the main revised MD/MM-PBSA evidence.
- Document packaging is separate from this computational workflow.

## Workflow Summary

After smoke testing, the workflow can be summarized as:

> We have implemented a reproducible Phase 1 Nextflow workflow that wraps the validated structure-preparation handoff, molecular dynamics, PBC-corrected trajectory export, MM-PBSA binding free-energy calculation, free-energy landscape construction, and automated figure/table generation. The workflow, configuration files, smoke-test settings, and run documentation are available in the GitHub repository.

## Phase 2: Docking Stage Installation Reference

Phase 2 will add Stage 1 docking processes upstream of `workflows/main.nf`, turning the pipeline into a full SMILES + PDB/sequence → pose → MD workflow.

The planned local docking tools are:

- Protenix: primary AI-based protein-ligand structure prediction tool.
- RoseTTAFold All-Atom (RFAA): secondary protein-ligand complex prediction tool.
- Umol: additional sequence-based protein-ligand prediction tool.
- Protenix-Dock: optional classical docking comparator.

Install each tool in a separate conda environment. Recommended order: Protenix → RFAA → Umol → optional Protenix-Dock. Test one small case per tool before connecting it to Nextflow.

### 1. Protenix

Purpose: predict protein-ligand complex structures from amino-acid sequence(s) and ligand SMILES.

- GitHub: https://github.com/bytedance/Protenix
- PyPI: https://pypi.org/project/protenix/
- License: Apache 2.0
- Reference: Zhang et al., bioRxiv 2026. doi:10.64898/2026.04.10.717613

```bash
# Create isolated environment
conda create -n protenix python=3.10 -y
conda activate protenix

# Install Protenix CLI
pip install protenix

# Optional MSA dependencies
conda install -c bioconda hmmer kalign2 -y

# Verify installation
protenix pred --help

# Small test case; see:
# https://github.com/bytedance/Protenix/blob/main/examples/input.json
protenix pred \
  -i examples/input.json \
  -o ./test_output \
  -n protenix_base_default_v1.0.0
```

CPPF-tubulin input template:

```json
{
  "sequences": [
    {"proteinChain": {"sequence": "<TUBA1B_sequence>", "count": 1}},
    {"proteinChain": {"sequence": "<TUBB3_sequence>", "count": 1}},
    {"ligand": {"smiles": "O=C(Nc1cccnc1)c1ccc(-c2cccc(Cl)c2)o1", "count": 1}}
  ],
  "modelSeeds": [1, 2, 3, 4, 5]
}
```

Notes:

- Use `protenix_base_default_v1.0.0` on A800/A100-class GPUs.
- Expected runtime is approximately minutes per complex on A100/A800-class hardware, depending on input size and MSA settings.

### 2. RoseTTAFold All-Atom (RFAA)

Purpose: predict protein-small-molecule complex structures as an independent AI-based docking/modeling method.

- GitHub: https://github.com/baker-laboratory/RoseTTAFold-All-Atom
- License: MIT
- Reference: Krishna et al., Science 2024. doi:10.1126/science.adl2528

```bash
git clone https://github.com/baker-laboratory/RoseTTAFold-All-Atom.git
cd RoseTTAFold-All-Atom

# Create environment
conda env create -f environment.yaml
conda activate RFAA

# Download model weights (~1.5 GB)
wget http://files.ipd.uw.edu/pub/RF-All-Atom/weights/RFAA_paper_weights.pt

# Verify installation
python -m rf2aa.run_inference --help

# Example protein-ligand inference
python -m rf2aa.run_inference \
  --config-name base \
  protein_inputs.A.fasta_file=examples/protein/7u7w_A.fasta \
  sm_inputs.B.input=examples/small_molecule/XG4.sdf \
  sm_inputs.B.input_type=sdf \
  job_name=cppf_tubulin_test
```

Generate CPPF SDF from SMILES:

```bash
python - <<'PY'
from rdkit import Chem
from rdkit.Chem import AllChem

mol = Chem.MolFromSmiles("O=C(Nc1cccnc1)c1ccc(-c2cccc(Cl)c2)o1")
mol = Chem.AddHs(mol)
AllChem.EmbedMolecule(mol, AllChem.ETKDG())
Chem.MolToMolFile(mol, "cppf/CPPF.sdf")
PY
```

Notes:

- Requires CUDA >= 11.7; A800/CUDA 12 is compatible.
- Full UniRef30 MSA databases are large. If they are unavailable, test `--use_esm_msa` as a lower-dependency alternative.
- Large alpha/beta tubulin heterodimer inputs (~900 residues) can take tens of minutes per inference.

### 3. Umol

Purpose: sequence-based protein-ligand complex prediction.

- GitHub: https://github.com/patrickbryant1/Umol
- License: Apache 2.0
- Reference: Bryant et al., Nature Communications 2024. doi:10.1038/s41467-024-48837-6

```bash
git clone https://github.com/patrickbryant1/Umol.git
cd Umol

conda create -n umol python=3.9 -y
conda activate umol
pip install -r requirements.txt

# Download model weights; see upstream README for the current command.
bash scripts/download_weights.sh

# Test run
bash predict.sh \
  --msa examples/test_msa.a3m \
  --smiles "O=C(Nc1cccnc1)c1ccc(-c2cccc(Cl)c2)o1" \
  --outdir ./test_output
```

Known limitations:

- Umol has a sequence-length limit of approximately 400 amino acids.
- The full alpha/beta heterodimer (~900 residues) is not suitable directly.
- TUBB3 beta-tubulin monomer is ~445 amino acids, so a pocket-centered truncation strategy may be needed.
- Umol does not use an input PDB receptor structure directly; it predicts from sequence/MSA.

### 4. Protenix-Dock (Optional)

Purpose: optional classical protein-ligand docking comparator.

- GitHub: https://github.com/bytedance/Protenix-Dock
- License: GPLv3

```bash
git clone https://github.com/bytedance/Protenix-Dock.git
cd Protenix-Dock

conda env create -f environment.yml
conda activate protenix-dock

python - <<'PY'
from pxdock import ProtenixDock

dock = ProtenixDock("5IJ0_cleaned.pdb")
dock.set_box([0.0, 0.0, 0.0], [20.0, 20.0, 20.0])
results = dock.run_docking("cppf/CPPF.sdf")
print(results)
PY
```

### Phase 2 Nextflow Integration Sketch

After the tools are installed and individually tested, add the following Stage 1-style processes before the Phase 1 MD handoff:

```nextflow
process PROTENIX_PREDICT {
    conda 'protenix'
    input:
    path input_json
    output:
    path "protenix_poses/*.cif"
    script:
    """
    protenix pred -i ${input_json} -o protenix_poses -n protenix_base_default_v1.0.0
    """
}

process RFAA_PREDICT {
    conda 'RFAA'
    input:
    tuple path(fasta), path(ligand_sdf)
    output:
    path "rfaa_output/*.pdb"
    script:
    """
    python -m rf2aa.run_inference \\
      --config-name base \\
      protein_inputs.A.fasta_file=${fasta} \\
      sm_inputs.B.input=${ligand_sdf} \\
      sm_inputs.B.input_type=sdf \\
      job_name=rfaa_cppf_tubulin
    """
}

process UMOL_PREDICT {
    conda 'umol'
    input:
    tuple path(msa), val(smiles)
    output:
    path "umol_output/*.pdb"
    script:
    """
    bash predict.sh \\
      --msa ${msa} \\
      --smiles "${smiles}" \\
      --outdir umol_output
    """
}
```

### Phase 2 Installation Priority

| Tool | Priority | Reason |
|------|----------|--------|
| Protenix | Highest | Primary docking/modeling tool in this study; simplest installation path |
| RFAA | Medium | Independent AI-based comparator; larger setup and weights |
| Umol | Medium | Useful additional predictor; sequence-length limit needs handling |
| Protenix-Dock | Optional | Classical docking comparator, not required for Phase 1 |
