# Integrative AI-Assisted Modeling of CPPF-Tubulin Interactions

This repository contains the computational workflow and analysis assets for the manuscript:

**"Integrative AI-Assisted Modeling of CPPF-Tubulin Interactions Suggests beta-Tubulin Binding Preference."**

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
- `docs/MD_revision_plan.md`: reviewer-oriented revision plan
- `docs/pregress.md`: chronological experiment and execution log

### Core Workspace

- `revision_exec/`: primary execution workspace
  - system preparation and topology assets
  - replicate runs (`rep1`, `rep2`, `rep3`)
  - production MD scripts and logs
  - analysis outputs
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

- The execution history, parameter changes, and troubleshooting decisions are tracked in `docs/pregress.md`.
- Current production workflow supports replicate-based runs and checkpoint continuation.
- For practical repository management, very large MD binaries may be stored outside Git history and referenced by path/log metadata.

## Data and Large Files

MD trajectories and related binary outputs can be large (for example, multi-GB `xtc` files).  
Recommended practice:

- keep scripts, configs, logs, and analysis code in Git;
- manage large simulation binaries via external storage and document paths/checksums in `docs/`.

## Citation

If you use this repository, please cite the associated manuscript when available.

Suggested citation placeholder:

Yang J, Liang L, Zhu D, Yin X, Feng Y, Tang S, Li M.  
Integrative AI-Assisted Modeling of CPPF-Tubulin Interactions Suggests beta-Tubulin Binding Preference.  
(Manuscript in preparation/submission.)

