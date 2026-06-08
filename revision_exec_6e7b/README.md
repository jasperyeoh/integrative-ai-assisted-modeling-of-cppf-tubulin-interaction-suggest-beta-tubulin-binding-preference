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

## Planned MD Simulation

- **Starting pose:** Protenix sample_0 (rank 1, highest confidence)
- **Force field:** AMBER99SB-ILDN (protein) + GAFF2/RESP2 (CPPF, reused from 5IJ0)
- **Cofactors:** GTP (α) + G2P (β) + Mg²⁺ × 2, from 6E7B template
- **Replicates:** 2 × 200 ns
- **Analysis:** RMSD, RMSF, binding pocket distances, H-bond, PLIP, MM-PBSA
- **GPU:** RTX 4090 24GB (cloud, ~50-55 ns/day estimated)

## Directory Structure

```
revision_exec_6e7b/
├── README.md                          ← this file
├── input/
│   ├── 6E7B.pdb                       ← PDB template
│   ├── protenix_prediction_config.json ← Protenix run configuration
│   └── protenix_predictions/
│       └── predictions/
│           ├── *_sample_0.cif         ← 5 predicted structures (mmCIF)
│           ├── *_sample_1.cif
│           ├── *_sample_2.cif
│           ├── *_sample_3.cif
│           ├── *_sample_4.cif
│           ├── *_summary_confidence_sample_*.json  ← confidence scores
│           └── 6E7B_pose0.pse         ← PyMOL session (pose 0 visualization)
├── prep/                              ← (to be created) topology & solvation
├── md/                                ← (to be created) production runs
│   ├── rep1/
│   └── rep2/
└── analysis/                          ← (to be created) post-MD analysis
```

## Manuscript Integration

- **Supplementary Figures:** S5/S6 (trajectory stability + 5IJ0 vs 6E7B binding comparison)
- **Methods:** additional paragraph on 6E7B supplementary MD
- **Discussion:** upgrade 6E7B from "future work" to "supplementary evidence"
- **Response to Reviewers:** rewrite Comment 4.2 response with MD results
