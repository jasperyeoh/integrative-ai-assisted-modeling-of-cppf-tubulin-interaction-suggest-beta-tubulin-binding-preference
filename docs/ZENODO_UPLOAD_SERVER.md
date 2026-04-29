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

Default files (paths relative to repo root `tubulin-cppf-md/`):

- `revision_exec/monomer_{alpha_rep1,alpha_rep2,beta_rep1}/prod/md_200ns.xtc`
- `revision_exec/rep{1,2,3}/prod/md_200ns.xtc`
- `revision_exec/rep1/prod/md_350ns.part0004.xtc`

Also uploads **`revision_exec/ZENODO_UPLOAD_SHA256SUMS.txt`** (checksums for those files).

To change the file list, edit the `DEFAULT_RELS` array in the script.

## 3. Dry run

From repo root:

```bash
cd /path/to/tubulin-cppf-md
bash revision_exec/scripts/zenodo_upload_trajectories.sh --dry-run
```

## 4. Upload (draft)

Creates a **new** Zenodo draft, sets metadata, uploads checksums + all trajectories.

```bash
bash revision_exec/scripts/zenodo_upload_trajectories.sh
```

Use **`tmux` or `screen`**; multi‑GiB uploads can take a long time. If a `curl` fails, fix the network and re‑run **only after** handling the half‑empty draft on the Zenodo website (or create a fresh draft and adjust the script to skip `POST` if you reuse an existing deposition—by default each run creates a new deposition).

## 5. Publish (DOI)

After checking the draft in the browser:

- Either click **Publish** on Zenodo, or  
- Run with **`--publish`** (creates deposition, uploads, then publishes in one go—only if you do not need a manual review step).

```bash
bash revision_exec/scripts/zenodo_upload_trajectories.sh --publish
```

## 6. Paper + GitHub

Put the Zenodo **DOI** in the manuscript *Data availability* and in `README.md`. Link to this GitHub repo for code, small inputs, and `docs/CONDA_ENVIRONMENTS.md`.
