# 6E7B Supplementary Simulations — Methods Draft

**Status:** Standalone Methods draft for the 6E7B supplementary MD (Reviewer 4.2 response). To be integrated into the manuscript Methods section once simulations complete. Result-dependent sections marked `[TBD: after MD]`.

**Last updated:** 2026-06-09
**MD status:** rep1 production running on AutoDL RTX 4090; rep2 queued.

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

The Protenix-predicted complex was aligned to the 6E7B experimental structure (chains A and B) via Kabsch superposition using Cα atoms common to both structures. The resulting RMSD over all aligned Cα atoms was **[TBD: insert from prepare_6e7b_complex.py log, expected < 1.0 Å]**. After alignment, protein chains A and B and the CPPF ligand (renamed `CPP`, chain C) were extracted; the predicted cofactors were not propagated to the MD topology (see §1).

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
100 ps NVT (`nvt.mdp`) with a 2 fs timestep, V-rescale thermostat at 300 K (τ = 0.1 ps; separate coupling for `Protein_CPP` and `Water_and_ions` groups), LINCS constraints on all bonds, and position restraints (`-DPOSRES`) applied to protein and CPPF heavy atoms. Initial velocities were drawn from a Maxwell–Boltzmann distribution at 300 K (rep1: `gen_seed = -1`; rep2: independent NVT initialization, see §4.4). Short-range cutoffs were set to 1.4 nm to match the production protocol.

### 4.3 NPT Equilibration
100 ps NPT (`npt.mdp`) at 300 K and 1 bar, with V-rescale thermostat and C-rescale barostat (isotropic, τ\_p = 1.0 ps, compressibility = 4.5×10⁻⁵ bar⁻¹). Position restraints retained; `refcoord_scaling = com`.

### 4.4 Production MD

Two independent replicates of **200 ns each** were performed using `md_prod_200ns.mdp`:
- 2 fs timestep, 100,000,000 steps
- V-rescale thermostat (300 K) and C-rescale barostat (1 bar, isotropic)
- PME electrostatics (1.4 nm real-space cutoff, 0.16 nm Fourier spacing, cubic interpolation)
- 1.4 nm van der Waals cutoff with `DispCorr = EnerPres`
- LINCS constraints on all bonds (`lincs_iter = 1`, `lincs_order = 4`)
- Compressed coordinates written every 5000 steps (10 ps); energies every 1000 steps

`gmx mdrun` flags: `-ntmpi 1 -ntomp 16 -nb gpu -pme gpu -bonded gpu -gpu_id 0`. Update and constraints ran on CPU due to the all-bonds constraint set exceeding the GPU LINCS coupling limit in GROMACS 2024.5; this matches the main-text 5IJ0 protocol.

The two replicates were initialized from independent NVT runs (different velocity seeds) starting from the common minimized structure, ensuring trajectory independence while keeping the equilibrated geometry consistent.

---

## 5. Analyses

Analysis scripts and trajectory-processing protocols were inherited from the 5IJ0 main-text analysis to ensure cross-system consistency:

- **Periodic-boundary correction.** `gmx trjconv -pbc nojump` followed by `gmx trjconv -pbc cluster -center` (dimer convention).
- **Backbone RMSD.** Least-squares fit on backbone atoms; reported per replicate and as concatenated traces.
- **Radius of gyration (Rg).** `gmx gyrate` on the protein backbone.
- **Minimum protein–ligand distance.** `gmx mindist` between CPPF heavy atoms and protein.
- **Hydrogen bonds.** `gmx hbond-legacy` between CPPF and protein (consistent with 5IJ0 analysis).
- **Pocket-residue distances.** Mean minimum distance between CPPF and the canonical pocket residues VAL236, LEU253, ALA314 computed over the final 50 ns (150–200 ns) of each replicate.
- **Free energy landscapes.** 2D FELs constructed via Boltzmann inversion of the (RMSD, Rg) joint distribution, plotted with shared axis limits and shared free-energy color scale relative to the 5IJ0 main-text FELs to enable direct visual comparison.

---

## 6. Results Summary `[TBD: after MD]`

**[Placeholder — to be completed once both replicates finish.]**

Expected report:
- Cα RMSD trace (per replicate, concatenated)
- CPPF–protein minimum distance (per replicate)
- H-bond count time series
- Final-window (150–200 ns) mean distance to VAL236, LEU253, ALA314
- Comparison with 5IJ0 main-text: ΔRMSD, Δmin-distance, Δpocket-residue contact
- 2D FEL with global minimum location; basin depth comparison vs 5IJ0
- Verdict statement on whether CPPF retains stable binding in the 6E7B (β-GTP/lattice) conformational state

---

## 7. Code and Data Availability

- **Preparation scripts:** `revision_exec_6e7b/scripts/prepare_6e7b_complex.py`, `revision_exec_6e7b/scripts/run_6e7b_md_pipeline.sh`
- **MDP files:** identical to `revision_exec/input/mdp/*.mdp` (em, nvt, npt, md\_prod\_200ns)
- **CPPF topology:** `revision_exec/input/ligand/CPPF_RESP2.itp` (re-used)
- **Trajectories:** `revision_exec_6e7b/md/rep{1,2}/md\_200ns.{xtc,edr,cpt,log}` on AutoDL; planned upload to the project Hugging Face dataset alongside 5IJ0 trajectories after completion.
- **Analysis scripts:** inherited from `revision_exec/scripts/` for cross-system consistency.

---

## 8. Limitations

- The MD protocol does not explicitly resolve the bound nucleotide identity (GTP vs G2P) and its Mg²⁺ coordination at the β-tubulin E-site. As discussed in §1, the dominant nucleotide effect on the CPPF site is mediated indirectly through backbone conformation, which is captured by the AI prediction step performed with cofactors present. A fully explicit GMPCPP-parameterized comparison could further dissect direct chemical contributions and is identified as a refinement for follow-up work.
- Two replicates (rather than the three used for 5IJ0) were performed for 6E7B to balance computational cost (single RTX 4090, fixed revision deadline) against statistical robustness. Cross-replicate variance is reported, and comparisons with 5IJ0 use across-replicate minimum/maximum bands for both systems.
