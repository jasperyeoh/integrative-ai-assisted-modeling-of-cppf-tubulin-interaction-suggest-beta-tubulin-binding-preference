# 6E7B Supplementary MD — β-GMPCPP State Control

Supplementary molecular dynamics simulation of CPPF bound to the α1B/TUBB3 heterodimer
using the **6E7B template (β-GMPCPP / microtubule-lattice-related conformation)**, as a
control for the main-text 5IJ0 simulations (β-GDP / soluble curved state).

**Purpose:** Address Reviewer Comment 4.2 — validate whether CPPF binding mode depends
on β-tubulin nucleotide state.

## Template Comparison

| Property              | 5IJ0 (main text)       | 6E7B (this supplement) |
|-----------------------|------------------------|------------------------|
| Biological state      | Soluble curved dimer   | Microtubule lattice    |
| α-chain nucleotide    | GTP                    | GTP                    |
| β-chain nucleotide    | GDP                    | **G2P (GMPCPP analog)**|
| Mg²⁺                 | 2 sites                | 2 sites                |
| Sequence              | TUBA1B / TUBB3         | TUBA1B / TUBB3         |

## Protenix Prediction

- **Model:** protenix_base_20250630_v1.0.0
- **Date:** 2026-05-26
- **Operator:** Project Operator (operator@example.invalid)
- **Config:** `input/protenix_prediction_config.json`
- **Template/MSA:** enabled
- **Seed:** 82770
- **Samples:** 5

### Input Components

| # | Type           | Identity                                       |
|---|----------------|------------------------------------------------|
| 1 | Protein chain  | α-tubulin (TUBA1B), same as 5IJ0 main text    |
| 2 | Protein chain  | β-tubulin (TUBB3), same as 5IJ0 main text     |
| 3 | Ligand × 2     | CCD_MG (Magnesium ions)                        |
| 4 | Ligand × 1     | CCD_G2P (GMPCPP, β-chain nucleotide)          |
| 5 | Ligand × 1     | CCD_GTP (α-chain nucleotide)                   |
| 6 | Ligand × 1     | CPPF (SMILES: ClC1=CC(=CC=C1)C1=CC=C(O1)C(=O)NC1=CN=CC=C1) |

### Confidence Scores (All 5 Samples)

| Sample   | pLDDT | pTM    | ipTM   | Ranking Score |
|----------|-------|--------|--------|---------------|
| sample_0 | 94.81 | 0.9584 | 0.9451 | **0.9478**    |
| sample_1 | 94.81 | 0.9580 | 0.9446 | 0.9473        |
| sample_2 | 94.81 | 0.9579 | 0.9444 | 0.9471        |
| sample_3 | 94.58 | 0.9541 | 0.9385 | 0.9416        |
| sample_4 | 94.58 | 0.9540 | 0.9384 | 0.9415        |

All samples show excellent confidence (pLDDT > 94, ipTM > 0.93).
**sample_0** has the highest ranking score and will be used for MD.

## Completed MD Simulation

- **Starting pose:** Protenix sample_0 (rank 1, highest confidence)
- **Alignment:** Cα RMSD **1.82 Å** to 6E7B template (`prep/alignment_summary.txt`)
- **Force field:** AMBER99SB-ILDN (protein) + GAFF2/RESP2 (CPPF, reused from 5IJ0)
- **Protocol:** **Cofactor-free** protein+ligand (same as main-text 5IJ0 for direct comparability)
- **Replicates:** **3 × 200 ns** (complete)
- **Analysis:** RMSD, min-distance, Rg, H-bond, FEL, MM-PBSA-GB (last 50 ns)

### Results Summary (last 50 ns, 3 reps)

| Metric | 6E7B (this work) | 5IJ0 (main text) | Verdict |
|--------|-------------------|-------------------|---------|
| Backbone RMSD | 0.295 ± 0.026 nm | 0.30 / 0.55 / 0.65 nm (per-rep) | 6E7B comparable-to-better |
| min(CPPF–protein) | 0.203 ± 0.014 nm | 0.14–0.24 nm | Within 5IJ0 range |
| FEL global minimum | RMSD 0.27 nm, Rg 2.99 nm | RMSD 0.43 nm, Rg 2.19 nm (β) | Comparable basin localization |
| **MM-PBSA-GB ΔG** | **−27.82 ± 5.44 kcal/mol** | **−31.19 ± 4.04 kcal/mol** | **1σ intervals overlap — statistically indistinguishable** |

**Conclusion: CPPF binding is STABLE and energetically equivalent in the 6E7B (β-GTP/microtubule-lattice) conformation relative to the 5IJ0 (β-GDP/soluble dimer) main-text simulations.** This directly addresses Reviewer Comment 4.2 with data rather than deferring to future work.

## Data deposition

| Asset | Location |
|-------|----------|
| Production `.xtc` (3 reps) | [Hugging Face dataset](https://huggingface.co/datasets/HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers) — `6e7b_rep{1,2,3}_md_200ns.xtc` |
| Production `.tpr`, last-50ns XTC, PBC-corrected trajectories, analysis bundle | Same HF dataset — see `revision_exec_6e7b/REPRODUCIBILITY.md` |
| SHA256 checksums (all uploaded files) | `revision_exec_6e7b/HF_UPLOAD_SHA256SUMS_6e7b.txt` (27 entries, verified complete) |
| Scripts, topology, plots, XVG, publication figures | This Git repo under `revision_exec_6e7b/` |

Upload trajectories: `bash revision_exec/scripts/huggingface_upload_6e7b_trajectories.sh --all --update-readme`  
Upload reproducibility bundle: `bash revision_exec/scripts/huggingface_upload_6e7b_reproducibility.sh --all`

**Full reproduce-from-scratch instructions:** see [`REPRODUCIBILITY.md`](REPRODUCIBILITY.md) — clone the repo, download the paired `.xtc`/`.tpr` files from Hugging Face, then run `bash analysis/run_full_analysis.sh` followed by `bash analysis/mmpbsa/recover_and_run_mmpbsa.sh` and `bash analysis/figures/make_6e7b_figures.sh` to regenerate every number and figure in this README from the raw trajectories.

## Directory Structure

```
revision_exec_6e7b/
├── README.md                          ← this file
├── REPRODUCIBILITY.md                 ← clone-and-rerun checklist (Git + Hugging Face)
├── METHODS_6E7B_DRAFT.md              ← standalone Methods draft (fully integrated into main.tex)
├── HF_UPLOAD_SHA256SUMS_6e7b.txt      ← checksums for all 6E7B files on Hugging Face
├── input/
│   ├── 6E7B.pdb                       ← PDB template
│   ├── protenix_prediction_config.json ← Protenix run configuration
│   └── protenix_predictions/
│       └── predictions/
│           ├── *_sample_0.cif         ← 5 predicted structures (mmCIF)
│           ├── *_sample_1.cif … *_sample_4.cif
│           ├── *_summary_confidence_sample_*.json  ← confidence scores
│           └── 6E7B_pose0.pse         ← PyMOL session (pose 0 visualization)
├── prep/                              ← topology, MDP files, alignment log (in git)
├── md/                                ← production runs (on disk + HF; large .xtc gitignored)
│   ├── rep1/  ├── rep2/  └── rep3/
├── scripts/                           ← system prep + MD pipeline scripts
└── analysis/                          ← summary.md, plots, XVG, FEL (in git + HF)
    ├── mmpbsa/                        ← MM-PBSA-GB scripts + 6e7b_mmpbsa_summary.csv
    └── figures/                       ← publication-quality TIFFs (reuse main-text plot code)
        ├── fig_S_6e7b_timeseries_panels.tif   → Supp Fig S7
        ├── fig_S_6e7b_fel_2d.tif               → Supp Fig S8
        └── fig_S_6e7b_mmpbsa_bar.tif           → Supp Fig S9
```

## Manuscript Integration (complete)

- **Abstract / Author Summary:** brief mention that binding is preserved across the two β-tubulin conformational states.
- **Introduction:** contribution (3) references the 6E7B cross-conformational-state result.
- **Methods:** dedicated subsection "Supplementary 6E7B Simulations (GTP-bound β-tubulin conformational state)" — full protocol, Kabsch alignment, MD, and MM-PBSA settings.
- **Results:** dedicated subsection "CPPF Binding Stability in the 6E7B (GTP-bound β-tubulin) Conformational State" — all quantitative results (RMSD, min-dist, FEL, MM-PBSA).
- **Discussion:** opening paragraph updated; new mechanistic paragraph contrasting CPPF's cross-conformational-state accessibility with stage-restricted binders (paclitaxel, colchicine); limitations paragraph narrowed to the remaining GMPCPP-explicit-parameterization refinement.
- **Supplementary Figures:** S7 (MD time series), S8 (2D FEL), S9 (MM-PBSA comparison bar chart).
- **Supplementary Table:** S4 (per-replicate window statistics, machine-readable CSV).
- **Response to Reviewers:** Comment 4.2 fully rewritten with the biochemical rationale, protocol, and results above; Comment 1.1 cofactor claim corrected; Comment 3.5 updated to report the completed cross-conformational-state test instead of describing it as future work.
