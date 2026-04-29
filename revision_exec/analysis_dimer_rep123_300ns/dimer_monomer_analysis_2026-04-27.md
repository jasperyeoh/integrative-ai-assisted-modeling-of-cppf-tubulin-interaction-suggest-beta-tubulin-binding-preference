# Dimer + Monomer Analysis (2026-04-27)

> **Note (2026-04-29):** 最新运行排期与 GPU 快照见仓库根目录 [`docs/pregress.md`](../../docs/pregress.md)。下文「Dimer Extension Decision」中曾建议优先延长 rep3；经平行试验一致性讨论，项目改为 **三条 dimer 同步延长至 350 ns（先行）**。本节 **200–300 ns 数值结论** 仍有效，未改原始分析。

## Scope
- Dimer: `rep1`, `rep2`, `rep3` analyzed on the 200-300 ns window with the same metrics used for extension decisions.
- Monomer: current available trajectories were assessed for run status and quick structural stability metrics.

## Dimer Results (200-300 ns)

### Replicate summaries
- `rep1`
  - Backbone RMSD: mean `1.4743` nm; last50ns mean `2.6522` nm
  - Protein-ligand contacts: mean `151.0`; 200-250 vs 250-300 ns shift `1.2%`
  - Protein-ligand min distance: mean `0.2070` nm; last50ns mean `0.2086` nm
  - Rolling 20 ns RMSD stability (tail ~100 ns std): `0.2603`
- `rep2`
  - Backbone RMSD: mean `3.8386` nm; last50ns mean `3.1164` nm
  - Protein-ligand contacts: mean `152.0`; 200-250 vs 250-300 ns shift `1.2%`
  - Protein-ligand min distance: mean `0.2063` nm; last50ns mean `0.2061` nm
  - Rolling 20 ns RMSD stability (tail ~100 ns std): `0.2531`
- `rep3`
  - Backbone RMSD: mean `3.4836` nm; last50ns mean `2.3977` nm
  - Protein-ligand contacts: mean `173.7`; 200-250 vs 250-300 ns shift `1.3%`
  - Protein-ligand min distance: mean `0.1950` nm; last50ns mean `0.1966` nm
  - Rolling 20 ns RMSD stability (tail ~100 ns std): `0.5487`

### Cross-replicate interpretation
- **Binding-interface stability is consistent** across all three dimers:
  - min distance stays near `~0.20 nm`
  - contact distributions show very small late-window drift (`~1.2-1.3%` between the last two 50 ns blocks)
- **Conformational convergence is mixed**:
  - `rep1` and `rep2` rolling RMSD tails are relatively stable (`~0.25-0.26`)
  - `rep3` still shows larger slow motion (`0.5487`), indicating incomplete conformational settling

## Dimer Extension Decision (to 400 ns)
- **Recommendation**: extend to 400 ns **selectively**.
  - Extend `rep3` (high priority): yes, to reduce residual RMSD drift and verify if a stable basin is reached.
  - Extend `rep1`/`rep2` (lower priority): optional; current contact/min-distance metrics already support stable binding behavior.
- **If compute budget allows only one extension**, use `rep3` first.

## Monomer Current Usage Status

### Runtime / resource usage snapshot
- Active MD jobs:
  - `monomer_alpha_rep1/prod/md_200ns` running on GPU
  - `monomer_alpha_rep2/prod/md_200ns` running on GPU
- GPU occupancy snapshot:
  - GPU0 util ~`54%`, memory ~`501 MiB / 81920 MiB`
  - GPU1 util ~`56%`, memory ~`501 MiB / 81920 MiB`
- `monomer_beta_rep1` is complete (200 ns trajectory available).

### Monomer trajectory progress (`gmx check`)
- `monomer_alpha_rep1`: `9202` frames, timestep `10 ps` => trajectory currently to ~`92.0 ns`
- `monomer_alpha_rep2`: `3279` frames, timestep `10 ps` => trajectory currently to ~`32.8 ns`
- `monomer_beta_rep1`: `20001` frames, timestep `10 ps` => complete `200.0 ns`

## Monomer Quick Structural Analysis (current available data)
- `monomer_alpha_rep1` (0-92.25 ns)
  - Backbone RMSD mean `0.4799` nm (sd `0.1209`), last `0.6068`
  - Protein Rg mean `2.2210` nm (sd `0.0244`), last `2.2061`
- `monomer_alpha_rep2` (0-33.13 ns)
  - Backbone RMSD mean `0.2452` nm (sd `0.0480`), last `0.2452`
  - Protein Rg mean `2.2615` nm (sd `0.0207`), last `2.2777`
- `monomer_beta_rep1` (0-200 ns)
  - Backbone RMSD mean `0.4225` nm (sd `0.1250`), last `0.2802`
  - Protein Rg mean `2.2060` nm (sd `0.0249`), last `2.1583`

## Monomer Interpretation
- Existing monomer data indicate no obvious global unfolding signal in current windows (Rg fluctuations are tight in all three).
- `monomer_beta_rep1` appears structurally stable over full 200 ns.
- `monomer_alpha_rep1/2` are still in-progress; any final between-replicate conclusion should wait until both reach a comparable window (at least 150-200 ns).

## Practical Next Steps
- Finish `monomer_alpha_rep2` to **200 ns**, then run the same monomer metrics on a matched late window (e.g., last 50 ns) across alpha replicates.
- Prepare and launch **monomer α rep3** and **β rep2/rep3** so each chain has **≥3** parallel productions.
- For dimers: complete **`rep1` → 350 ns**, then extend **`rep2` and `rep3`** to **350 ns** on free GPUs; re-use `run_rep_analysis.sh` / `summarize_xvgs.py` on the new late window (e.g., 300–350 ns) with the same criteria.
