# Chai-1 Predictions

Protein-ligand complex predictions generated using **Chai-1** [Chai Discovery, 2024] for six targets: CPPF and nocodazole (benchmark), each against the α/β-heterodimer, α-tubulin monomer, and β-tubulin monomer.

Chai-1 was evaluated alongside the other AI-assisted platforms (Protenix, RFAA, Umol) during initial method screening, but was **not used as primary evidence**: predicted pose geometries were notably less stable than Protenix/RFAA. See main-text Methods for the full comparison.

These outputs are retained here for provenance and transparency, consistent with the study's data-deposition policy — not as a claim of methodological equivalence to the platforms used for primary analysis.

## Contents

Each target directory (`cppf_{ab_tubulin_dimer,alpha_tubulin,beta_tubulin}/`, `nocodazole_{ab_tubulin_dimer,alpha_tubulin,beta_tubulin}/`) contains 5 ranked poses (rank_0–rank_4): predicted structures (`pred.rank_*.cif`), predicted aligned error matrices (`pae.rank_*.npy`), confidence scores (`scores.rank_*.json`), and PyMOL visualizations (`*.png`, `*.pse`).

## Manuscript Reference

Main text: Chai-1 predictions were "notably less stable" compared to Protenix and RFAA — see Supplementary Fig. S4 for the all-platform structural alignment comparison.
