# Large MD outputs vs Git / GitHub

**Why not everything is in `git push`:** GitHub rejects blobs **> ~100 MiB**. Your production trajectories are multi‑GB (e.g. `md_200ns.xtc` ≈ 8–20 GiB per run), so they **cannot** live in a normal GitHub repo without **Git LFS** (quota/cost) or an external store (HPC disk, Zenodo, S3, etc.).

**What *is* committed:** All `revision_exec` files **under 100 MiB** per file (logs, `.edr`, `.tpr`, `.cpt`, `.gro`, `.xvg`, `.pid`, check/summary `.txt`, small subsampled `.xtc`/`.trr`, figures, etc.).

**Excluded (see `revision_exec/LARGE_FILES_NOT_IN_GIT.txt`):** Trajectories and coordinate files **≥ 100 MiB** (mostly `prod/*.xtc`, long `nvt/npt.trr`, extension chunks like `md_350ns.part*.xtc`).

**If you need trajectories on GitHub:** use [Git LFS](https://git-lfs.github.com/) with `git lfs track "*.xtc"` (expect **large** storage/bandwidth), or publish archives elsewhere and cite URLs in this repo.
