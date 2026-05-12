# CPPF–Tubulin Phase 1 Nextflow Pipeline

This directory contains a Phase 1 Nextflow implementation for the reviewer-facing CPPF–tubulin MD workflow. It wraps the reproducible parts used in the revision:

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

- `RESP2_CHARGES` is a documented stub in Phase 1. The manuscript revision already uses locked RESP2/GAFF2 ligand assets and gate-validated cofactor topology handling.
- ProteinsPlus and PDBePISA are web-only and are not included as local Nextflow processes.
- Monomer analysis can be added by extending the same process patterns with monomer-specific topology/index paths. The current Phase 1 implementation focuses on the heterodimer workflow that supports the main revised MD/MM-PBSA evidence.
- Overleaf/PLOS manuscript packaging is separate from this computational workflow.

## Response Letter Wording

After smoke testing and committing the workflow, the response letter can accurately state:

> We have implemented a reproducible Phase 1 Nextflow workflow that wraps the validated structure-preparation handoff, molecular dynamics, PBC-corrected trajectory export, MM-PBSA binding free-energy calculation, free-energy landscape construction, and automated figure/table generation. The workflow, configuration files, smoke-test settings, and run documentation are available in the GitHub repository.
