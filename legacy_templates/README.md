# Curated Legacy Reference from yfeng494_data

## Purpose
This folder contains selected files copied from legacy work so we can reuse useful setup templates without inheriting old assumptions that conflict with current reviewer-driven revision goals.

Current revision priority is:
- heterodimer-focused evidence,
- replicate MD (3 independent seeds),
- longer production runs (target >= 200 ns per replicate),
- MM-PBSA-first energetics under deadline constraints.

## Source Location
- Original dataset directory (kept intact): `../../yfeng494_data`

## What Was Copied

### `common/`
- `CPPF.itp`
- `CPPF.gro`
- `CPPF.mol2`
- `ions.mdp` (copied from `capsazepine+ChainA` as reusable ion-prep template)

### `alpha_template/`
- `topol.top`
- `em.mdp`
- `nvt.mdp`
- `npt.mdp`
- `md.mdp`
- `index.ndx`
- `posre_CPPF.itp`

### `tubb3_template/`
- `topol.top`
- `em.mdp`
- `nvt.mdp`
- `npt.mdp`
- `md.mdp`
- `index.ndx`
- `posre_CPPF.itp`

## Critical Limitations (Do Not Directly Reuse as Final Protocol)
1. Legacy systems are monomer-centric (`CPPF+alpha`, `CPPF+tubb3`) and are not the final physiological target for revision.
2. Legacy production `md.mdp` is configured for 50 ns, not the current >= 200 ns objective.
3. Legacy topology/style may contain standalone large `topol.top` patterns that are hard to maintain for replicate workflows.
4. Historical workflows used specific force-field/water choices that must be re-justified and locked for the revised manuscript.

## Recommended Use
- Use these files as templates for parameter blocks, index group conventions, and ligand includes.
- Build a new heterodimer-based project structure (`rep1/rep2/rep3`) from clean scripted setup.
- Keep all changes versioned and document each deviation from legacy templates in `METHOD_LOCK.md`.

## Next Step
Create a new execution runbook that maps:
- legacy templates -> revised heterodimer pipeline,
- one-off monomer flow -> replicate-aware production and analysis flow.
