# Umol Predictions

Protein-ligand complex predictions generated using **Umol** [Bryant et al., Nat Commun 2024].

Umol is a deep-learning method for predicting protein-ligand complex structures from
protein sequence and ligand SMILES, using MSA features for improved accuracy.

## Prediction Targets

### `tubb3_cppf/`
- **Target:** β-tubulin monomer (TUBB3) + CPPF
- **Key files:**
  - `Umol.ipynb` — Colab notebook used for prediction
  - `tubb3.fasta` — Input protein sequence
  - `tubb3.a3m` — Multiple sequence alignment
  - `tubb3_pred_raw.pdb` — Raw predicted structure
  - `ligand_plddt.csv` — Ligand confidence scores
- **Manuscript:** Supplementary Fig. S3A (shows a comparable predicted β-tubulin binding mode)

### `tuba1b_cppf/`
- **Target:** α-tubulin monomer (TUBA1B) + CPPF
- **Key files:**
  - `Umol_tuba1b.ipynb` — Colab notebook
  - `tuba1b.fasta` — Input protein sequence
  - `tuba1b.a3m` / `tuba1b_processed.a3m` — MSA files
  - `tub_alpha_1b.pdb` — Reference structure
  - `tuba1b_esmfold.pdb` — ESMFold-predicted template
- **Note:** Umol model weight files (params40000.npy, params60000.npy, ~354MB each) are
  excluded from this repository due to size. They can be downloaded from the Umol repository.

### `ab_tubulin_dimer/`
- **Target:** α/β-tubulin heterodimer + CPPF
- **Key files:**
  - `Umol_tub.ipynb` — Colab notebook
  - `5ij0_entry.fasta` / `rcsb_pdb_5IJ0.fasta` — Input sequences
  - `alpha_beta_only.pdb` — Dimer structure (protein chains only)

### `refined_figures/`
- Refined PyMOL visualization of Umol β-tubulin prediction
  - `tub_cppf_refine_v1.png` — Publication-quality figure
  - `tub_cppf_refined.pse` — PyMOL session

## Manuscript References

- **Supplementary Fig. S3A:** Umol-predicted CPPF binding on β-tubulin, showing a
  VAL236-centered pose comparable to the Protenix and RFAA predictions
- **Main text:** "Umol independently predicted a comparable CPPF binding mode on the
  β-tubulin monomer, centering around residue VAL236"
