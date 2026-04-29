# Hosting large MD trajectories on Hugging Face Hub

Use this when **Zenodo single-record quota** (~50 GB) is tight, or you prefer one Dataset repo for all `.xtc` files.

## Pros / cons (vs Zenodo)

| | Hugging Face Hub | Zenodo |
|--|------------------|--------|
| **Strength** | Large files via **Git LFS**; easy CLI; good bandwidth for downloads | **DOI** for citations; journals very used to it |
| **Citation** | Dataset card URL (and optional DOI if you later archive a snapshot elsewhere) | `doi.org/10.5281/zenodo...` |

Many papers cite **both**: Zenodo for a DOI’d bundle and HF for heavy files, or **HF + GitHub** with clear Data availability text—**check your journal’s author guide**.

## One-time setup

1. Account: [https://huggingface.co](https://huggingface.co)  
2. Token: **Settings → Access Tokens** (role with write). On the server:

   ```bash
   pip install -U "huggingface_hub[cli]"
   huggingface-cli login
   ```

## Create a Dataset repo

- New dataset: e.g. `YOURUSER/cppf-tubulin-md-trajectories` (choose **Dataset** type).  
- Or empty repo + add files.

## Upload from the HPC (no Git LFS clone of full history required)

From `tubulin-cppf-md` (after unique names are clear), you can upload file-by-file:

```bash
export HF_REPO="YOURUSER/cppf-tubulin-md-trajectories"
# example: one file (repeat for each xtc)
huggingface-cli upload "$HF_REPO" \
  revision_exec/monomer_alpha_rep1/prod/md_200ns.xtc \
  monomer_alpha_rep1_md_200ns.xtc --repo-type dataset
```

Use the **same unique names** as in `revision_exec/scripts/zenodo_upload_trajectories.sh` (`zenodo_remote_name` logic) so dimer/monomer reps do not collide.

For **many GB**, ensure the repo uses **Git LFS** for `*.xtc` (HF often tracks large files as LFS automatically on upload; if `git push` path is used, add `.gitattributes` with `*.xtc filter=lfs`).

## Dataset card (`README.md`)

In the repo root on HF, document:

- What each file is (replicate id, length, `dt`, GROMACS version)  
- Link to **GitHub** workflow and `docs/CONDA_ENVIRONMENTS.md`  
- SHA256 list (same as `ZENODO_UPLOAD_SHA256SUMS_*.txt` or a dedicated `SHA256SUMS`)

## Practical split strategy (recommended hybrid)

1. **Zenodo record A — monomers** (~22 GiB): DOI for “monomer bundle”.  
2. **Zenodo record B — dimers** OR **Hugging Face — dimers** (~57 GiB): if B hits quota, put dimers on **HF** and cite the dataset URL in the paper.

Script:

```bash
bash revision_exec/scripts/zenodo_upload_trajectories.sh --bundle monomer
bash revision_exec/scripts/zenodo_upload_trajectories.sh --bundle dimer   # if quota allows
```
