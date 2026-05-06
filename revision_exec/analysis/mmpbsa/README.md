# MM-PBSA (`gmx_MMPBSA`)

This folder contains the **dimer rep1/rep2/rep3 last-50ns (350–400 ns)** MM-PBSA-GB runs used for the revision.

## Current status on this node (2026-05-06)

- `gmx_MMPBSA` runs in conda env `mmpbsa` (`gmx_MMPBSA v1.5.0.3`).
- `cpptraj` is required by `gmx_MMPBSA`. On this node it is available (may be provided via a local fix if the base env is missing it).

## Numerical overflow in bond terms (known issue)

Some `sander` GB outputs may show fixed-width overflow in bond terms (e.g., `BOND = *************`). Those bond energy terms were **excluded from per-frame reporting**. This does **not** affect binding free energy reporting because bond contributions cancel upon subtraction (Complex − Receptor − Ligand); the reported **ΔTOTAL** is unaffected.

## Fix: create a clean MM-PBSA env that includes `cpptraj`

On some images, the existing `mmpbsa` env may have AmberTools installed without `cpptraj`.
The robust fix is to create a fresh env pinned to a supported Python version:

```bash
CONDA_SOLVER=classic conda create -n mmpbsa_py311 -c conda-forge -c bioconda \
  python=3.11 gmx_mmpbsa ambertools mpi4py -y

conda run -n mmpbsa_py311 which cpptraj
conda run -n mmpbsa_py311 gmx_MMPBSA -h
```

## Run (GB, last 50 ns)

Smoke test (few frames, sanity check):

```bash
MMPBSA_ENV=mmpbsa_py311 bash revision_exec/analysis/mmpbsa/run_dimer_rep1_last50ns_mmpbsa.sh
```

Subsampled full-window GB-only (default interval targets ~50 snapshots in 350–400 ns):

```bash
MMPBSA_ENV=mmpbsa_py311 MMPBSA_MODE=full bash revision_exec/analysis/mmpbsa/run_dimer_rep1_last50ns_mmpbsa.sh
```

Outputs are written under:
- `revision_exec/analysis/mmpbsa/work_dimer_rep{1,2,3}_last50ns_smoke/`
- `revision_exec/analysis/mmpbsa/work_dimer_rep{1,2,3}_last50ns_full/`

Summary CSV (all three replicates):
- `revision_exec/analysis/mmpbsa/mmpbsa_summary.csv`

