# MD-trajectories-CPPF-tubulin-heterodimer-and-monomers

**Copy this file into the Hugging Face dataset “README” (Dataset card).**  
Source of truth in Git: `https://github.com/GITHUB_NAMESPACE/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference` — see `docs/DIMER_TRAJECTORY_NAMING.md`.

---

## What this dataset contains

All-atom GROMACS **production trajectories** (`.xtc`) for **CPPF** with **human tubulin**: **three heterodimer replicates** (extended to **~400 ns** per replicate) and **six monomer replicates** (~**200 ns** each: α/β × three replicates).  
Checksum sidecars: `HF_UPLOAD_SHA256SUMS_all.txt`, `HF_UPLOAD_SHA256SUMS_dimer_extensions.txt` (commit may split uploads across bundles).

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

## Human-readable aliases (optional, Git repo only)

The GitHub repo may contain **symlinks** such as `segment_0-300ns.xtc` → `md_200ns.xtc` under `revision_exec/rep*/prod/` (created by `revision_exec/scripts/create_dimer_trajectory_symlinks.sh`). **These symlinks are not required on the Hub**; they exist to avoid renaming canonical MD files that scripts and checkpoints rely on.

---

## Workflow & environments

- Scripts and topology: **same GitHub repo** as above.
- Conda / GROMACS environment notes: `docs/CONDA_ENVIRONMENTS.md`.

---

## License

MIT (same as repository; confirm here matches your publication requirement).
