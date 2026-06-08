# SwissDock Predictions

Molecular docking results generated using **SwissDock** [Grosdidier et al., NAR 2011].

SwissDock is a web-based docking server that uses the EADock DSS engine. In this study,
SwissDock yielded high RMSD values relative to crystallographic references, indicating
less stable predictions compared to AI-based methods (Protenix, RFAA).

## Docking Targets

### `tub_dimer_cppf/`
- **Target:** α/β-tubulin heterodimer + CPPF
- **Key files:**
  - `parameters` — SwissDock run parameters
  - `result.dock4` — Raw docking output (all poses)
  - `receptor.pdb` — Input receptor structure
  - `pose1_cluster0.pdb` — Top-ranked pose
  - `dimer_pose_data.csv` — Parsed pose metrics
  - `extracted_pdb/` — Individual pose PDB files
  - `pose_analysis.ipynb` — Jupyter analysis notebook
  - `optimized_plot.png` — Pose energy visualization
  - `files/` — Input ligand/receptor mol2 files

### `tuba1b_cppf/`
- **Target:** α-tubulin monomer (TUBA1B) + CPPF
- **Run date:** Dec 27, 2024
- **Key files:**
  - `parameters` — SwissDock run parameters
  - `result.dock4` — Raw docking output
  - `atub_pose_data.csv` — Parsed pose metrics
  - `extracted_pdb/` — Individual pose PDB files
  - `files/` — Input ligand/receptor mol2 files

### `tubb3_cppf/`
- **Target:** β-tubulin monomer (TUBB3) + CPPF
- **Key files:**
  - `parameters` — SwissDock run parameters
  - `result.dock4` — Raw docking output
  - `btub_pose_data.csv` — Parsed pose metrics
  - `extracted_pdb/` — Individual pose PDB files
  - `files/` — Input ligand/receptor mol2 files

## Analysis Scripts

- `extract_pdb_swissdock.py` — Extracts individual poses from dock4 output
- `info_docking.py` — Parses and summarizes docking metrics

## Manuscript References

- Main text: "predictions from SwissDock and Chai-1 were notably less stable; SwissDock in
  particular yielded high root-mean-square deviation (RMSD) values relative to crystallographic references"
- **Supplementary Fig. S4:** All-platform structural alignment comparison
