# Protenix Structure Predictions

AI-assisted protein-ligand complex predictions generated using **Protenix** (ByteDance).
These predictions underlie Figures 2, 7, Table 1, and Supplementary Figures S2-S4 in the manuscript.

## CPPF Predictions (5IJ0 Template)

Predicted binding poses of CPPF with tubulin systems using the 5IJ0 (human alpha1B/TUBB3 heterodimer, beta-GDP state) template.

### `cppf_ab_tubulin_dimer/`
- **Target:** alpha/beta-tubulin heterodimer + CPPF
- **Job ID:** `protenix_job_6b6c2e66`
- **Samples:** 5 raw CIF outputs (sample_0 to sample_4)
- **Curated poses:** 4 PDB files (pose 0-3), exported and annotated in PyMOL
  - **Pose 1** (`AlphaFold3_abTub_CPPF_pose1_V236_ptm0.96802771091.pdb`): selected for MD simulations (Table 1, main text)
  - Key residue: VAL236 on beta-tubulin (H-bond at 2.9 A)
- **Visualizations:** PNG snapshots + PSE (PyMOL session) files per pose
- **Manuscript:** Fig. 2A, Table 1 (dimer rows)

### `cppf_alpha_tubulin/`
- **Target:** alpha-tubulin monomer (TUBA1B) + CPPF
- **Job ID:** `protenix_job_4b907ebe` (seed 12330)
- **Samples:** 5 raw CIF outputs (sample_0 to sample_4)
- **Curated poses:** 6 PDB files — pose 0-3, plus zoomed-in ASN257 contact views for pose 0 and pose 1 (`*_Asn257.pdb`)
  - Key residue: ASN257 (H-bond at ~3.0 A)
- **Manuscript:** Fig. 2B, Table 1 (alpha monomer rows)

### `cppf_beta_tubulin/`
- **Target:** beta-tubulin monomer (TUBB3) + CPPF
- **Job ID:** `protenix_job_6e06530a`
- **Samples:** 5 raw CIF outputs (sample_0 to sample_4)
- **Confidence JSONs:** 5 files (confidence_sample_0 to _4, renamed from 8.3 short filenames)
- **Curated poses:** 3 PDB files (pose 0-2)
  - Key residues: TYR200, GLU198, LEU253, VAL236
- **Manuscript:** Fig. 2D, Table 1 (beta monomer rows), Supplementary Fig. S3

## Nocodazole Benchmark Predictions

Nocodazole predictions used as positive controls to validate the Protenix modeling pipeline
(Supplementary Fig. S2). Nocodazole is a well-characterized microtubule-destabilizing agent
with an experimentally determined crystal structure binding mode (PDB: 5CA1).

### `nocodazole_ab_tubulin_dimer/`
- **Target:** alpha/beta-tubulin heterodimer + nocodazole
- **Samples:** 5 raw CIF outputs
- **Exported PDB:** 2 curated poses, in `exported_pdb/` (`pose_0.pdb`, `pose_1.pdb`)
- **Visualizations:** 4 PNG + 3 PSE files (`pose_3.pse` was not generated; `pose_3.png` is present)
- **Confidence JSONs:** 5 files

### `nocodazole_alpha_tubulin/`
- **Target:** alpha-tubulin monomer (TUBA1B) + nocodazole
- **Samples:** 5 raw CIF outputs
- **Exported PDB:** 2 curated poses, in `exported_pdb/` (`pose_0.pdb`, `pose_1.pdb`)
- **Visualizations:** 2 PNG + 3 PSE files
- **Confidence JSONs:** 5 files

### `nocodazole_beta_tubulin/`
- **Target:** beta-tubulin monomer (TUBB3) + nocodazole
- **Samples:** 5 raw CIF outputs
- **Exported PDB:** 3 curated poses, in `exported_pdb/` (`pose_0.pdb`, `pose_1.pdb`, `pose_2.pdb`)
- **Visualizations:** 2 PNG + 3 PSE files
- **Confidence JSONs:** 5 files

## Supplementary Files

| File | Description |
|------|-------------|
| `protenix_confidence_data.xlsx` | Compiled confidence scores (pTM, ipTM, RMSD) across all predictions |
| `nocodazole_conformer_3d.json` | Nocodazole 3D conformer (PubChem CID 4122) |
| `pymol_alignment_script.txt` | PyMOL script for structural alignment of predictions to PDB references |
| `pymol_data.docx` | PyMOL visualization parameters and session notes |

## Notes

- Raw CIF files are direct Protenix outputs in mmCIF format
- PDB files were exported from CIF via PyMOL with residue-level annotations in filenames
- Nocodazole subdirectory filenames were converted from Windows 8.3 short names (original long names unavailable); files are numbered sequentially by filesystem order
- The 6E7B (beta-GMPCPP state) Protenix predictions are stored separately in `revision_exec_6e7b/input/protenix_predictions/` as they are part of the supplementary MD workflow
- Confidence JSON files contain pLDDT, pTM, ipTM, and chain-level metrics from Protenix output
