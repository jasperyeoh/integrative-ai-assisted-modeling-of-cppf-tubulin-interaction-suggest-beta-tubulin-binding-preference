# Conda environments (reproducibility)

This project uses **two conda environments** with different roles. Keep them separate: **`mdprep`** for setup and QM/charge workflows, **`gmx-lite`** for running **GPU-accelerated GROMACS** production and most trajectory tools.

## Quick start

```bash
# From repository root (directory that contains conda/)
conda env create -f conda/environment-mdprep.yml
conda env create -f conda/environment-gmx-lite.yml

conda activate gmx-lite
gmx -version   # must report: GPU support: CUDA
```

## Environment roles

| Name        | Purpose |
|------------|---------|
| **`mdprep`** | PDB/topol prep, `tleap`/`antechamber` (via AmberTools), ACPYPE, RDKit/OpenBabel, **Psi4** for electrostatics feeding RESP2; Python tooling. |
| **`gmx-lite`** | **GROMACS 2024.5** (CUDA build), `gmx mdrun` with `-nb gpu -pme gpu -bonded gpu`; small NumPy/Matplotlib/SciPy stack. |

Do **not** use an OpenCL-only or CPU-only GROMACS build for production on NVIDIA GPUs: `mdrun` will fall back to CPU (see `docs/pregress.md`).

## Install recipes (minimal)

- `conda/environment-mdprep.yml` — pin **`python=3.11`** and conda-forge/bioconda packages listed in the file.
- `conda/environment-gmx-lite.yml` — **`gromacs=2024.5=*cuda*`** so conda selects a CUDA-enabled build.

Full dependency snapshots (same machine that wrote them, **no build hashes**) for closer reproduction:

- `conda/exports/environment-mdprep-full.yml`
- `conda/exports/environment-gmx-lite-full.yml`

Those files list the full transitive closure; they may still differ slightly on another OS or solver version. Prefer the **minimal** YAMLs for new clones, and use the **full** exports when debugging “works on my node” issues.

## Verification checklist

**`gmx-lite` (required for MD):**

```bash
conda activate gmx-lite
gmx -version
# Expect: GROMACS version 2024.5-conda_forge (or similar), line "GPU support: CUDA"
```

If you see **GPU support: OpenCL** or no GPU line, reinstall the CUDA-labelled build:

```bash
conda install -n gmx-lite -c conda-forge "gromacs=2024.5=*cuda*"
```

**`mdprep`:**

```bash
conda activate mdprep
obabel -V
psi4 --version
python -c "import rdkit; print('rdkit', rdkit.__version__)"
```

## Multiwfn (RESP2 post-processing)

**Multiwfn** is used with Psi4 outputs for RESP/RESP2 charge fitting (`docs/RUNBOOK.md`). It is **not** installed via the `mdprep` YAML. This repo includes a **Linux noGUI** bundle under:

`revision_exec/tools/multiwfn/Multiwfn_2026.4.10_bin_Linux_noGUI/`

Add the program directory to `PATH`, or invoke with the full path to the `Multiwfn` executable as in `revision_exec/input/ligand/resp2_work/multiwfn_resp/calcRESP.sh`.

## Optional third environment (MM-PBSA)

`docs/RUNBOOK.md` describes a separate **`mmpbsa`** env for `gmx_mmpbsa` post-processing. Create it only when running that step; keep **`gmx-lite`** dedicated to simulations.

## Scripts and `GMX` binary path

GROMACS from conda-forge may install the binary as `.../envs/gmx-lite/bin.AVX2_256/gmx` (SIMD subdirectory). Scripts should not hard-code a user home path.

- Prefer: `conda activate gmx-lite` and `gmx` on `PATH`.
- Or: set **`GMX`** to the full path of the `gmx` executable before running shell scripts (e.g. `export GMX="$CONDA_PREFIX/bin.AVX2_256/gmx"` if that path exists).

`revision_exec/analysis_dimer_rep123_300ns/run_rep_analysis.sh` resolves `gmx` from `GMX`, `PATH`, or `CONDA_PREFIX`.

## CUDA / drivers

The **CUDA toolkit** used to *compile* the conda GROMACS package must be compatible with the **NVIDIA driver** on the node. If `mdrun` fails at GPU detection, check `nvidia-smi` and the GROMACS error log; align driver/CUDA stack with conda-forge’s GROMACS build (see `gmx -version` CUDA compiler line).
