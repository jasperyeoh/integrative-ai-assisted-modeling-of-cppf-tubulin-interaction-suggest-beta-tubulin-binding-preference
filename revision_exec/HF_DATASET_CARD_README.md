# MD-trajectories-CPPF-tubulin-heterodimer-and-monomers

**Copy this file into the Hugging Face dataset “README” (Dataset card).**  
Source of truth in Git: `https://github.com/GITHUB_NAMESPACE/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference` — see `docs/DIMER_TRAJECTORY_NAMING.md`.

---

## What this dataset contains

All-atom GROMACS **production trajectories** (`.xtc`) for **CPPF** with **human tubulin**:

- **5IJ0 / soluble curved dimer (main text):** three heterodimer replicates extended to **~400 ns** each.
- **6E7B / lattice straight dimer (supplementary):** three replicates × **200 ns** each (no cofactors; comparable to main-text 5IJ0 setup).
- **Monomers:** six replicates (~**200 ns** each: α/β × three replicates).

Checksum sidecars: `HF_UPLOAD_SHA256SUMS_all.txt`, `HF_UPLOAD_SHA256SUMS_dimer_extensions.txt`, `HF_UPLOAD_SHA256SUMS_6e7b.txt` (uploads may be split across bundles).

---

## Important: dimer files named `*_md_200ns.xtc` are **not** “only 0–200 ns”

**There is no missing 200–300 ns segment in the dimer data.**

GROMACS often **keeps the first output basename** when the run is **continued** (checkpoint / append). The on-disk file is still called `md_200ns.xtc`, but the **trajectory inside can run from ~0 to ~300 ns** for the dimer. The next time windows are stored in the **separate** part files below.

| Approx. time (dimer) | What to use on this Hub (replicate in filename) | Typical on-disk name in the GitHub `revision_exec` tree |
|----------------------|--------------------------------------------------|--------------------------------------------------------|
| **~0 → 300 ns** | `dimer_rep{1,2,3}_md_200ns.xtc` | `rep*/prod/md_200ns.xtc` (name is **legacy**; **content is not “200 ns only”**) |
| **~300 → 350 ns** | `dimer_rep1_md_350ns.part0004.xtc` or `dimer_rep{2,3}_md_350ns.part0003.xtc` | `md_350ns.part0004` (rep1) or `md_350ns.part0003` (rep2/3) |
| **~350 → 400 ns** | `dimer_rep1_md_400ns.part0005.xtc` or `dimer_rep{2,3}_md_400ns.part0004.xtc` | matching `md_400ns.part*` |

Part indices **differ between rep1 and rep2/3** because of how extensions were launched (`-noappend`, run numbering).

**Monomers:** `monomer_*_md_200ns.xtc` correspond to **~200 ns** production per replicate (standard naming matches length).

---

## 6E7B supplementary trajectories (lattice straight state)

Reviewer-requested control matching the **6E7B** microtubule-lattice-related conformation. **No GTP/GDP/Mg²⁺** in the MD system (same cofactor-free protocol as main-text 5IJ0 for direct comparability).

| Replicate | Hub filename | Typical on-disk path (`revision_exec_6e7b`) |
|-----------|--------------|-----------------------------------------------|
| rep1 | `6e7b_rep1_md_200ns.xtc` | `md/rep1/md_200ns.xtc` |
| rep2 | `6e7b_rep2_md_200ns.xtc` | `md/rep2/md_200ns.xtc` |
| rep3 | `6e7b_rep3_md_200ns.xtc` | `md/rep3/md_200ns.xtc` |

**Paired run inputs (required to re-analyze `.xtc`):**

| Replicate | Hub filename | On-disk path |
|-----------|--------------|--------------|
| rep1 | `6e7b_rep1_md_200ns.tpr` | `revision_exec_6e7b/md/rep1/md_200ns.tpr` |
| rep2 | `6e7b_rep2_md_200ns.tpr` | `revision_exec_6e7b/md/rep2/md_200ns.tpr` |
| rep3 | `6e7b_rep3_md_200ns.tpr` | `revision_exec_6e7b/md/rep3/md_200ns.tpr` |

**Last-50 ns subsampled trajectories** (51 frames, MM-PBSA / lightweight re-analysis):  
`6e7b_rep{N}_md_200ns_last50ns_sub.xtc`

**Analysis outputs** (plots, timeseries XVG, FEL, PBC-corrected traj): `analysis_6e7b/` on this Hub.  
**Scripts & topology mirror:** `revision_exec_6e7b/` on this Hub (production `.xtc` also at flat root names).

Upload: `revision_exec/scripts/huggingface_upload_6e7b_trajectories.sh --all` then  
`revision_exec/scripts/huggingface_upload_6e7b_reproducibility.sh --all`

---

## Human-readable aliases (optional, Git repo only)

The GitHub repo may contain **symlinks** such as `segment_0-300ns.xtc` → `md_200ns.xtc` under `revision_exec/rep*/prod/` (created by `revision_exec/scripts/create_dimer_trajectory_symlinks.sh`). **These symlinks are not required on the Hub**; they exist to avoid renaming canonical MD files that scripts and checkpoints rely on.

---

## Workflow & environments

- Scripts and topology: **same GitHub repo** as above.
- Conda / GROMACS environment notes: `docs/CONDA_ENVIRONMENTS.md`.

---

## License

MIT (same as repository; confirm here matches your publication requirement).
