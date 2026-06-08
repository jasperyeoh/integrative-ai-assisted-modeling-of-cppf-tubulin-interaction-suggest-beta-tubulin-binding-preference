# Chai-1 Predictions

Protein-ligand complex predictions generated using **Chai-1** [Chai Discovery, 2024].

Chai-1 is a multi-modal foundation model for molecular structure prediction. In this study,
Chai-1 predictions were compared against Protenix and RFAA but showed notably less stable
pose geometries (see main text).

## CPPF Predictions

### `cppf_ab_tubulin_dimer/`
- **Target:** α/β-tubulin heterodimer + CPPF
- **Ranks:** 5 predicted poses (rank_0 to rank_4)
- **Files:** CIF structures, PAE (predicted aligned error) matrices (.npy), score JSONs, PyMOL visualizations

### `cppf_alpha_tubulin/`
- **Target:** α-tubulin monomer (TUBA1B) + CPPF
- **Ranks:** 5 predicted poses

### `cppf_beta_tubulin/`
- **Target:** β-tubulin monomer (TUBB3) + CPPF
- **Ranks:** 5 predicted poses

## Nocodazole Benchmark

### `nocodazole_ab_tubulin_dimer/`
- **Target:** α/β-tubulin heterodimer + nocodazole
- **Ranks:** 5 predicted poses

### `nocodazole_alpha_tubulin/`
- **Target:** α-tubulin monomer + nocodazole
- **Ranks:** 5 predicted poses

### `nocodazole_beta_tubulin/`
- **Target:** β-tubulin monomer + nocodazole
- **Ranks:** 5 predicted poses

## File Types

| Extension | Description |
|-----------|-------------|
| `pred.rank_*.cif` | Predicted structures in mmCIF format |
| `pae.rank_*.npy` | Predicted aligned error matrices (NumPy) |
| `scores.rank_*.json` | Confidence scores per rank |
| `*.png` | PyMOL visualization snapshots with annotated residues |
| `*.pse` | PyMOL session files |

## Manuscript References

- Main text mentions Chai-1 predictions were "notably less stable" compared to Protenix and RFAA
- **Supplementary Fig. S4:** All-platform structural alignment comparison
