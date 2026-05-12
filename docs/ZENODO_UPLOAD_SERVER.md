# Zenodo upload from the HPC server (trajectories)

Large `.xtc` files are not in GitHub; upload them with the REST API from the machine that already holds the files.

## 1. Token (keep secret)

1. If a token was ever pasted in chat, **revoke it** on Zenodo and create a **new** token with scopes **`deposit:write`** and **`deposit:actions`**.
2. On the server only:

```bash
printf '%s\n' 'PASTE_NEW_TOKEN_HERE' > ~/.zenodo_token
chmod 600 ~/.zenodo_token
```

Or for a single session: `export ZENODO_TOKEN='...'`

**Do not** commit `~/.zenodo_token` or put the token in the repository.

## 2. What gets uploaded (default)

Script: `revision_exec/scripts/zenodo_upload_trajectories.sh`

Each replicate keeps **one main production** `.xtc` (plus optional extension segments). On Zenodo they are stored under **unique names** (e.g. `monomer_alpha_rep1_md_200ns.xtc`, `dimer_rep2_md_200ns.xtc`) so files are **not** overwritten.

Default files (paths relative to repo root `tubulin-cppf-md/`):

- `revision_exec/monomer_{alpha_rep1,alpha_rep2,beta_rep1}/prod/md_200ns.xtc`
- `revision_exec/rep{1,2,3}/prod/md_200ns.xtc`
- `revision_exec/rep1/prod/md_350ns.part0004.xtc`

When you finish **6 monomer** + **3 dimer** replicates, add the three new monomer paths to `DEFAULT_RELS` and re-run (or make a **second Zenodo record**) — expect **9** production trajectories **+** any `md_350ns` / extension parts.

Also uploads **`revision_exec/ZENODO_UPLOAD_SHA256SUMS.txt`** (checksums; names match Zenodo keys).

To change the file list, edit the `DEFAULT_RELS` array in the script.

### Quota (50 GB / record)

If the total size of one upload **exceeds** the Zenodo quota for that record, split into **two deposits** (e.g. dimers in one, monomers in another) or contact Zenodo. **Hugging Face Hub** (Dataset repo + `git lfs`) is a workable alternative for very large static files; cite the HF URL in the paper if the journal allows URLs without DOI (many accept both; check author guidelines).

## 3. Split uploads (recommended)

| Bundle | Approx. size | Typical Zenodo fit |
|--------|----------------|---------------------|
| `--bundle monomer` | ~22 GiB | Usually **OK** under 50 GB |
| `--bundle dimer` | ~57 GiB | **May exceed** 50 GB/record → use **Hugging Face** for dimers, or **three separate Zenodo records** (one per replicate), or request a quota increase |
| `--bundle all` | ~79 GiB | Usually **too large** for one record |

See also `docs/HUGGINGFACE_DATASET.md`.

## 4. Dry run

From repo root:

```bash
cd /path/to/tubulin-cppf-md
bash revision_exec/scripts/zenodo_upload_trajectories.sh --dry-run
bash revision_exec/scripts/zenodo_upload_trajectories.sh --bundle monomer --dry-run
bash revision_exec/scripts/zenodo_upload_trajectories.sh --bundle dimer --dry-run
```

## 5. Upload (draft)

Creates a **new** Zenodo draft, sets metadata, uploads checksums + trajectories for that bundle.

```bash
bash revision_exec/scripts/zenodo_upload_trajectories.sh --bundle monomer
bash revision_exec/scripts/zenodo_upload_trajectories.sh --bundle dimer
# or combined (only if quota allows):
bash revision_exec/scripts/zenodo_upload_trajectories.sh --bundle all
```

Use **`tmux` or `screen`**; multi‑GiB uploads can take a long time. If a `curl` fails, fix the network and re‑run **only after** handling the half‑empty draft on the Zenodo website (or create a fresh draft and adjust the script to skip `POST` if you reuse an existing deposition—by default each run creates a new deposition).

## 6. Publish (DOI)

After checking the draft in the browser:

- Either click **Publish** on Zenodo, or  
- Run with **`--publish`** (creates deposition, uploads, then publishes in one go—only if you do not need a manual review step).

```bash
bash revision_exec/scripts/zenodo_upload_trajectories.sh --publish
```

## 7. Dataset DOI + GitHub

Put the Zenodo **DOI** in `README.md` when available. Link to this GitHub repo for code, small inputs, and `docs/CONDA_ENVIRONMENTS.md`.
