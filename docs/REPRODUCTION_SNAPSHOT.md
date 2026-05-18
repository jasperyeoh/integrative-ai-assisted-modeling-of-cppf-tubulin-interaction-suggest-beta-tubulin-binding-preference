# Reproduction snapshot (frozen on HPC)

This file records **which software stack was used for the manuscript MD/analysis runs** on the project HPC node. Large trajectories stay on [Hugging Face](HUGGINGFACE_DATASET.md); this repo holds **code + conda exports** for fast re-setup.

## Frozen date and machine

| Field | Value |
|-------|--------|
| **Snapshot date (UTC)** | 2026-05-18 |
| **Host** | `3d456dcc0c92` |
| **Git commit** | `eacf19b` (`feat(revision): extend MD analysis plots and monomer pocket metrics`) |
| **Verification log** | `conda/exports/verification-2026-05-18.txt` |

Re-export after major conda upgrades or before a new paper revision.

## Conda environments (use these for reproduction)

| Env | Role | Minimal recipe | **Frozen export (`--no-builds`)** |
|-----|------|----------------|-------------------------------------|
| `gmx-lite` | GROMACS 2024.5 CUDA, trajectory tools | `conda/environment-gmx-lite.yml` | `conda/exports/environment-gmx-lite-full-2026-05-18.yml` |
| `mdprep` | Topology, RESP2/Psi4, ligand prep | `conda/environment-mdprep.yml` | `conda/exports/environment-mdprep-full-2026-05-18.yml` |
| `mmpbsa` | `gmx_MMPBSA` post-processing | (create per `docs/RUNBOOK.md`) | `conda/exports/environment-mmpbsa-full-2026-05-18.yml` |
| `nextflow` | Reproducible workflow engine | (see `README.md`) | `conda/exports/environment-nextflow-full-2026-05-18.yml` |

Canonical aliases (same content as the dated files above):

- `conda/exports/environment-gmx-lite-full.yml`
- `conda/exports/environment-mdprep-full.yml`
- `conda/exports/environment-mmpbsa-full.yml`
- `conda/exports/environment-nextflow-full.yml`

### Recreate from frozen export

```bash
cd /path/to/tubulin-cppf-md
export CONDA_SOLVER=classic   # if libmamba fails on your cluster image

conda env create -n gmx-lite -f conda/exports/environment-gmx-lite-full-2026-05-18.yml
conda env create -n mdprep    -f conda/exports/environment-mdprep-full-2026-05-18.yml
conda env create -n mmpbsa    -f conda/exports/environment-mmpbsa-full-2026-05-18.yml
conda env create -n nextflow  -f conda/exports/environment-nextflow-full-2026-05-18.yml

conda activate gmx-lite && gmx -version   # expect CUDA GPU support
```

Prefer **minimal** YAMLs (`conda/environment-*.yml`) for a clean install on a new OS; use **full** exports when versions must match the paper runs.

## Data and manuscript (not in this git repo)

| Asset | Where |
|-------|--------|
| Production `.xtc` trajectories | Hugging Face dataset `HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers` — see `docs/HUGGINGFACE_DATASET.md` |
| Locked topology/MDP/input | HPC: `revision_exec/input/` (~77 MB; keep a local tarball backup) |
| LaTeX manuscript & track changes | HPC: `Manu_v4_plos/`, `compared_manu/` (gitignored here) |

## Refresh this snapshot

```bash
export CONDA_SOLVER=classic
DATE=$(date -u +%F)
OUT=conda/exports
for env in gmx-lite mdprep mmpbsa nextflow; do
  conda env export -n "$env" --no-builds > "$OUT/environment-${env}-full-${DATE}.yml"
done
# Re-run version checks into verification-${DATE}.txt (see existing file as template)
# Update this document’s date table and git commit hash.
```
