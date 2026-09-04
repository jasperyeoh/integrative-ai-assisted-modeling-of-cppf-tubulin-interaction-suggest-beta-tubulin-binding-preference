# Reproduction setup (sanitized)

This document records the public software setup for the CPPF-tubulin workflow. Exact host identifiers, local paths, account names, runtime logs, and full environment exports are intentionally excluded. Large trajectories are available on [Hugging Face](HUGGINGFACE_DATASET.md).

## Public configuration

| Field | Value |
|-------|--------|
| **GROMACS production target** | CUDA-enabled GROMACS 2024.5 or compatible |
| **Environment recipes** | Minimal, public YAML files under `conda/` |
| **Machine-specific records** | Intentionally not published |

Re-export after major conda upgrades or before a new paper revision.

## Conda environments (use these for reproduction)

| Env | Role | Public recipe |
|-----|------|---------------|
| `gmx-lite` | GROMACS CUDA and trajectory tools | `conda/environment-gmx-lite.yml` |
| `mdprep` | Topology, RESP2/Psi4, and ligand preparation | `conda/environment-mdprep.yml` |
| `mmpbsa` | `gmx_MMPBSA` post-processing | Create per `docs/RUNBOOK.md` |
| `nextflow` | Reproducible workflow engine | See `README.md` |

### Recreate from public recipes

```bash
conda env create -f conda/environment-gmx-lite.yml
conda env create -f conda/environment-mdprep.yml

conda activate gmx-lite && gmx -version   # expect CUDA GPU support
```

Machine-specific full exports can carry host, path, and account metadata. Keep them private or review and redact them before sharing.

## Data and manuscript (not in this git repo)

| Asset | Where |
|-------|--------|
| Production `.xtc` trajectories | Hugging Face dataset `HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers` — see `docs/HUGGINGFACE_DATASET.md` |
| Workflow, topology, inputs, and analysis scripts | This repository |
| Manuscript drafts and local execution records | Intentionally not included |

## Maintaining this document

Before publishing any environment snapshot, log, or command transcript, remove account identifiers, hostnames, absolute paths, access tokens, scheduler details, and other machine-specific metadata. Keep sensitive operational records outside the public repository.
