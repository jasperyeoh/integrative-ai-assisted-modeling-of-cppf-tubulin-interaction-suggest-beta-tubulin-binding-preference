# Integrative AI-Assisted Modeling of CPPF-Tubulin Interactions

This repository contains the computational workflow and analysis assets for a CPPF-tubulin molecular modeling study.

The project integrates AI-assisted structure modeling and molecular dynamics (MD) simulation to characterize binding behavior of **5-(3-chlorophenyl)-N-(3-pyridinyl)-2-furamide (CPPF)** with human tubulin systems (PDB template: `5IJ0`).

## Study Overview

Microtubules are clinically validated anticancer targets, but multidrug resistance (MDR) limits efficacy of many microtubule-targeting drugs. CPPF is a candidate microtubule-active compound with reported activity in MDR models, yet its structural binding mechanism has been unclear.

This repository documents a structure-based computational workflow combining:

- AI-assisted binding pose generation and model curation
- All-atom MD simulations with replicate designs
- Trajectory-derived stability and interaction analyses

## Main Computational Finding

Across the current modeling and MD evidence in this study, CPPF shows a **more stable and favorable interaction pattern with beta-tubulin** than with alpha-tubulin-containing alternatives, supporting a beta-tubulin binding preference hypothesis.

## Repository Guide

### Start Here

- `docs/RUNBOOK.md`: operational runbook for execution
- `docs/CONDA_ENVIRONMENTS.md`: **conda envs** (`mdprep`, `gmx-lite`, optional `mmpbsa`) and how to recreate them
- `docs/REPRODUCTION_SNAPSHOT.md`: **frozen HPC stack** (2026-05-18 exports + verification log)
- `conda/environment-mdprep.yml` / `conda/environment-gmx-lite.yml`: minimal install recipes
- `conda/exports/environment-*-full-2026-05-18.yml`: **exact envs used on the analysis node** (`--no-builds` exports)

### Core Workspace

- `revision_exec/`: primary execution workspace
  - system preparation and topology assets
  - replicate runs (`rep1`, `rep2`, `rep3`)
  - production MD scripts and logs
  - analysis outputs
- `revision_exec_6e7b/`: **6E7B supplementary MD** (β-GTP / microtubule-lattice-related straight conformation) — **complete**
  - Protenix predictions (5 samples, all pLDDT > 94, ipTM > 0.93), starting pose aligned to 6E7B (Cα RMSD 1.82 Å)
  - 3 × 200 ns production MD, cofactor-free protocol identical to the 5IJ0 main-text simulations
  - MM-PBSA-GB binding free energy: −27.82 ± 5.44 kcal/mol (statistically indistinguishable from 5IJ0's −31.19 ± 4.04 kcal/mol)
  - Directly addresses Reviewer Comment 4.2 (β-nucleotide-state / conformational-state dependence) with completed data, not future work
  - `analysis/figures/`: publication-quality TIFFs used as Supplementary Figs. S7–S9
  - `REPRODUCIBILITY.md`: full clone-and-rerun checklist (Git + Hugging Face)
  - See `revision_exec_6e7b/README.md` for full details
- `predictions/`: AI-assisted structure prediction outputs
  - `protenix/`: all Protenix predictions (CPPF + nocodazole benchmark)
    - `cppf_ab_tubulin_dimer/` — dimer poses (5 CIF samples + 4 curated PDB poses)
    - `cppf_alpha_tubulin/` — α-monomer poses (5 CIF + 4 PDB)
    - `cppf_beta_tubulin/` — β-monomer poses (3 CIF + 3 PDB + confidence JSONs)
    - `nocodazole_ab_tubulin_dimer/` — benchmark (5 CIF + exported PDB)
    - `nocodazole_alpha_tubulin/` — benchmark (5 CIF + exported PDB)
    - `nocodazole_beta_tubulin/` — benchmark (5 CIF + exported PDB)
  - `rfaa/`: RoseTTAFold All-Atom predictions (CPPF + nocodazole, PDB + aux.pt)
  - `chai1/`: Chai-1 predictions (CPPF + nocodazole, 5 ranks each × 6 targets)
  - `swissdock/`: SwissDock docking results (dimer + α/β monomers, dock4 + extracted PDBs)
  - `umol/`: Umol predictions (β-tubulin primary, α-tubulin, dimer notebooks)
  - See each platform's `README.md` for details
- `cppf/`: CPPF provenance assets (for example, source structure files)
- `inputs/`: downloaded source inputs and provenance records
- `legacy_templates/`: archived legacy templates (reference only)
- `work/`: auxiliary scratch area

### Key Files

- Starting pose (AI-assisted): `Protenix/CPPF/ab Tub-CPPF/AlphaFold3_abTub_CPPF_pose1_V236_ptm0.96802771091.pdb`
- Tubulin template structure: `revision_exec/5IJ0.pdb`
- Main topology entry: `revision_exec/prep/gate_topol.top`
- Production MDP: `revision_exec/input/mdp/md_prod_200ns.mdp`

## Reproducibility Notes

- **Conda (paper runs):** see `docs/REPRODUCTION_SNAPSHOT.md` and dated files under `conda/exports/` (captured 2026-05-18 on the project HPC node).
- **Conda (general setup):** see `docs/CONDA_ENVIRONMENTS.md` and minimal YAMLs under `conda/`.
- Execution provenance is captured in run logs, checksum manifests, and dataset-upload documentation under `revision_exec/` and `docs/`.
- Current production workflow supports replicate-based runs and checkpoint continuation.
- Large trajectories (multi-GB `xtc`) are listed in `revision_exec/LARGE_FILES_NOT_IN_GIT.txt` if not in git; see also `docs/git_binary_data.md`.
- **Trajectory archive (primary):** `docs/HUGGINGFACE_DATASET.md` — `revision_exec/scripts/huggingface_upload_trajectories.sh` (`HF_DATASET_REPO=...`, token via `huggingface-cli login` or `~/.huggingface_token`).  
- **Zenodo (optional DOI / subset):** `docs/ZENODO_UPLOAD_SERVER.md` — `revision_exec/scripts/zenodo_upload_trajectories.sh`.

## Reproducible Pipeline (Nextflow)

A complete end-to-end Nextflow pipeline is available under `workflows/`:

```bash
# Install Nextflow
CONDA_SOLVER=classic conda create -y -n nextflow -c conda-forge -c bioconda nextflow openjdk
export PATH=${HPC_WORKSPACE}/miniconda3/envs/nextflow/bin:$PATH

# Run full pipeline
nextflow run workflows/main.nf -profile hpc -c workflows/nextflow.config -resume

# Smoke test (quick validation)
nextflow run workflows/main.nf -profile local -c workflows/nextflow.config -c workflows/smoke_test.config --stage full -resume
```

See `workflows/README_NEXTFLOW.md` for full documentation.

## Data and Large Files

MD trajectories and related binary outputs can be large (for example, multi-GB `xtc` files).  
Recommended practice:

- keep scripts, configs, logs, and analysis code in Git;
- manage large simulation binaries via external storage and document paths/checksums in `docs/`.

### Dimer trajectories: the “200–300 ns” window is **not** missing

On the **Heterodimer (dimer) replicates**, the first production segment is still **named** `md_200ns.xtc` on disk (historical GROMACS `deffnm` / continuation). **That file can cover ~0–300 ns** of simulation time; the **200–300 ns** range is **inside** it, not absent. Continuation segments are the `md_350ns.part*.xtc` and `md_400ns.part*.xtc` files. **Monomer** `md_200ns.xtc` files are **~200 ns** production only.

- Full segment table, symlink aliases, and Hub naming notes: **[`docs/DIMER_TRAJECTORY_NAMING.md`](docs/DIMER_TRAJECTORY_NAMING.md)**  
- **Copy-paste text** for the Hugging Face dataset card: **[`revision_exec/HF_DATASET_CARD_README.md`](revision_exec/HF_DATASET_CARD_README.md)**

## Citation

If you use this repository, please cite the associated publication when it becomes available. Until then, cite this repository and the public trajectory dataset URL in any derivative work.

