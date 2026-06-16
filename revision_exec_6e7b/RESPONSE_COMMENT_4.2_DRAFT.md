# Response to Reviewer — Comment 4.2 (6E7B supplementary MD)

**Paste target:** `RESPONSE_TO_REVIEWERS.md` → Reviewer 4, Comment 4.2 block (replace `[TO BE FILLED IN]`).

---

## Comment 4.2 (paraphrase)

The reviewer requested supplementary MD on the **6E7B** (β-GMPCPP / microtubule-lattice-related) tubulin conformation to assess whether CPPF binding is maintained outside the soluble **5IJ0** (β-GDP) state.

---

## Response

We thank the reviewer for this constructive suggestion. We performed **three independent 200 ns all-atom MD replicates** of the CPPF–αβ-tubulin complex in the 6E7B-derived conformation, using the **same cofactor-free protein+ligand protocol** as the main-text 5IJ0 dimer simulations (AMBER99SB-ILDN + GAFF2/RESP2 CPPF, TIP3P, 300 K, 1 bar; GROMACS 2024.5). The starting pose was obtained from Protenix prediction (sample\_0) after Kabsch alignment to the 6E7B template (Cα RMSD **1.82 Å** over aligned residues).

**Binding stability (last 50 ns, 150–200 ns; mean ± s.d. across three replicates):**

| Metric | 6E7B (this work) | 5IJ0 main-text (reference) |
|--------|------------------|----------------------------|
| Backbone RMSD | **0.295 ± 0.021 nm** | per-rep ~0.3–0.65 nm |
| min(CPPF–protein) distance | **0.203 ± 0.011 nm** | ~0.19 nm (0.14–0.24 nm range) |
| Per-replicate backbone RMSD | 0.270, 0.295, 0.321 nm | — |
| Per-replicate min distance | 0.209, 0.214, 0.188 nm | — |
| MM-PBSA-GB ΔG (last 50 ns) | **−27.82 ± 5.44 kcal/mol** | −31.19 ± 4.04 kcal/mol |

CPPF remained in close contact with the protein throughout all three trajectories (minimum heavy-atom distance consistently below 0.25 nm). The across-replicate spread is modest relative to the 5IJ0 dimer ensemble, and the **minimum CPPF–protein distance matches the main-text 5IJ0 dimer band (0.14–0.24 nm)**. We conclude that CPPF retains a **stable binding mode** in the lattice-related β-tubulin conformation, supporting the conformational-state comparison requested by the reviewer.

**Binding free energy (MM-PBSA-GB, last 50 ns, 150–200 ns):** Using the same GB-OBC2 protocol as the main-text 5IJ0 dimer analysis (igb=5, 51 frames per replicate at 1 ns intervals), the average binding free energy was **−27.82 ± 5.44 kcal/mol** across three replicates (per-replicate ΔG: −21.80, −29.28, −32.38 kcal/mol), comparable in sign and magnitude to the 5IJ0 main-text value of **−31.19 ± 4.04 kcal/mol**.

**Trajectory availability:** All three 6E7B production trajectories (`6e7b_rep{1,2,3}_md_200ns.xtc`) are deposited in the project Hugging Face dataset alongside the 5IJ0 and monomer trajectories: [MD-trajectories-CPPF-tubulin-heterodimer-and-monomers](https://huggingface.co/datasets/HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers).

**Figures:** Supplementary time-series panels and a 5IJ0 vs 6E7B comparison figure are provided (see Supplementary Figures; analysis plots in `analysis_6e7b/plots/`).

We did **not** extend 6E7B simulations to 400 ns because convergence diagnostics on the first replicate showed plateaued binding-relevant metrics by 200 ns (backbone RMSD 0.270 nm; min distance 0.210 nm). We did **not** add an explicit GMPCPP/GTP/Mg²⁺ cofactor variant, because (i) the main-text 5IJ0 protocol was likewise cofactor-free for direct comparability, and (ii) the nucleotide-binding site is spatially separated from the CPPF pocket; the cofactor-conditioned geometry is already encoded in the Protenix starting structure (see Methods).

---

## One-sentence summary (optional closing line)

> Supplementary 6E7B MD (3 × 200 ns) demonstrates stable CPPF binding in the lattice-related β-tubulin state, with interfacial distances comparable to the main-text 5IJ0 dimer simulations.
