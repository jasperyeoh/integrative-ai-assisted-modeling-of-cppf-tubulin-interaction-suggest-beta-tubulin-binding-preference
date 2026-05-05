# Hugging Face Hub — MD trajectories (primary archive)

Large `.xtc` files (~80 GiB total) fit comfortably on the Hub (LFS). Use this as the **main** public archive; you can still add a small **Zenodo** entry later if the journal insists on a DOI for a *manifest* or subset.

## Let Cursor / an agent upload automatically (safe pattern)

The agent runs **terminal commands on your server**. It **cannot** use your Hugging Face password interactively, but it **can** run uploads if **you have already authenticated on that same machine**:

1. **On the server (SSH), once:**  
   `hf auth whoami` → should print your user (e.g. `HUB_NAMESPACE`).  
   If not: `hf auth login` and complete the browser/token flow **without pasting the token into chat**.

2. **Optional:** put a write token in `~/.huggingface_token` (chmod 600). Never commit it.

3. **Tell the agent your dataset id** (public info, not a secret), e.g.  
   `HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers`  
   Example: `export HF_DATASET_REPO='HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers'`

4. The agent runs `revision_exec/scripts/huggingface_upload_trajectories.sh` (often under `nohup` for multi-hour uploads).

There is **no** way to safely paste a **secret token** into the chat for the agent to “remember”; always use **server-side login** or a **local file** the agent reads only by path, never by pasting the secret in messages.

See also `revision_exec/scripts/HF_DATASET_REPO.env.example`.

## 1. One-time setup

```bash
pip install -U "huggingface_hub[cli]"
huggingface-cli login
# or put a read/write token in ~/.huggingface_token (chmod 600), same as GitHub-style HF tokens
```

Create an empty **Dataset** repo on [huggingface.co/new-dataset](https://huggingface.co/new-dataset), or from the CLI:

```bash
export HF_TOKEN='hf_...'   # optional if you already ran huggingface-cli login
huggingface-cli repo create YourUser/cppf-tubulin-md-trajectories --repo-type dataset --exist-ok
```

## 2. Upload from the HPC (recommended)

Script: `revision_exec/scripts/huggingface_upload_trajectories.sh`

```bash
cd /path/to/tubulin-cppf-md
export HF_DATASET_REPO='HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers'

# preview
bash revision_exec/scripts/huggingface_upload_trajectories.sh --dry-run
bash revision_exec/scripts/huggingface_upload_trajectories.sh --bundle monomer --dry-run
bash revision_exec/scripts/huggingface_upload_trajectories.sh --bundle dimer --dry-run

# optional: create repo on Hub if needed
bash revision_exec/scripts/huggingface_upload_trajectories.sh --create-repo

# upload (use tmux/screen)
bash revision_exec/scripts/huggingface_upload_trajectories.sh --bundle all
# or split:
bash revision_exec/scripts/huggingface_upload_trajectories.sh --bundle monomer
bash revision_exec/scripts/huggingface_upload_trajectories.sh --bundle dimer
```

Files appear under **unique names** (e.g. `dimer_rep1_md_200ns.xtc`, `monomer_alpha_rep2_md_200ns.xtc`). Each upload is a separate Hub commit.

**Dimer first segment:** the Hub object `*_md_200ns.xtc` follows historic **`md_200ns.xtc`** basenames on disk; that file can span **0–300 ns** before the `md_350ns.part*` segments (see [`docs/DIMER_TRAJECTORY_NAMING.md`](DIMER_TRAJECTORY_NAMING.md)). Renaming on-disk production files would break `mdrun`/scripts; optional symlinks: `revision_exec/scripts/create_dimer_trajectory_symlinks.sh`.

## 3. Dataset card (`README.md` on the Hub)

On the dataset page → **Files** → edit **README.md**. Include:

- Short description of CPPF + tubulin systems  
- Table: filename → replicate, length (ns), GROMACS version  
- Link to **this GitHub repo** and `docs/CONDA_ENVIRONMENTS.md`  
- Mention `HF_UPLOAD_SHA256SUMS_{monomer,dimer,all}.txt` in the repo root on the Hub  

## 4. Paper (Data availability)

Example wording:

> All-atom MD trajectories are publicly available on Hugging Face at `https://huggingface.co/datasets/YourUser/cppf-tubulin-md-trajectories`. Workflow, topology, and analysis scripts are in `https://github.com/...`.

If the journal **requires a DOI**, you can still deposit a **small Zenodo record** (checksums + README + link to HF) or ask the editor whether a **citable HF dataset** is acceptable.

## 5. Zenodo vs HF (quick)

| | Hugging Face | Zenodo |
|--|--------------|--------|
| **~80 GiB trajectories** | Straightforward | Often needs **split records** or quota |
| **Citation** | Dataset URL (+ DOI optional elsewhere) | **DOI** by default |

See `docs/ZENODO_UPLOAD_SERVER.md` if you use Zenodo for a subset or second copy.

## 6. Operational logs (what was uploaded, when, from which host)

All upload and polling transcripts intended for **provenance and debugging** live under `revision_exec/logs/`. They are safe to commit at typical sizes (individual files are usually well below GitHub’s hard limits; the largest HF nohup log may be ~10–15 MB—still acceptable if you need a paper trail in git).

**Start here:** [`revision_exec/logs/HF_AND_PIPELINE_LOG_INDEX.md`](../revision_exec/logs/HF_AND_PIPELINE_LOG_INDEX.md) — tables for:

- `hf_upload*.log`, `hf_poll*.log` — Hub CLI sessions  
- `zenodo_upload_nohup.log` — Zenodo  
- `rep*` / `monomer_*` / `auto_*` — MD production and chained extensions  

When you run a new upload, prefer a **descriptive filename** and add a row to that index so reviewers (and your future self) can tie Hub commits to local logs.

**Figure format for the paper:** revision plotting defaults to **TIFF LZW @ 300 dpi**; see [`docs/PLOS_COMPBIOL_FIGURES.md`](PLOS_COMPBIOL_FIGURES.md).

## 7. Mirror the rest of `revision_exec/` (no duplicate prod `.xtc`)

Trajectory segments in each `*/prod/*.xtc` are already uploaded by `revision_exec/scripts/huggingface_upload_trajectories.sh` (flat filenames at the dataset root). To push **everything else** under `revision_exec/` with the **same folder layout** on the Hub (tpr, gro, edr, logs, `input/`, `prep/`, analysis outputs, `analysis_revision/work/*.xtc`, etc.) **without** re-uploading those production trajectories:

```bash
cd /path/to/tubulin-cppf-md
export HF_DATASET_REPO='HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers'

bash revision_exec/scripts/huggingface_upload_revision_exec_mirror.sh --dry-run
bash revision_exec/scripts/huggingface_upload_revision_exec_mirror.sh --upload
# optional: one top-level folder only
bash revision_exec/scripts/huggingface_upload_revision_exec_mirror.sh --upload --only input
```

The script passes `--exclude '**/prod/**/*.xtc'` to `hf upload`. Remote paths default to `revision_exec/<relative path>` (`HF_REVISION_MIRROR_PREFIX` overrides the `revision_exec` segment).

**Logs:** `revision_exec/analysis_revision/work/` is gitignored. Copy `export_all_9sys.log` into `revision_exec/logs/analysis_revision_export_all_9sys_SNAPSHOT_<timestamp>.log` for GitHub (see `revision_exec/logs/HF_AND_PIPELINE_LOG_INDEX.md` § Revision export); the mirror script will also upload `analysis_revision/work/` to the Hub if you run a full mirror.
