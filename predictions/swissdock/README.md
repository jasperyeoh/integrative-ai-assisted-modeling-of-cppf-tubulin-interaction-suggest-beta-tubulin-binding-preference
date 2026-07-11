# SwissDock Predictions

Molecular docking results generated using **SwissDock** [Grosdidier et al., NAR 2011] for three CPPF-tubulin targets (α/β-heterodimer, α-tubulin monomer, β-tubulin monomer).

SwissDock was evaluated alongside the AI-assisted platforms (Protenix, RFAA, Umol) as part of the initial method screening described in the manuscript, but was **not used as primary evidence**: predicted poses showed high RMSD relative to crystallographic references, and the heterodimer target exceeds SwissDock's practical receptor-size limits for stable docking. See main-text Methods and Response to Reviewers (Comment 3.3) for the full exclusion rationale.

These outputs are retained here for provenance and transparency, consistent with the study's data-deposition policy — not as a claim of methodological equivalence to the AI-assisted platforms.

## Contents

Each target directory (`tub_dimer_cppf/`, `tuba1b_cppf/`, `tubb3_cppf/`) follows the same layout: raw SwissDock output (`parameters`, `result.dock4`), per-pose extracted PDB files (`extracted_pdb/`), a parsed pose-metrics CSV, and the input receptor/ligand files (`files/`). `extract_pdb_swissdock.py` and `info_docking.py` (repo-level scripts) regenerate the extracted PDBs and metrics CSV from the raw `result.dock4` output.

## Manuscript Reference

Main text: "predictions from SwissDock and Chai-1 were notably less stable; SwissDock in particular yielded high root-mean-square deviation (RMSD) values relative to crystallographic references" — see Supplementary Fig. S4 for the all-platform structural alignment comparison.
