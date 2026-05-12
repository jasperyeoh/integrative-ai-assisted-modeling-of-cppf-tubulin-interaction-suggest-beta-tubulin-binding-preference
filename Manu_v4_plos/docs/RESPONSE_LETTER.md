## Response to reviewers

Dear Professor Taghizadeh, Professor Walther, and Reviewers,

We thank the editor and reviewers for the careful evaluation of our manuscript, “Integrative AI-Assisted Modeling of CPPF–Tubulin Interactions Suggests β-Tubulin Binding Preference.” The comments substantially improved the rigor, reproducibility, and biological framing of the study. In the revised manuscript, we have strengthened the structural validation, extended and replicated the molecular dynamics simulations, added MM-PBSA binding free-energy calculations, revised the free-energy landscape analysis, added benchmarking against experimental tubulin–ligand structures and prior in silico studies, improved data availability, and corrected figure/text formatting issues.

Major changes include:

- Extension of MD simulations to three independent heterodimer replicates of 400 ns and three monomer replicates of 200 ns per class.
- Addition of PBC-corrected trajectory processing and regenerated MD figures.
- Addition of MM-PBSA (GB) energetics over the heterodimer 350--400 ns window, reporting ΔVDW, ΔEEL, ΔEGB, ΔESURF, and ΔTOTAL.
- Addition of a Protenix/nocodazole benchmark against the experimental cryo-EM structure PDB 5CA1.
- Addition of a structural comparison between crystallized colchicine-bound tubulin (PDB 4O2B) and Protenix-predicted CPPF-bound models.
- Addition of a ProTox 3.0 toxicity/off-target profile as Supplementary Fig. S1.
- Public deposition of MD production trajectories on Hugging Face and documentation of analysis scripts in the GitHub repository.
- Implementation of a smoke-tested Nextflow workflow for the complete revised analysis pipeline.

Below we respond to each point in detail.

## Editor and Journal Requirements

### Data availability

**Comment:** All data underlying the findings must be freely available, including MD trajectory files.

**Response:** We have addressed this requirement. The underlying all-atom MD production trajectories are publicly available on the Hugging Face Hub:

\url{https://huggingface.co/datasets/HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers}

The companion GitHub repository contains the computational workflow, scripts, runbooks, generated analysis artifacts, and documentation required to reproduce the revised analyses and figures.

### Main figure files

**Comment:** Please upload all main figures as separate `.tif` or `.eps` files.

**Response:** We have exported the main figures in TIFF format, with PNG preview copies retained for manuscript assembly and review. Multi-panel figures have been revised with A--D panel labels where applicable.

## Reviewer #1

### Comment 1.1

**Comment:** The reviewer asked why AI-based structure prediction was necessary given the availability of PDB 5IJ0, how predicted structures were validated, why the experimental structure was not used directly, and how cofactors such as Mg²⁺ were considered.

**Response:** We thank the reviewer for this important point. We have revised the manuscript to clarify that our goal was not to predict the tubulin fold de novo, but to model plausible CPPF-bound tubulin complexes in the absence of an experimentally solved CPPF--tubulin structure. The experimental 5IJ0 structure was used as the biological template/reference for the tubulin heterodimer context, and predicted complexes were aligned back to experimental reference structures to evaluate structural accuracy.

To validate the structural accuracy of the predicted protein models, we aligned Protenix-generated structures to the corresponding experimental references and reported backbone RMSD values in Table 1. For the β-tubulin monomer, all Protenix-predicted poses showed sub-angstrom to near-sub-angstrom agreement with the experimental reference, with RMSD values of 0.578--0.841 Å and a mean RMSD of 0.682 Å. These values indicate that the protein backbone geometry of the predicted models is highly consistent with the experimental structure, supporting their use as receptor frameworks for downstream binding-site analysis and MD simulation.

We also added a ligand-level benchmark using nocodazole, a well-characterized tubulin ligand with an experimentally determined cryo-EM binding mode. Specifically, Protenix-predicted β-tubulin--nocodazole poses were aligned to the experimental nocodazole-bound β-tubulin structure (PDB: 5CA1), and the resulting alignment is shown in Supplementary Fig. S2. The predicted poses recapitulated the known binding region, providing an additional positive-control validation of the AI-based modeling workflow before applying it to CPPF.

Regarding cofactors, we now explicitly describe the structural context of 5IJ0, including Mg²⁺, GTP, and GDP, in the manuscript. In ligand docking and pose-prediction workflows, crystallographic waters, ions, or non-target cofactors are often simplified or omitted depending on the software constraints and the purpose of the docking step. We have clarified this point without treating it as a limitation unique to our study. Importantly, the structural benchmark against a ligand-bound experimental tubulin complex supports that this modeling workflow preserves the relevant binding-site geometry. The revised MD simulations were then used to evaluate the stability of the resulting CPPF--tubulin complexes in an explicit dynamic context.

### Comment 1.2

**Comment:** The reviewer asked for a clearer biological rationale for analyzing monomeric α1B- and β3-tubulin when CPPF is proposed to interact with the α/β heterodimer.

**Response:** We agree that this point required clearer framing, and we have substantially revised the manuscript. The monomeric analyses are now presented as complementary, not as the primary physiological binding claim. Their purpose is to test whether the predicted CPPF pocket remains stable in the absence of the α/β heterodimer interface and to contrast this behavior with the assembled heterodimer.

Our revised data support the assembled α/β heterodimer as the relevant structural framework for stable CPPF accommodation. In isolated β-tubulin monomer simulations, CPPF did not consistently maintain proximity to canonical pocket residues such as LEU253 and ALA314 during the final 50 ns, with mean minimum distances of 0.64--1.36 nm and 0.90--1.59 nm across replicates, respectively. In contrast, in the α/β-tubulin heterodimer, CPPF maintained stable interfacial contacts across three independent 400 ns replicates, with minimum protein--ligand distances of 0.14--0.24 nm, a localized FEL basin, and favorable MM-PBSA energetics. We therefore revised the mechanistic interpretation from “monomer preference” to a heterodimer-centered model in which the β-tubulin side of the interface provides the most stable local accommodation site for CPPF.

We also clarified in the Introduction that 5IJ0 was selected because it represents a soluble α/β-tubulin heterodimer conformation relevant to microtubule-destabilizing ligands. This framing avoids implying that CPPF binds unfolded or partially folded monomers.

### Comment 1.3

**Comment:** The reviewer noted that the PDBePISA ΔG values of −0.4 and −0.2 kcal/mol are too small to support stable binding.

**Response:** We agree and have revised the manuscript accordingly. We now explicitly treat PDBePISA ΔG as a static single-structure interface estimate rather than the primary binding-energy evidence. To provide a more rigorous energetic assessment, we added MM-PBSA (GB) calculations over the final 50 ns of the heterodimer trajectories (350--400 ns, 51 frames per replicate). Across three replicates, the mean binding-energy components were ΔVDW = −41.96 ± 1.33 kcal/mol, ΔEEL = −5.91 ± 2.22 kcal/mol, ΔEGB = +22.29 ± 0.63 kcal/mol, ΔESURF = −5.61 ± 0.23 kcal/mol, and ΔTOTAL = −31.19 ± 4.04 kcal/mol. We now anchor binding-stability conclusions on the combined MD time series, FEL, and MM-PBSA results rather than on the PDBePISA value alone.

### Comment 1.4

**Comment:** The reviewer noted that 50 ns MD simulations are too short for tubulin.

**Response:** We have extended the simulations substantially. The revised manuscript includes three independent 400 ns heterodimer simulations and three independent 200 ns monomer simulations for each monomer class. We also reprocessed trajectories using a two-step PBC correction procedure to remove jump artifacts before recalculating RMSD and Rg.

### Comment 1.5

**Comment:** The reviewer asked for clearer novelty and stronger validation.

**Response:** We revised the manuscript to clarify that the contribution is not a new algorithm, but a reproducible, integrative computational workflow for CPPF--tubulin recognition: pocket analysis, multi-platform pose generation, experimental-structure benchmarking, replicate MD, FEL analysis, and MM-PBSA energetics. We have implemented the complete analysis pipeline as a reproducible Nextflow workflow (Nextflow v26.04.1; Di Tommaso et al., 2017), integrating all steps from structure preparation, molecular dynamics simulation (three independent replicates), PBC trajectory correction, MM-PBSA binding free energy calculation, free energy landscape construction, and automated figure generation. The pipeline, conda environment specifications, and documentation are publicly available at \url{https://github.com/GITHUB_NAMESPACE/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference} and have been smoke-tested end-to-end on our HPC cluster. We also added the nocodazole benchmark against PDB 5CA1, the 4O2B colchicine-site structural comparison, the extended replicate MD simulations, and MM-PBSA calculations. Experimental mutational validation remains outside the scope of this computational revision, and we now state this clearly as a future validation direction.

## Reviewer #2

### Comment 2.1

**Comment:** Some abbreviations were not defined, for example GTP.

**Response:** We corrected this by defining GTP as guanosine triphosphate at first mention and expanded additional tool/analysis abbreviations, including PLIP, PDBePISA, and GROMACS.

### Comment 2.2

**Comment:** Several claims in the Introduction lacked proper citations.

**Response:** We revised the Introduction to improve point-of-claim citation placement. In particular, we added citation support for drug-resistance context, placed the Han et al. citation directly after the CPPF docking/colchicine-site overlap statement, and removed the unsupported claim that TUBA1B is broadly expressed in proliferative tissues.

### Comment 2.3

**Comment:** The results should be benchmarked against existing experimental and in silico studies.

**Response:** We added two forms of benchmarking. First, we benchmarked Protenix predictions against the experimental nocodazole-bound β-tubulin cryo-EM structure (PDB: 5CA1; Supplementary Fig. S2). Second, we added a Discussion paragraph comparing our CPPF MM-PBSA ΔTOTAL (−31.19 ± 4.04 kcal/mol) to published MM-GBSA estimates for DAMA-colchicine bound to human αβ-tubulin heterodimers (Kumbhar et al., 2016; ref. 44), while explicitly noting that absolute endpoint free-energy values are protocol-dependent. To support reproducibility of these analyses, we have implemented the complete analysis pipeline as a reproducible Nextflow workflow (Nextflow v26.04.1; Di Tommaso et al., 2017), integrating all steps from structure preparation, molecular dynamics simulation (three independent replicates), PBC trajectory correction, MM-PBSA binding free energy calculation, free energy landscape construction, and automated figure generation. The pipeline, conda environment specifications, and documentation are publicly available at \url{https://github.com/GITHUB_NAMESPACE/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference} and have been smoke-tested end-to-end on our HPC cluster.

### Comment 2.4

**Comment:** Some Å symbols lacked spacing.

**Response:** We normalized Å formatting throughout the manuscript, using forms such as `1.39~\AA` and `in~\AA`.

### Comment 2.5

**Comment:** The DrugScore > 0.7 threshold required justification.

**Response:** We added a rationale explaining that Drug Score > 0.7 was used as a practical cutoff to prioritize potentially druggable pockets for downstream inspection.

### Comment 2.6

**Comment:** Fig. 2 should better show surface properties such as hydrophobic/hydrophilic features.

**Response:** We clarified the role of Fig. 2 and related figures. Fig. 2 is retained as a cross-platform pose comparison figure with zoomed surface views and representative interaction distances. Pocket-scale physicochemical characterization is reported through ProteinsPlus screening and Fig. 1D, and residue-level interaction chemistry is summarized in Fig. 3 and the PLIP-based analyses. We revised the Fig. 2 caption to make this division of information explicit. We also added a reproducible PyMOL-oriented workflow under `Manu_v4_plos/scripts/` for regenerating hydrophobicity-colored binding-cavity surface views if a separate supplementary surface panel is requested.

### Comment 2.7

**Comment:** Since SwissADME was used, ADME/Tox properties should also be assessed.

**Response:** We added a ProTox 3.0 toxicity and off-target activity prediction for CPPF as Supplementary Fig. S1 and added a Methods sentence introducing this analysis. The figure shows predicted toxicity probabilities across endpoints and off-target classes relative to the ProTox 3.0 training-set activity profile. Full experimental ADME/Tox characterization remains outside the scope of this computational revision, but the added ProTox 3.0 analysis provides a transparent in silico toxicity screen.

### Comment 2.8

**Comment:** pTM and ipTM should be defined.

**Response:** We revised the Table 1 caption to define pTM as a predicted template-modeling score reflecting global fold confidence and ipTM as an interface-confidence metric for multimeric predictions.

### Comment 2.9

**Comment:** Interaction-related parameters such as hydrogen-bond occupancy, vdW/electrostatic components, and MM-PBSA should be included.

**Response:** We revised the MD analysis and Results accordingly. The new heterodimer MD figure reports backbone RMSD, Rg, minimum protein--ligand distance, and hydrogen-bond count across three replicates. We also added MM-PBSA component reporting, including ΔVDW, ΔEEL, ΔEGB, ΔESURF, and ΔTOTAL.

### Comment 2.10

**Comment:** Fig. 4 contained duplicated panels and the Rg plot was missing.

**Response:** We replaced the old Fig. 4 with a new 2×2 heterodimer MD figure showing backbone RMSD, Rg, minimum protein--ligand distance, and hydrogen-bond count across three 400 ns replicates. The duplicated panel issue has been removed.

### Comment 2.11

**Comment:** The reviewer suggested longer simulations and enhanced sampling, preferably umbrella sampling.

**Response:** We extended the MD simulations to three 400 ns heterodimer replicates and three 200 ns monomer replicates for each monomer class. We did not perform umbrella sampling in this revision cycle because the requested revision was addressed through substantially longer unbiased replicate MD, PBC-corrected analysis, FEL comparison, and MM-PBSA energetics. We now clearly state remaining limitations and future directions.

## Reviewer #3

### Comment 3.1

**Comment:** The novelty of the study was unclear.

**Response:** We revised the manuscript to clarify the novelty as a reproducible, end-to-end computational workflow applied to CPPF--tubulin recognition, rather than a new algorithm. The revised workflow integrates AI-assisted modeling, experimental-structure benchmarking, residue-level interaction analysis, replicate MD, FEL analysis, and MM-PBSA energetics. The study also adds a new mechanistic interpretation that CPPF is accommodated more stably in the β-tubulin side of the assembled α/β interface.

### Comment 3.2

**Comment:** The reviewer asked why nocodazole is an appropriate validation ligand for CPPF.

**Response:** We clarified that nocodazole was not used to validate the CPPF binding mode directly. Instead, it was used as a positive-control ligand to benchmark the modeling pipeline because nocodazole is a well-characterized tubulin-binding ligand with an experimentally determined cryo-EM binding mode. We added Supplementary Fig. S2, which overlays Protenix-predicted β-tubulin--nocodazole poses with the experimental nocodazole-bound β-tubulin structure (PDB: 5CA1). This benchmark supports the ability of the modeling workflow to recover a known tubulin--ligand binding region before applying it to CPPF.

### Comment 3.3

**Comment:** The reviewer asked why classical docking methods were not systematically included and how alternative methods were excluded.

**Response:** We clarified the role of classical and alternative docking approaches. The original CPPF study used AutoDock and suggested partial overlap with the colchicine site. In our revised manuscript, we added a structural comparison with the experimentally determined colchicine-bound tubulin complex (PDB: 4O2B; Fig. 7). This comparison shows that the Protenix-predicted CPPF pose is proximal to the broader colchicine-site region but occupies a deeper β-tubulin cleft that is spatially distinct from the crystallographic colchicine-bound conformation. This provides a structural explanation for why CPPF can remain active in colchicine-resistant contexts despite proximity to the colchicine-site region. We also note that we evaluated alternative tools such as SwissDock and Chai-1, but they produced less stable or less reproducible poses under our evaluation criteria. The revised manuscript now emphasizes fit-for-purpose AI-based modeling validated against experimental structural data.

### Comment 3.4

**Comment:** The energetic differences from PDBePISA were too small and may be within noise.

**Response:** We agree and have revised the energetic interpretation. PDBePISA values are now described as static interface estimates, not as definitive binding free energies. We added replicate MM-PBSA calculations with ΔTOTAL = −31.19 ± 4.04 kcal/mol across heterodimer replicates, providing a stronger energetic basis for the binding-stability discussion.

### Comment 3.5

**Comment:** The reviewer asked whether CPPF binds soluble/curved tubulin versus lattice-incorporated tubulin and whether alternative conformations were considered.

**Response:** We added text clarifying why 5IJ0 was selected. We selected 5IJ0 because it captures a soluble α/β-tubulin heterodimer conformation relevant to microtubule-destabilizing ligands, which may prevent conformational transitions required for productive lattice incorporation. We did not explicitly model all alternative tubulin conformational states in this revision; this is now described as an important future direction.

### Comment 3.6

**Comment:** The reviewer asked whether 50 ns simulations were sufficient and whether replicates were performed.

**Response:** We addressed this by extending the simulations and adding replicates: three independent 400 ns heterodimer simulations and three independent 200 ns monomer simulations for each monomer class. The revised figures show replicate traces and across-replicate spread.

## Reviewer #4

### Comment 4.1

**Comment:** The reviewer noted that the PDBePISA ΔG values are weaker than thermal energy and suggested more rigorous binding-energy methods such as FEP.

**Response:** We agree that the PDBePISA ΔG values alone are not sufficient to support stable binding. We therefore added replicate MM-PBSA (GB) calculations over the final 50 ns of each heterodimer simulation. The resulting ΔTOTAL was −31.19 ± 4.04 kcal/mol across replicate averages. While we did not perform FEP in this revision cycle, the added MM-PBSA analysis, extended replicate MD, and shared-scale FELs provide substantially stronger energetic and dynamic support than the original PDBePISA estimate.

### Comment 4.2

**Comment:** The reviewer suggested considering the GTP-bound conformation (PDB: 6E7B).

**Response:** We thank the reviewer for raising this important point. The 5IJ0 structure used in this study is an α/β-tubulin heterodimer in which the α-subunit is GTP-bound and the β-subunit is GDP-bound, with Mg²⁺ also present in the native structural context. Thus, our simulations capture CPPF interactions in a physiologically relevant nucleotide-containing heterodimer context. PDB 6E7B represents a distinct GTP-bound β-tubulin conformational state; modeling CPPF binding across this additional state would be informative, and we now describe such conformational-state comparisons as a future extension.

### Comment 4.3

**Comment:** The reviewer noted that FEL differences were hard to visualize and asked for quantitative description.

**Response:** We regenerated the main FELs using shared axis limits and a shared kcal/mol color scale capped at 5 kcal/mol. We also added quantitative global-minimum coordinates: the combined β landscape minimum is near Rg ≈ 2.19 nm and RMSD ≈ 0.43 nm, whereas the combined α landscape minimum is near Rg ≈ 2.20 nm and RMSD ≈ 0.48 nm. This supports the conclusion that α samples a broader, more structurally drifted landscape than β.

### Comment 4.4

**Comment:** FEL plots used kJ/mol, while text and tables used kcal/mol.

**Response:** We corrected this. FELs are now presented in kcal/mol with a shared scale capped at 5 kcal/mol.

### Comment 4.5

**Comment:** Fig. 4E duplicated Fig. 4F and the Rg plot was missing.

**Response:** We replaced the old figure with a new heterodimer MD figure containing backbone RMSD, Rg, minimum protein--ligand distance, and hydrogen-bond count. The duplicated panel issue has been removed.

### Comment 4.6

**Comment:** The reviewer noted that the molecular dynamics analysis Python scripts were not included.

**Response:** We have included analysis scripts under `revision_exec/analysis_revision/` and documented their use in the runbook and reviewer evidence checklist. The GitHub repository now contains the code and documentation required to reproduce the revised figures and tables.
