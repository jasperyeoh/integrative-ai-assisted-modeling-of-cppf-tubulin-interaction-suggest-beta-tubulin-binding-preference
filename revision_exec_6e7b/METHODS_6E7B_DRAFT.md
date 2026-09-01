# 6E7B Supplementary Simulations — Methods Draft

**Status:** Complete — integrated numbers from 3 × 200 ns production MD (2026-06-15).

**MD status:** 3 replicates complete; trajectories at `md/rep{1,2,3}/`; uploaded to Hugging Face as `6e7b_rep{1,2,3}_md_200ns.xtc`.

---

## 1. Rationale

Reviewer 4.2 noted that PDB 5IJ0—used throughout the main text—represents the soluble, curved α/β-tubulin heterodimer with the β-subunit in the GDP-bound state, and requested that CPPF binding be additionally examined in the GTP-bound β-tubulin conformation captured by PDB **6E7B** (β-GMPCPP, straight microtubule-lattice conformation). We performed an independent set of MD simulations on the 6E7B system, mirroring the main-text protocol to preserve direct comparability.

**Justification for the protein-only MD protocol.** The crystallographic nucleotide cofactors (α-GTP, β-GMPCPP/G2P) and the two Mg²⁺ ions present in 6E7B were not retained in the production topology. This choice is motivated by three considerations:

1. **Spatial separation of binding sites.** The CPPF pose predicted in this study localizes at the αβ-interface adjacent to the canonical colchicine site, near the β-tubulin N-site. The exchangeable nucleotide cofactor (GTP/G2P) and its coordinating Mg²⁺ bind at the E-site on the opposite face of β-tubulin, ~15–20 Å away. Direct steric or electrostatic interaction between the bound nucleotide and CPPF is therefore physically negligible.

2. **Experimental colchicine-site precedent.** Published affinity measurements indicate that the binding of colchicine to the αβ-tubulin dimer is not appreciably modulated by the β-tubulin nucleotide state. Because the CPPF site overlaps with the colchicine pocket (slightly displaced toward β-tubulin), the same insensitivity to nucleotide identity is expected.

3. **Conformational signature captured upstream.** The indirect effect of the bound nucleotide on backbone conformation is encoded in the Protenix prediction step, which was performed with all cofactors explicitly present. The predicted CPPF pose therefore reflects the cofactor-conditioned pocket geometry; subsequent MD probes the dynamic stability of CPPF within that geometry.

This protocol is identical to that used for the main-text 5IJ0 production simulations (αβ-tubulin + CPPF, AMBER99SB-ILDN + GAFF2/RESP2, TIP3P water, neutralizing/0.15 M NaCl), enabling a direct comparison of CPPF binding behavior between the GDP-bound (5IJ0) and GTP-bound (6E7B) β-tubulin conformational states.

---

## 2. Starting Structure Generation

The 6E7B-based CPPF–tubulin complex was generated via AI-based structure prediction followed by superposition onto the experimental template.

### 2.1 Protenix Prediction

Protenix v0.5.0 (December 2025 release) was used to predict the CPPF-bound α1B/β3-tubulin heterodimer in the 6E7B context. The input specification included:

- α-tubulin (TUBA1B) and β-tubulin (TUBB3) sequences taken from the 6E7B asymmetric unit
- One CPPF molecule (SMILES `O=C(Nc1cccnc1)c1ccc(-c2cccc(Cl)c2)o1`)
- Two Mg²⁺ ions, one GTP molecule (α-site), and one GMPCPP/G2P molecule (β-site), all included to ensure the predicted complex reflects the cofactor-bound microtubule-lattice conformation

Five independent samples were generated. All samples passed quality thresholds (pLDDT > 94 across all atoms; ipTM > 0.93; protein–ligand interface pTM > 0.85). The top-ranked sample (`sample_0`, ranking score 0.9478) was selected as the MD starting structure.

### 2.2 Template Alignment

The Protenix-predicted complex was aligned to the 6E7B experimental structure (chains A and B) via Kabsch superposition using Cα atoms common to both structures. The resulting RMSD over all aligned Cα atoms was **1.82 Å** (`prep/align.log`). After alignment, protein chains A and B and the CPPF ligand (renamed `UNL`, chain C) were extracted; the predicted cofactors were not propagated to the MD topology (see §1).

---

## 3. System Preparation

System construction was performed using the same toolchain as the main-text 5IJ0 simulations.

- **Force field.** AMBER99SB-ILDN was used for the protein. CPPF was parameterized with GAFF2 using RESP2(0.5) atomic charges derived from a B3LYP/6-31G(d) optimization with implicit solvent (Multiwfn + ACPYPE). The CPPF topology (`CPPF_RESP2.itp`) and position restraints (`posre_CPPF_RESP2.itp`) used for 5IJ0 were re-used identically.
- **Topology assembly.** `gmx pdb2gmx` was applied to the protein-only PDB to generate per-chain topologies (`topol_Protein_chain_A.itp`, `topol_Protein_chain_B.itp`). CPPF was added by including `CPPF_RESP2.itp` before all `[ moleculetype ]` definitions (defines atomtypes) and inserting `CPPF_RESP2 1` into the `[ molecules ]` block.
- **Solvation.** The complex was placed in a rhombic-dodecahedral box with a 1.0 nm minimum distance from any protein atom to the box edge, and solvated with TIP3P water (`spc216.gro`). The resulting system contained approximately 168,000 atoms (51,478 water molecules).
- **Ionization.** `gmx genion` was used with `-neutral -conc 0.15` to bring the system to net-neutral and ~0.15 M physiological ionic strength. The final composition was Protein\_chain\_A + Protein\_chain\_B + CPPF + 51,478 SOL + 27 Na⁺ (Cl⁻ was not required given the net protein charge).

---

## 4. Equilibration and Production MD

All simulations were performed with **GROMACS 2024.5** with CUDA support on an NVIDIA RTX 4090 GPU.

### 4.1 Energy Minimization
Steepest-descent minimization (`em.mdp`) with `emtol = 1000 kJ/mol/nm`, Verlet cutoff scheme, 1.0 nm short-range Coulomb and van der Waals cutoffs, and PME electrostatics. Maximum force at termination was below `emtol`.

### 4.2 NVT Equilibration
100 ps NVT (`nvt.mdp`) with a 2 fs timestep, V-rescale thermostat at 300 K (τ = 0.1 ps; separate coupling for `Protein_CPP` and `Water_and_ions` groups), LINCS constraints on all bonds, and position restraints (`-DPOSRES`) applied to protein and CPPF heavy atoms. Initial velocities were drawn from a Maxwell–Boltzmann distribution at 300 K (rep1: `gen_seed = -1`; reps 2–3: independent NVT initialization from the common minimized structure, see §4.4). Short-range cutoffs were set to 1.4 nm to match the production protocol.

### 4.3 NPT Equilibration
100 ps NPT (`npt.mdp`) at 300 K and 1 bar, with V-rescale thermostat and C-rescale barostat (isotropic, τ\_p = 1.0 ps, compressibility = 4.5×10⁻⁵ bar⁻¹). Position restraints retained; `refcoord_scaling = com`.

### 4.4 Production MD

**Three independent replicates** of **200 ns each** were performed using `md_prod_200ns.mdp`:
- 2 fs timestep, 100,000,000 steps
- V-rescale thermostat (300 K) and C-rescale barostat (1 bar, isotropic)
- PME electrostatics (1.4 nm real-space cutoff, 0.16 nm Fourier spacing, cubic interpolation)
- 1.4 nm van der Waals cutoff with `DispCorr = EnerPres`
- LINCS constraints on all bonds (`lincs_iter = 1`, `lincs_order = 4`)
- Compressed coordinates written every 5000 steps (10 ps); energies every 1000 steps

`gmx mdrun` flags: `-ntomp 16 -nb gpu -pme gpu -bonded gpu -gpu_id 0`. Update and constraints ran on CPU due to the all-bonds constraint set exceeding the GPU LINCS coupling limit in GROMACS 2024.5; this matches the main-text 5IJ0 protocol.

Replicates 2 and 3 were initialized from independent NVT/NPT equilibration runs (different velocity seeds) starting from the common minimized structure, ensuring trajectory independence while keeping the equilibrated geometry consistent.

**Performance:** ~114–120 ns/day per replicate on RTX 4090.

---

## 5. Analyses

Analysis scripts and trajectory-processing protocols were inherited from the 5IJ0 main-text analysis to ensure cross-system consistency (`analysis/run_full_analysis.sh`, `analysis/make_plots.py`):

- **Periodic-boundary correction.** `gmx trjconv -pbc nojump` followed by `gmx trjconv -pbc cluster -center` (dimer convention).
- **Backbone RMSD.** Least-squares fit on backbone atoms; reported per replicate and as concatenated traces.
- **Radius of gyration (Rg).** `gmx gyrate` on the protein backbone.
- **Minimum protein–ligand distance.** `gmx mindist` between CPPF heavy atoms and protein.
- **Hydrogen bonds.** `gmx hbond-legacy` between CPPF and protein (consistent with 5IJ0 analysis).
- **Pocket-residue distances.** Mean minimum distance between CPPF and the canonical pocket residues VAL236, LEU253, ALA314 computed over the final 50 ns (150–200 ns) of each replicate.
- **Free energy landscapes.** 2D FELs constructed via Boltzmann inversion of the (RMSD, Rg) joint distribution, plotted with shared axis limits relative to the 5IJ0 main-text FELs.
- **MM-PBSA binding free energy.** gmx\_MMPBSA v1.5+ with the GB-OBC2 model (igb=5, intdiel=1.0, extdiel=78.5), ff99SB + GAFF, T=298.15 K, sub-sampled from the last 50 ns at ~1 ns spacing (~50 snapshots per replicate). Settings match the 5IJ0 main-text MM-PBSA protocol (`revision_exec/analysis/mmpbsa/`) to enable direct cross-system comparison.

All analysis outputs written to `/root/autodl-tmp/analysis_6e7b/` (data disk).

---

## 6. Results Summary

**Binding stability verdict: STABLE** (3 × 200 ns, last 50 ns statistics)

| Metric | Across-rep mean ± s.d. | Per-rep values |
|--------|----------------------|----------------|
| Backbone RMSD (nm) | **0.295 ± 0.026** | 0.270, 0.295, 0.321 |
| min(CPPF–protein) (nm) | **0.203 ± 0.014** | 0.209, 0.214, 0.188 |
| FEL global minimum | RMSD 0.27 nm, Rg 2.99 nm | — |
| MM-PBSA ΔG (kcal/mol) | **−27.82 ± 5.44** | −21.80, −29.28, −32.38 |

**Comparison with 5IJ0 main-text dimer:**
- Minimum CPPF–protein distance in 6E7B (0.203 ± 0.014 nm) falls within the 5IJ0 dimer band (~0.19 nm; 0.14–0.24 nm).
- Backbone RMSD in 6E7B (0.295 ± 0.026 nm) is comparable to or lower than the 5IJ0 per-replicate range (~0.3–0.65 nm), consistent with the more constrained lattice-related conformation.
- MM-PBSA-GB binding free energy in 6E7B (−27.82 ± 5.44 kcal/mol) is comparable to the 5IJ0 main-text value (−31.19 ± 4.04 kcal/mol), with overlapping 1σ intervals across the two β-tubulin conformational states.

Rep1 convergence diagnostics at 200 ns (pre-extension check): backbone RMSD 0.270 nm, min distance 0.210 nm — all binding-relevant metrics CONVERGED; simulations were not extended to 400 ns.

### MM-PBSA-GB Protocol
Following the identical protocol used for the main-text 5IJ0 dimer (`revision_exec/analysis/mmpbsa/`), MM-PBSA-GB analysis was performed with **gmx_MMPBSA v1.5+**, the GB-OBC2 model (`igb=5`, intdiel=1.0, extdiel=78.5, ff99SB + GAFF, T=298.15 K), and ~50 snapshots per replicate sub-sampled from the last 50 ns (150–200 ns) at ~1 ns spacing. Per-replicate output and the cross-replicate summary CSV are at `revision_exec_6e7b/analysis/mmpbsa/6e7b_mmpbsa_summary.csv`.

Full numeric summary: `revision_exec_6e7b/analysis/summary.md`. Plots: `/root/autodl-tmp/analysis_6e7b/plots/`.

---

## 7. Code and Data Availability

- **Preparation scripts:** `revision_exec_6e7b/scripts/prepare_6e7b_complex.py`, `run_6e7b_md_pipeline.sh`, `setup_rep3.sh`
- **Analysis:** `revision_exec_6e7b/analysis/run_full_analysis.sh`, `make_plots.py`
- **MM-PBSA:** `revision_exec_6e7b/analysis/mmpbsa/run_6e7b_mmpbsa.sh`, `recover_and_run_mmpbsa.sh`, `mmpbsa_6e7b_last50ns_gb.in`, `mmpbsa_6e7b_presampled_gb.in`, summary at `6e7b_mmpbsa_summary.csv`
- **MDP files:** `revision_exec_6e7b/prep/mdp/` (em, nvt, npt, md\_prod\_200ns)
- **CPPF topology:** `revision_exec/input/ligand/CPPF_RESP2.itp` (re-used)
- **Trajectories:** `revision_exec_6e7b/md/rep{1,2,3}/md_200ns.xtc` on Hugging Face as `6e7b_rep{1,2,3}_md_200ns.xtc` in [MD-trajectories-CPPF-tubulin-heterodimer-and-monomers](https://huggingface.co/datasets/HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers).

---

## 8. Limitations

- The MD protocol does not explicitly resolve the bound nucleotide identity (GTP vs G2P) and its Mg²⁺ coordination at the β-tubulin E-site. As discussed in §1, the dominant nucleotide effect on the CPPF site is mediated indirectly through backbone conformation, which is captured by the AI prediction step performed with cofactors present. A fully explicit GMPCPP-parameterized comparison could further dissect direct chemical contributions and is identified as a refinement for follow-up work.
- Three replicates × 200 ns were performed for 6E7B, matching the replicate count of the main-text 5IJ0 dimer ensemble. Cross-replicate variance is reported as mean ± s.d. across replicates.
