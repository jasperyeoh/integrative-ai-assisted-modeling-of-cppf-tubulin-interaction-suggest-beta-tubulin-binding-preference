# RoseTTAFold All-Atom (RFAA) Predictions

Protein-ligand complex predictions generated using **RoseTTAFold All-Atom (RFAA)** [Krishna et al., Science 2024].

RFAA extends the RoseTTAFold framework to predict three-dimensional protein-ligand complex
conformations from amino acid sequence and ligand chemical structure.

## CPPF Predictions

| File | Target | Description |
|------|--------|-------------|
| `cppf_ab_tubulin_dimer.pdb` | α/β-tubulin dimer + CPPF | Heterodimer complex prediction |
| `cppf_alpha_tubulin.pdb` | α-tubulin (TUBA1B) + CPPF | Monomer prediction (Fig. 2C) |
| `cppf_beta_tubulin.pdb` | β-tubulin (TUBB3) + CPPF | Monomer prediction (Fig. 2E) |

## Nocodazole Benchmark

| File | Target | Description |
|------|--------|-------------|
| `nocodazole_alpha_tubulin.pdb` | α-tubulin + nocodazole | Benchmark control |
| `nocodazole_beta_tubulin.pdb` | β-tubulin + nocodazole | Benchmark control |

## Auxiliary Files

Each PDB has a corresponding `_aux.pt` file containing RFAA model auxiliary outputs
(confidence metrics and internal representations in PyTorch format).

## Manuscript References

- **Fig. 2C, 2E:** RFAA-predicted CPPF binding poses for α- and β-tubulin monomers
- **Table 2:** PDBePISA interface analysis was performed on RFAA-predicted complexes
- **Supplementary Fig. S4:** Structural alignment comparison across all platforms
