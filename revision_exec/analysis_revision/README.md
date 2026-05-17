# Revision analysis (GROMACS exports + Python figures)

This folder holds **Step 2** (bulk `gmx` export to `.xvg`) and **Step 3** (Python summaries and publication figures). Large outputs (`raw_xvg/`, `work/`, `figures/`, `tables/`) are **gitignored**; keep them on disk or archive separately.

## Prerequisites

- **GROMACS** on `PATH` or set `GMX` (see `run_export_all.sh`).
- **Topology / index**: `revision_exec/input/index.ndx` and per-system `prod/*.tpr` as laid out under `revision_exec/<system>/prod/`.
- **Python**: same conda/env as the rest of the repo; `matplotlib` with **Pillow** for TIFF LZW (standard with most installs).

## Step 2 — `run_export_all.sh`

Exports time series used for SHAM/FEL inputs and revision plots.

```bash
cd revision_exec/analysis_revision
bash run_export_all.sh                    # all 9 systems
ONLY_SYSTEM=dimer_rep1 bash run_export_all.sh   # one system (debug / heavy hbond)
```

**Behaviour (high level)**

- **Dimers**: `trjcat` merges segment `.xtc` files; stdout/stderr are suppressed so bash command substitution only receives the merged path.
- **PBC / centering**: `trjconv` writes to `work/<system_id>/trjconv.log` (not the shell stdout used for paths). **Two-step**: `-pbc nojump` then dimer **`-pbc cluster -center`** (Protein_CPP cluster) or monomer **`-pbc mol -ur compact -center`**. If `work/<system_id>/clean_pbc.xtc` already exists and `FORCE_TRJCONV` is unset or `0`, that file is **reused** to save hours of I/O.
- **Hydrogen bonds**: `gmx hbond-legacy` (CGenFF + newer `hbond` can fail on these systems).
- **Per-system outputs** under `raw_xvg/<system_id>/` (rms, rmsd, rg, mindist, hbnum, rmsf, etc.).
- **Monomer only**: `rmsf_binding_site_last50ns.xvg` — `gmx rmsf -res` on **[150,200] ns** (`-b 150000 -e 200000` ps) for binding-pocket summary in `revision_plot_monomer_boxplot.py` (mean of residues 236, 253, 314; `gmx rmsf` does not support `-tu` here).
- **End of run**: `merge_xvg_for_sham.py` builds aligned `.xvg` for Gibbs / SHAM (inner join on time, no blind `paste`).

**Environment**

| Variable | Meaning |
|----------|---------|
| `GMX` | Path to `gmx` binary |
| `ONLY_SYSTEM` | Restrict to one id from the `SYSTEMS` list |
| `FORCE_TRJCONV` | If `1`, always rerun `trjconv` even if `clean_pbc.xtc` exists |

## Step 3 — Python scripts

All plotting entry points default to **TIFF, 300 dpi, LZW** via `revision_figure_export.save_figure`.

| Script | Role |
|--------|------|
| `revision_plot_dimer_timeseries.py` | Dimer metrics: `--mode single` or `--mode panels` (2×2). |
| `revision_plot_monomer_boxplot.py` | Monomer α vs β boxplots + jitter. |
| `revision_plot_monomer_timeseries.py` | Monomer α \| β time series (2×2): ligand RMSD + mindist, rep1–3 lines. |
| `revision_plot_summary_table.py` | Windowed metrics → CSV / optional smoke table figure. |
| `merge_xvg_for_sham.py` | Merge `.xvg` on common time stamps; `--plain` for minimal columns. |
| `prepare_fel_gsham_input.sh` | Thin wrapper: calls merge → `gsham_input_rg_rmsdBB_plain.xvg`. |
| `revision_xvg_io.py` | Shared `.xvg` parsing and window masks. |
| `revision_figure_export.py` | `save_figure(..., fig_format='tif', dpi=300)` with `pil_kwargs` LZW. |

**Examples**

```bash
python revision_plot_dimer_timeseries.py --help
python revision_plot_monomer_boxplot.py --help
python revision_plot_monomer_timeseries.py --help
# Typical outputs: use extension .tif and --dpi 300 (defaults)
```

## Lightweight: contact-defined pocket residue list (monomers)

To sanity-check that CPP stays near the pocket and that the selected residues are reasonable, run:

```bash
cd revision_exec/analysis_revision
bash make_contact_pocket_rmsf_monomers.sh
```

Per monomer system this writes:
- `raw_xvg/<sid>/contact_pocket_residues_last50ns.txt`
- `raw_xvg/<sid>/rmsf_contact_pocket_last50ns.xvg`

## FEL / Gibbs landscape (external)

The vendored copy under `revision_exec/analysis/external/gromacs-gibbs-pipeline/scripts/plot_gibbs_landscape.py` accepts `--format tif` / `tiff` and writes **TIFF LZW** the same way as the top-level `gromacs-gibbs-pipeline` repo script.

## Outputs you should not commit

See repo root `.gitignore`: `raw_xvg/`, `work/`, `figures/`, `tables/`, `_smoke/`. Regenerate from scripts after clone.

## Related docs

- `docs/HUGGINGFACE_DATASET.md` — Hub uploads and checksum manifests.
- `revision_exec/logs/HF_AND_PIPELINE_LOG_INDEX.md` — index of upload and MD run logs.
