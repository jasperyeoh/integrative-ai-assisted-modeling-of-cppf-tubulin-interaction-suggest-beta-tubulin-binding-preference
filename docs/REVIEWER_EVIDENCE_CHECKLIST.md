# Reviewer → evidence checklist (revision MD)

This file maps common reviewer requests to the **exact, reproducible** artifacts generated in this repo (scripts + outputs). It is meant to be used as a final pre-submission sanity checklist.

## A. Replicates / statistical support

- **Reviewer concern**: “Where are the independent replicates? Please show replicate consistency and between-replicate spread.”
- **What we did**: Ran/analyzed **three independent replicates** and summarize results as replicate traces + aggregate summaries.
- **Evidence (scripts)**:
  - `revision_exec/analysis_revision/run_export_all.sh` (bulk GROMACS exports for all 9 systems)
  - `revision_exec/analysis_revision/revision_plot_dimer_timeseries.py` (replicate-aware dimer traces)
  - `revision_exec/analysis_revision/revision_plot_monomer_boxplot.py` (replicate-aware monomer α vs β boxplots)
  - `revision_exec/analysis_revision/revision_plot_summary_table.py` (windowed summary table)
- **Evidence (outputs)**:
  - `revision_exec/analysis_revision/figures/dimer_rep123_panels_0-400ns.tif`
  - `revision_exec/analysis_revision/figures/monomer_alpha_vs_beta_last50ns_boxplots.tif`
  - `revision_exec/analysis_revision/tables/summary_by_window.csv`
  - Exported per-system `.xvg` time series under `revision_exec/analysis_revision/raw_xvg/<system_id>/`

## B. Timescale / “longer MD”

- **Reviewer concern**: “Please extend sampling / show late-stage stability.”
- **What we did**:
  - Dimers: plots summarize **0–400 ns** across rep1–rep3 (as exported by the Step-2 pipeline).
  - Monomers: boxplots focus on the **last 50 ns window** (late-stage stability comparison α vs β).
- **Evidence (outputs)**:
  - `revision_exec/analysis_revision/figures/dimer_rep123_panels_0-400ns.tif`
  - `revision_exec/analysis_revision/figures/monomer_alpha_vs_beta_last50ns_boxplots.tif`
  - Underlying `.xvg`: `revision_exec/analysis_revision/raw_xvg/**/rmsd_backbone.xvg`, `rg.xvg`, `mindist_pl.xvg`, `hbond_num.xvg`

## C. “Interaction-level metrics” (Rg / mindist / H-bonds / RMSD)

- **Reviewer concern**: “Do you have interaction-level evidence beyond one metric? Also: avoid missing/duplicated panels.”
- **What we did**: Exported and plotted **RMSD(backbone)**, **Rg**, **minimum distance**, **H-bond count** consistently across replicates/systems.
- **Evidence (script)**:
  - `revision_exec/analysis_revision/run_export_all.sh` (generates the `.xvg` series)
- **Evidence (outputs)**:
  - `revision_exec/analysis_revision/figures/dimer_rep123_panels_0-400ns.tif` (2×2 panels)
  - `revision_exec/analysis_revision/raw_xvg/<system_id>/{rmsd_backbone.xvg,rg.xvg,mindist_pl.xvg,hbond_num.xvg}`

## D. Free energy landscape (FEL) with shared scale (main) + per-replicate consistency (supp)

- **Reviewer concern**: “Show a FEL with a **shared color scale** and demonstrate replicate consistency.”
- **What we did**:
  - Main: built FEL for **combined trajectory** per state (α combined | β combined) with a **shared z-cap** of **5 kcal/mol**.
  - Supplement: generated **per-replicate** FELs (rep1–rep3) for α and β, also with z-cap 5 kcal/mol.
- **Evidence (inputs)**:
  - `revision_exec/analysis_revision/raw_xvg/<system_id>/gsham_input_rg_rmsdBB_plain.xvg`
  - `revision_exec/analysis_revision/fel/combined/{alpha,beta}/gsham_input_rg_rmsdBB_plain.xvg`
- **Evidence (main figure outputs)**:
  - `revision_exec/analysis_revision/figures/fel_combined_alpha_beta_zcap5.tif` (α | β, shared z-cap)
  - (also available as single panels)
    - `revision_exec/analysis_revision/figures/fel_combined_alpha_zcap5.tif`
    - `revision_exec/analysis_revision/figures/fel_combined_beta_zcap5.tif`
- **Evidence (supp figure outputs, per replicate)**:
  - `revision_exec/analysis_revision/fel/monomer_alpha_rep{1,2,3}/gibbs_rg_rmsd_monomer_alpha_rep*_zcap5.tif`
  - `revision_exec/analysis_revision/fel/monomer_beta_rep{1,2,3}/gibbs_rg_rmsd_monomer_beta_rep*_zcap5.tif`
- **How generated (external, vendored)**:
  - `revision_exec/analysis/external/gromacs-gibbs-pipeline/scripts/xpm2txt.py`
  - `revision_exec/analysis/external/gromacs-gibbs-pipeline/scripts/plot_gibbs_landscape.py` (exports **TIFF LZW**, 300 dpi; `--energy-unit kcal_mol`)

## E. Binding energetics (MM-PBSA/GB) with replicate summary

- **Reviewer concern**: “Provide binding energetics; address the ‘binding too weak’ criticism with quantitative data.”
- **What we did**:
  - Ran **gmx_MMPBSA (GB)** on the **350–400 ns** segment for **rep1–rep3**, subsampling to ~**51 frames** (≈ 1 ns spacing).
  - Summarized **ΔVDW, ΔEEL, ΔEGB, ΔESURF, ΔTOTAL** (mean ± SD) per replicate and aggregated ΔTOTAL across replicates.
- **Evidence (outputs)**:
  - `revision_exec/analysis/mmpbsa/mmpbsa_summary.csv`
  - Per-replicate workdirs:
    - `revision_exec/analysis/mmpbsa/work_dimer_rep1_last50ns_full/`
    - `revision_exec/analysis/mmpbsa/work_dimer_rep2_last50ns_full/`
    - `revision_exec/analysis/mmpbsa/work_dimer_rep3_last50ns_full/`
  - Final results files inside the workdirs (e.g. `FINAL_RESULTS.dat`)
- **Evidence (scripts/inputs)**:
  - `revision_exec/analysis/mmpbsa/run_dimer_rep1_last50ns_mmpbsa.sh` (parameterized by `REP=rep{1,2,3}`)
  - `revision_exec/analysis/mmpbsa/mmpbsa_dimer_rep1_last50ns_gb.in` (GB input template; `interval=100`)
  - `revision_exec/analysis/mmpbsa/summarize_mmpbsa_gb_last50ns.py` (parses `FINAL_RESULTS.dat` → CSV)
- **Known issue documented**:
  - Bond-term overflow in `sander` output (`BOND = *************`) is handled as NaN for parsing and explicitly documented as not affecting ΔTOTAL.
  - See `tubulin-cppf-md/docs/RUNBOOK.md` and `revision_exec/analysis/mmpbsa/README.md`.

## F. Reproducibility (GitHub + Hugging Face)

- **Reviewer concern**: “Can someone reproduce the analysis from your shared code/data?”
- **What we did**: Documented the end-to-end pipeline (inputs → exports → plots/tables) and dataset naming conventions.
- **Evidence (docs)**:
  - `tubulin-cppf-md/docs/RUNBOOK.md`
  - `tubulin-cppf-md/docs/HUGGINGFACE_DATASET.md`
  - `tubulin-cppf-md/docs/DIMER_TRAJECTORY_NAMING.md`
  - `revision_exec/logs/HF_AND_PIPELINE_LOG_INDEX.md`

