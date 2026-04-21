# MD Revision Plan for CPPF-Tubulin Study (Reviewer-Driven Rapid Revision)

## Project Status Snapshot
### Current progress
- Heterodimer template acquired:
  - `revision_exec/5IJ0.pdb` is available and checked.
- Key structural context detected in 5IJ0:
  - chain A (alpha1B), chain B (beta3), with `GTP A501`, `GDP B501`, `MG A502`.
- Legacy workflow references curated:
  - `legacy_from_yfeng494/` contains reusable templates (`mdp`, `CPPF` files, index examples).
- Runtime environment validated:
  - `gmx-lite` is available and usable (`gmx 2024.5-conda_forge`).
- Protenix best starting pose located:
  - `Protenix/CPPF/ab Tub-CPPF/AlphaFold3_abTub_CPPF_pose1_V236_ptm0.96802771091.pdb`
- Input staging completed for runbook execution:
  - `revision_exec/input/5IJ0.pdb`
  - `revision_exec/input/protenix_pose1_abTub_CPPF.pdb`
  - `revision_exec/input/mdp/{ions,em,nvt,npt}.mdp`
- Starting complex build test completed:
  - generated `revision_exec/prep/complex_start.pdb`
  - validation report: `revision_exec/logs/complex_validation_report.txt` (PASS)
  - detected chains: `A`, `B`, and ligand chain `C`
  - retained cofactors confirmed: `GTP`, `GDP`, `MG`
- Phase 1.5 gate (rep1) executed end-to-end:
  - EM converged (`Fmax < 1000`) with stable negative potential energy.
  - NVT completed to 100 ps (`step 50000`) without fatal errors.
  - NPT completed to 100 ps (`step 50000`) without fatal errors.
  - Output set available under `revision_exec/rep1/{em,nvt,npt}/`.

### Major unresolved items (must decide)
1. MM-PBSA execution environment:
   - confirm toolchain/env and command style.

### Risks identified from current files
- Legacy `CPPF.itp` risk:
  - atom charges appear all zeros in the copied template; this can weaken electrostatics realism and reviewer confidence.
- Legacy topology style risk:
  - monolithic monomer-centric `topol.top` files are not directly suitable for heterodimer replicate production.
- Legacy duration mismatch:
  - legacy `md.mdp` is 50 ns and must be upgraded for revision target.

### Immediate coordination agenda (for team discussion)
1. Confirm MM-PBSA runtime environment.
2. Ligand naming convention locked:
   - keep ligand as `chain C`
   - enforce ligand `resname` consistency with final topology (`CPPF`)
3. Decide execution strategy for remaining replicates:
   - run `rep2/rep3` gate tests first, then launch production,
   - or start production for `rep1` immediately while `rep2/rep3` gates run in parallel.

### Locked scientific decisions (finalized)
1. Starting structure:
   - Use Protenix heterodimer `pose 1` (Table 1 dimer RMSD = 1.318 \AA) aligned to `5IJ0`.
2. Cofactors:
   - Keep `GTP/GDP/MG2+` in production system.
   - Use established literature nucleotide parameter sets (no ad-hoc de novo GAFF of nucleotides).
3. Ligand charge model:
   - Use `RESP2(0.5)` for CPPF (CPPF-only recharging route).
4. Force field and water:
   - `amber99sb-ildn + GAFF2 + TIP3P`.

## Goal
Prepare a reviewer-oriented and deadline-feasible MD revision plan that directly addresses major criticisms, with focus on:
- physiologically relevant system definition (alpha/beta tubulin heterodimer, not monomer-only evidence),
- replicate-supported MD evidence (independent seeds),
- interaction and energetics analyses that can be completed before resubmission.

Locked status in this iteration:
- `5IJ0` structure has been downloaded and prepared under `revision_exec/5IJ0.pdb`.
- Existing CPPF parameter assets are accepted for current revision cycle.
- Primary scientific target is heterodimer-centric evidence; monomer is supplementary only.
- Protenix heterodimer `pose 1` is selected as MD starting pose definition.
- Protenix `pose 1` file path has been identified and registered in this plan.
- Cofactors `GTP/GDP/MG2+` are retained in production topology.
- Force-field/water locked: `amber99sb-ildn + GAFF2 + TIP3P`.
- CPPF charge route locked: `RESP2(0.5)`.

## Scope and Systems (Locked Priorities)
- Primary target system:
  - CPPF bound to alpha/beta tubulin heterodimer
- Optional comparative system (only if time allows):
  - legacy monomer setup for supplementary consistency check (not main evidence)
- Force-field strategy (to lock before production):
  - Protein: Amber99SB-ILDN (or newer Amber protein force field if already validated in your project)
  - Ligand: GAFF-based topology with RESP/RESP2 charges
  - Water model: choose one and keep consistent across all runs (recommended to justify and document clearly)
- Ions:
  - neutralization + fixed salt concentration protocol (e.g., physiological concentration)
- Cofactors:
  - preserve biologically relevant cofactors/ions in the heterodimer model when supported by the structural template

## Available Assets and Reuse Strategy
- Legacy references have been curated under:
- `legacy_from_yfeng494/common/`
- `legacy_from_yfeng494/alpha_template/`
- `legacy_from_yfeng494/tubb3_template/`
- Reuse policy:
  - Reuse ligand parameter assets (`CPPF.itp`, `CPPF.gro`, `CPPF.mol2`) as starting point.
  - Reuse `em/nvt/npt/md.mdp` parameter blocks as templates only.
  - Do not directly reuse monomer `topol.top` as final production topology.
  - Do not directly reuse 50 ns production setup; all production settings must be upgraded for revision targets.

## Required Input Checklist (Execution Blocking)
Status labels:
- `[Ready]` available in current workspace
- `[Need]` must be provided/confirmed before production launch

1. System definition
   - `[Ready]` final heterodimer+CPPF starting file:
     - `Protenix/CPPF/ab Tub-CPPF/AlphaFold3_abTub_CPPF_pose1_V236_ptm0.96802771091.pdb`
   - `[Need]` chain mapping and residue naming consistency plan
2. Topology and force field
   - `[Ready]` candidate ligand parameters (`CPPF.itp/.gro/.mol2`)
   - `[Need]` final protein+ligand+cafactor topology assembly for heterodimer
   - `[Ready]` force-field and water-model locked (`amber99sb-ildn + GAFF2 + TIP3P`)
3. Cofactor handling
   - `[Ready]` cofactors retained in production (`Mg2+`, `GDP`, `GTP`)
   - `[Need]` if retained, parameter/include files and topology references
4. Run control files
   - `[Ready]` legacy `em.mdp`, `nvt.mdp`, `npt.mdp`, `md.mdp`, `ions.mdp` templates
   - `[Need]` revised replicate-aware `md.mdp` (>=200 ns target; seed policy included)
5. Analysis pipeline
   - `[Need]` current figure-generation scripts and input tables used for Fig4/Fig5/Supp
   - `[Need]` MM-PBSA toolchain confirmation (gmx_MMPBSA environment and command style)
6. Reporting
   - `[Need]` final response-letter wording constraints (if PI/team already fixed wording)

Minimum inputs still required before production launch:
- Confirmed MM-PBSA execution environment and command style.

## Proposed Working Directory Layout (Final Revision Workspace)
Use a clean, script-first structure:

`revision_exec/`
- `input/`
  - `heterodimer_cppf.pdb`
  - `topol.top`
  - `ligand/` (`CPPF.itp`, `CPPF.gro`, `CPPF.mol2`)
  - `mdp/` (`ions.mdp`, `em.mdp`, `nvt.mdp`, `npt.mdp`, `md_200ns.mdp`)
- `rep1/`
  - `em/`, `nvt/`, `npt/`, `md/`
- `rep2/`
  - `em/`, `nvt/`, `npt/`, `md/`
- `rep3/`
  - `em/`, `nvt/`, `npt/`, `md/`
- `analysis/`
  - `core_metrics/`, `fel/`, `mmpbsa/`, `figures/`
- `logs/`
  - `run_manifest.csv`
  - `method_changes.md`

Naming convention to enforce:
- System root: `dimer_cppf`
- Replicates: `rep1`, `rep2`, `rep3`
- Production prefix: `md_200ns`
- Seed mapping:
  - `rep1: gen_seed=11001`
  - `rep2: gen_seed=22002`
  - `rep3: gen_seed=33003`

## Phase 1.5: Rapid Validation Gate (Before Full 3x200 ns)
Run a short gate test (for example 2-5 ns per replicate) to reduce expensive failure risk.

Gate checks:
1. `grompp` warning audit: no unresolved critical warning in production path.
2. Topology integrity: molecule counts and include tree match expected system.
3. Stability sanity:
   - no explosive energy/temperature drift,
   - no immediate ligand escape due to setup artifacts,
   - pressure/density enters reasonable range during equilibration.
4. Analysis dry-run:
   - RMSD/Rg/H-bond scripts run on pilot trajectory without manual edits.

Pass criterion:
- all 4 checks pass for rep1, then launch rep2/rep3 full production.

Failure response policy:
- Topology/include mismatch -> stop, fix include tree, rerun gate.
- Early trajectory instability -> strengthen equilibration and recheck index/restraints.
- Persistent LINCS or pressure blow-up -> do not scale to full replicates until resolved.

## Phase 2 Detailed Execution Targets
For each replicate:
1. EM -> generate `em.gro`, `em.edr`, `em.log`
2. NVT -> generate `nvt.gro`, `nvt.cpt`, `nvt.edr`, `nvt.log`
3. NPT -> generate `npt.gro`, `npt.cpt`, `npt.edr`, `npt.log`
4. MD production -> generate `md_200ns.xtc`, `md_200ns.tpr`, `md_200ns.edr`, `md_200ns.log`, `md_200ns.cpt`
5. Checkpoint-resume policy:
   - if interrupted, resume only from latest `cpt`,
   - append command and timestamp to `run_manifest.csv`.

Command skeleton (to be instantiated per replicate after final input lock):
- `gmx grompp -f em.mdp -c system_start.gro -p topol.top -o em.tpr`
- `gmx mdrun -deffnm em`
- `gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr -n index.ndx`
- `gmx mdrun -deffnm nvt`
- `gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -n index.ndx`
- `gmx mdrun -deffnm npt`
- `gmx grompp -f md_200ns.mdp -c npt.gro -t npt.cpt -p topol.top -o md_200ns.tpr -n index.ndx`
- `gmx mdrun -deffnm md_200ns`
- Resume: `gmx mdrun -deffnm md_200ns -cpi md_200ns.cpt`

## Phase 1: Method Standardization (Must Finish First)
1. Unify naming and files
   - Use one ligand naming convention (`CPPF`) in all `gro`, `itp`, `top`, and plotting scripts.
   - Remove ambiguous legacy names in new workflow outputs.
   - Explicitly label all production data as `dimer_rep{1,2,3}`.
2. Lock topology generation protocol
   - Document ligand parameter source and charge calculation pipeline.
   - Record any missing/substituted parameters and rationale.
3. Remove manual structure editing
   - Replace hand-editing of `complex.gro` with scriptable merge/check steps.
   - Add validation checks: atom count, molecule count, topology consistency.
4. Remove avoidable `-maxwarn` bypass in production pathway
   - For each warning, capture exact cause and resolution.
5. Lock reviewer-facing system statement
   - Clearly state that revision simulations use heterodimer-based model as primary evidence.

Deliverable:
- `METHOD_LOCK.md` with exact software versions, parameters, and command templates.

## Phase 2: Production MD Extension (Replicate-Centered)
For the heterodimer+CPPF system:
1. Energy minimization
2. NVT equilibration
3. NPT equilibration
4. Production MD (target: 3 independent replicates, each >= 200 ns)
5. If interrupted, resume from checkpoint and keep continuous trajectory metadata

Recommended run organization:
- one directory for primary system (`dimer_cppf/`)
- one subdirectory per replicate (`rep1/`, `rep2/`, `rep3/`)
- each replicate contains stage folders (`em/`, `nvt/`, `npt/`, `md/`)
- explicit seed policy (`gen_seed` differs across replicates and is logged)

Deliverables:
- `rep{1,2,3}_md_200ns.xtc`, `.tpr`, `.edr`, `.log`, checkpoint files
- run manifest (`run_manifest.csv`) with replicate ID, seed, start/end time, node/GPU info, and command history

## Phase 3: Analysis Required by Reviewer
Mandatory analyses (replicate-aware):
- RMSD (protein backbone, ligand heavy atoms)
- RMSF (binding-site residues)
- Radius of gyration (Rg) (explicitly ensure no missing plot)
- Hydrogen bond occupancy and persistence
- Contact frequency map (ligand-residue contacts)
- van der Waals and electrostatic interaction energy decomposition (trajectory-based)
- stability comparison across replicates (mean + spread, block-based uncertainty)

Minimal statistical reporting rule:
- For each metric, report per-replicate trace + aggregate summary (mean +/- SD or block SE).
- Clearly distinguish within-replicate fluctuation from between-replicate variation.

Mandatory figure QC before manuscript insertion:
- confirm Rg panel exists and is not duplicated with SASA panel.
- verify panel labels (A/B/C...) and legend text correspond to actual data.
- verify all units (`nm`, `kcal/mol`, `ns`) are consistent.

Quality checks:
- no duplicated subplot panels
- consistent axis units and labels
- include replicate-aware or block-average uncertainty where feasible

Deliverables:
- `fig_md_core.pdf` / `fig_md_core.png`
- `tables_interaction_energy.csv`
- `analysis_notes.md`

## Phase 3.5: MM-PBSA Priority Energetics (Primary for Revision)
Objective:
- Provide deadline-feasible binding energetics from stable trajectory segments.

Protocol outline:
1. Select production windows from each replicate (for example, stable late-phase segments).
2. Run MM-PBSA/GBSA consistently across replicates.
3. Perform per-residue energy decomposition for binding-site interpretation.
4. Report average, spread, and consistency trends across replicates.

Deliverables:
- `mmpbsa_summary.csv`
- `mmpbsa_per_residue.csv`
- one reviewer-facing figure/table linking energetics to beta-subunit preference claim.

Interpretation guardrails:
- emphasize comparative trend across replicates over absolute value claims.
- report replicate spread explicitly to avoid overconfidence language.

## Phase 4: Umbrella Sampling for Dissociation PMF (Optional Fallback, Time-Permitting)
Objective:
- Only attempt if Phase 2+3.5 are complete and convergence risk is acceptable before deadline.

Protocol outline:
1. Define reaction coordinate (e.g., ligand-protein COM distance along extraction path).
2. Generate initial pulling trajectory.
3. Select windows along coordinate (uniform spacing).
4. Equilibrate each window.
5. Production sampling per window.
6. WHAM/MBAR reconstruction of PMF.
7. Convergence checks:
   - overlap between neighboring windows
   - cumulative PMF stability over time slices

Deliverables (optional):
- window setup metadata (`us_windows.csv`)
- PMF profile figure with uncertainty band
- convergence figure(s)
- short interpretation paragraph for Results and Response Letter

## Suggested Timeline (Quality-First Weekly Plan)
- Week 1:
  - finalize starting complex (`pose 1` + `5IJ0` alignment), cofactor policy, and topology lock
  - complete CPPF RESP2(0.5) charge pipeline and integrate updated ligand topology
  - complete Phase 1.5 gate tests and resolve all setup instabilities
- Week 2-3:
  - run 3 independent production replicates to target length (>= 200 ns each)
  - perform rolling QC and checkpoint-based sanity reviews
- Week 3-4:
  - complete replicate-aware core analysis (RMSD/RMSF/Rg/H-bond/contact/energy trends)
  - run MM-PBSA and per-residue decomposition with aggregate uncertainty reporting
- Week 4-5:
  - finalize figures/tables and update Methods/Results/Discussion text
  - draft and polish response-to-reviewer mapping
  - run optional US only if already convergent and scientifically additive

Quality-first contingency:
- If any replicate shows setup artifacts, pause expansion and fix root cause before continuing.
- Prefer complete, internally consistent evidence over partial high-volume runs.
- Do not include weakly converged enhanced-sampling results just to increase method count.

## Manuscript Update Requirements (Concrete Edits)
1. Methods:
   - replace monomer-primary phrasing with heterodimer-primary protocol.
   - explicitly report replicate count and seed policy.
   - explicitly report final simulation length and analysis windows.
2. Results:
   - ensure no duplicated panels and include Rg clearly.
   - show replicate-aware plots/tables for stability and interactions.
   - include MM-PBSA aggregate and per-residue decomposition summary.
3. Discussion:
   - avoid over-claiming from single-trajectory behavior.
   - tie conclusions to replicate consistency and energetics.
   - mark US as not completed (if not done) and justify with deadline/prioritization.

## Risks and Mitigation
- Parameter uncertainty for ligand:
  - Mitigation: freeze one charge model and report sensitivity notes if needed.
- Insufficient sampling convergence:
  - Mitigation: prioritize replicate consistency and block analysis; extend only highest-value segments.
- Reproducibility concerns:
  - Mitigation: keep command logs, software version logs, and automated pipeline scripts.
- Deadline risk:
  - Mitigation: prioritize heterodimer + replicate MD + MM-PBSA; treat US as optional.

## Manuscript/Response Mapping
Map each reviewer concern to concrete output:
- "Monomer relevance concern" -> heterodimer-focused Phase 1/2 setup and evidence
- "Need replicate simulations" -> Phase 2 replicate outputs and replicate-aware statistics
- "Extend MD to >=200 ns" -> replicate trajectories and updated stability figures
- "Include interaction-level metrics" -> Phase 3 outputs
- "Need binding energetics" -> Phase 3.5 MM-PBSA outputs (primary)
- "Enhanced sampling suggestion" -> Phase 4 marked as optional/time-permitting
- "Figure issue (repeated panels, missing Rg)" -> Phase 3 quality checklist

## Immediate Next Actions
1. Freeze heterodimer system definition and cofactor retention.
2. Freeze ligand parameterization protocol (RESP2(0.5) locked for CPPF).
3. Create replicate-ready scripted build (`rep1/rep2/rep3`) and launch runs now.
4. Prepare MM-PBSA pipeline in parallel to avoid post-run bottleneck.

## Information Still Needed From Team (Actionable Request List)
Please provide/confirm these items in this order:
1. Available compute envelope before deadline:
   - number of GPUs (note: GPU visibility depends on allocated compute node; login node may show none),
   - expected wall-time per 200 ns replicate,
   - allowed parallel replicate count.
2. MM-PBSA execution environment details (existing env name and validated command, if any).
3. Ligand naming convention for final topology:
   - locked to keep ligand as current chain `C` naming from merged complex.

## Latest Execution Notes
- `check_env.sh` run completed in `gmx-lite`:
  - `gmx` available and working
  - core input files found
  - `gmx_MMPBSA` not found in current PATH
- Complex assembly script run:
  - `prepare_complex_from_pose1.py` completed successfully
  - `validate_complex_pdb.py` report status: `PASS`

## Reviewer Response Draft Mapping (Execution to Wording)
- Monomer relevance concern:
  - "Revision simulations are heterodimer-based and used as primary evidence."
- Replicate concern:
  - "Three independent seeds were simulated and analyzed with aggregate statistics."
- Timescale concern:
  - "Production protocol extends beyond initial short trajectories."
- Energetics concern:
  - "MM-PBSA and per-residue decomposition were added with replicate-consistent trends."
- Figure quality concern:
  - "Figure set rebuilt with explicit QC; duplicated/missing panels corrected."

## Next Technical Deliverable
- `RUNBOOK.md` completed:
  - `tubulin-cppf-md/docs/RUNBOOK.md`
- Next deliverable after MM-PBSA env confirmation:
  - environment-specific MM-PBSA command section (to append into RUNBOOK).

