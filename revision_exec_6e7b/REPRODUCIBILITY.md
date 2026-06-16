# 6E7B Reproducibility Checklist

**Status:** Complete (2026-06-15). Three × 200 ns replicates, cofactor-free protocol.

## Git (scripts + small artifacts)

| Item | Path | Status |
|------|------|--------|
| Prep & MD pipeline | `scripts/`, `prep/mdp/`, `prep/topol.*`, `prep/index.ndx` | ✅ |
| Input & Protenix | `input/` | ✅ |
| Analysis scripts | `analysis/run_full_analysis.sh`, `make_plots.py`, `rep1_convergence_check.sh` | ✅ |
| Analysis outputs | `analysis/summary.md`, `analysis/plots/`, `analysis/timeseries/`, `analysis/fel/` | ✅ |
| MM-PBSA | `analysis/mmpbsa/*.sh`, `*.in`, `6e7b_mmpbsa_summary.csv` | ✅ |
| Manuscript drafts | `RESPONSE_COMMENT_4.2_DRAFT.md`, `METHODS_6E7B_DRAFT.md`, `RESULTS_*.tex` | ✅ |
| Alignment provenance | `prep/alignment_summary.txt` (1.819 Å Cα RMSD) | ✅ |

## Hugging Face (large binaries)

Dataset: [HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers](https://huggingface.co/datasets/HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers)

| Item | Hub path | Upload script |
|------|----------|---------------|
| Production trajectories | `6e7b_rep{1,2,3}_md_200ns.xtc` | `huggingface_upload_6e7b_trajectories.sh --all` |
| Run inputs (TPR) | `6e7b_rep{1,2,3}_md_200ns.tpr` | `huggingface_upload_6e7b_reproducibility.sh --tpr` |
| Last-50ns subsampled | `6e7b_rep{1,2,3}_md_200ns_last50ns_sub.xtc` | `--last50ns` |
| Analysis bundle | `analysis_6e7b/{plots,timeseries,fel,summary.md}` | `--analysis` |
| Full script mirror | `revision_exec_6e7b/` (no `md/*.xtc`) | `--mirror` |
| Checksums | `HF_UPLOAD_SHA256SUMS_6e7b.txt` | auto-updated |

**Not on HF (regenerate locally):** PBC-corrected full trajectories (`analysis_6e7b/traj/rep*_pbc.xtc`, ~14 GB each) — run `analysis/run_full_analysis.sh` from raw `.xtc` + `.tpr`.

## Reproduce analysis from scratch

```bash
cd revision_exec_6e7b
# 1. Download from HF: 6e7b_rep{N}_md_200ns.{xtc,tpr} into md/rep{N}/
# 2. conda activate gmx-lite
bash analysis/run_full_analysis.sh          # → plots, XVG, summary
bash analysis/mmpbsa/recover_and_run_mmpbsa.sh  # → MM-PBSA CSV
```

## Key results (last 50 ns, 3 reps)

| Metric | 6E7B | 5IJ0 reference |
|--------|------|----------------|
| Backbone RMSD | 0.295 ± 0.021 nm | ~0.3–0.65 nm |
| min(CPPF–prot) | 0.203 ± 0.011 nm | ~0.19 nm |
| MM-PBSA ΔG | −27.82 ± 5.44 kcal/mol | −31.19 ± 4.04 kcal/mol |
| Verdict | **STABLE** | — |
