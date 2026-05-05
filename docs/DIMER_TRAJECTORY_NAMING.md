# Dimer production trajectories — filenames vs. time coverage

> **中文摘要：** 二聚体第一条轨迹文件名仍是 `md_200ns.xtc`，但体内帧可以持续到 **~300 ns**；**200–300 ns 并未缺失**，就在该文件中。延伸段在 `md_350ns.part*` / `md_400ns.part*`。单体 `md_200ns.xtc` 仍为约 **200 ns** 生产段。  
> **HF dataset README:** paste [`revision_exec/HF_DATASET_CARD_README.md`](../revision_exec/HF_DATASET_CARD_README.md) into the Hugging Face dataset card so下载者不会误以为缺段。

**There is no gap from 200 ns to 300 ns** for the heterodimer: that interval is stored in the **same first `.xtc`** (`md_200ns.xtc`), despite the filename.

GROMACS keeps the **first output basename** when you **continue** a run (e.g. `-append` or a new part with the same `deffnm` prefix). So on disk the first segment is still called `md_200ns.xtc` even after the simulation has been extended **past 200 ns** into the same file.

## Segment map (this project)

| Approx. simulation time | `rep1/prod` on-disk file | `rep2` / `rep3` on-disk file |
|-------------------------|--------------------------|------------------------------|
| **0 → 300 ns** | `md_200ns.xtc` | `md_200ns.xtc` |
| **300 → 350 ns** | `md_350ns.part0004.xtc` | `md_350ns.part0003.xtc` |
| **350 → 400 ns** | `md_400ns.part0005.xtc` | `md_400ns.part0004.xtc` |

**There is no missing 200–300 ns window:** that range is inside **`md_200ns.xtc`** (misleading name). The part numbers differ between rep1 and rep2/3 because of how extensions were started (`-noappend` part indices).

**Monomers** use `md_200ns.xtc` for a **200 ns** production window; the “long first file” issue applies to **dimer** continuations only.

## Human-readable aliases (symlinks, optional)

Do **not** rename the canonical files used by `mdrun` and `run_export_all.sh` unless you are prepared to update every script and re-link checkpoints.

Instead, run:

```bash
bash revision_exec/scripts/create_dimer_trajectory_symlinks.sh
```

That creates **same-directory symlinks** such as `segment_0-300ns.xtc` → `md_200ns.xtc` under each `rep{1,2,3}/prod/`. Original names remain.

## Hugging Face

Remote objects keep **stable names** (e.g. `dimer_rep1_md_200ns.xtc`) so existing citations and checksum files stay valid. For the dataset **README** on the Hub, copy the table above and point readers to this file in the GitHub repo.
