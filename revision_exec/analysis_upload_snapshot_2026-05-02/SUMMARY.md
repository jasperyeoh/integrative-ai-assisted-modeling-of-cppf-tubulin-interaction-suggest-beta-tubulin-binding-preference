# Quick stability snapshot (2026-05-02)

## Dimer rep2 — 300–350 ns (`md_350ns.part0003.xtc`)

### Backbone RMSD (nm)

- 300–325 ns: mean=4.2964, std=0.1055, n=2500
- 325–350 ns: mean=2.5523, std=2.0939, n=2500
- slope(300–350 ns): **-0.045315** / ns

### Ligand RMSD vs backbone fit (nm)

- 300–325 ns: mean=8.3618, std=4.8580, n=2500
- 325–350 ns: mean=10.5200, std=4.3368, n=2500
- slope(300–350 ns): **0.071048** / ns

### Protein Rg (nm)

- 300–325 ns: mean=5.3565, std=0.1597, n=2501
- 325–350 ns: mean=4.4407, std=1.4817, n=2501
- slope(300–350 ns): **-0.021014** / ns

### Protein–ligand min dist (nm)

- 300–325 ns: mean=0.2070, std=0.0126, n=2501
- 325–350 ns: mean=0.2126, std=0.0103, n=2501
- slope(300–350 ns): **0.000245** / ns

### Contacts <0.35 nm (count)

- 300–325 ns: mean=144.2823, std=13.0556, n=2501
- 325–350 ns: mean=142.3291, std=12.8279, n=2501
- slope(300–350 ns): **-0.131571** / ns

## Monomer β rep3 — 150–200 ns (late window, `md_200ns.xtc`)

### Backbone RMSD (nm)

- 150–175 ns: mean=0.4070, std=0.0223, n=2500
- 175–200 ns: mean=0.4144, std=0.0194, n=2500
- slope(150–200 ns): **0.000130** / ns

### Ligand RMSD (MOL) vs backbone fit (nm)

- 150–175 ns: mean=1.4869, std=2.8637, n=2500
- 175–200 ns: mean=8.2921, std=3.9162, n=2500
- slope(150–200 ns): **0.191711** / ns

### Protein–MOL min dist (nm)

- 150–175 ns: mean=0.2110, std=0.0097, n=2501
- 175–200 ns: mean=0.2117, std=0.0097, n=2501
- slope(150–200 ns): **0.000013** / ns

### Contacts <0.35 nm (count)

- 150–175 ns: mean=162.2331, std=14.9797, n=2501
- 175–200 ns: mean=158.1064, std=15.4813, n=2501
- slope(150–200 ns): **-0.176023** / ns

## Still running (do not upload partial XTC yet)

- `dimer rep3` 300→350 ns: in progress

- `dimer rep1` 350→400 ns: in progress


## Hugging Face

- Uploaded / uploading: `dimer_rep2_md_350ns.part0003.xtc` (new)

- `monomer_beta_rep3_md_200ns.xtc` was handled by the incremental uploader (flag file present)

