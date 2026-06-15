# Cursor Briefing: 6E7B MM-PBSA

## 任务

跑 6E7B 三 rep 的 MM-PBSA-GB，得到 ΔG_binding (kcal/mol)，与 5IJ0 main-text 的 −31.19 ± 4.04 kcal/mol 对比。

## 背景（必读）

- **5IJ0 main-text 协议**（必须完全照搬以保证可比性）：
  - `gmx_MMPBSA v1.5+`
  - GB-OBC2 (`igb=5`)
  - `intdiel=1.0`, `extdiel=78.5`, `temperature=298.15`
  - AMBER99SB + GAFF
  - last 50 ns × 3 reps，interval=100，~50 snapshots/rep
- 6E7B 用**完全相同**的 .in 文件结构（已写好：`mmpbsa_6e7b_last50ns_gb.in`）
- **唯一差异**：6E7B 是 200 ns 不是 400 ns，所以 startframe/endframe 是 15000-20000（last 50 ns of 200 ns @ 10ps）

## 环境准备

需要 conda env `mmpbsa_py311`（5IJ0 时已建过，可能要重建）：

```bash
conda env list | grep mmpbsa_py311
```

如果没有：

```bash
CONDA_SOLVER=classic conda create -n mmpbsa_py311 -c conda-forge -c bioconda \
  python=3.11 gmx_mmpbsa ambertools mpi4py -y

conda run -n mmpbsa_py311 which cpptraj
conda run -n mmpbsa_py311 gmx_MMPBSA -h
```

预计 5-10 分钟。

## 执行

```bash
cd /root/tubulin-cppf-md/revision_exec_6e7b
git pull   # 拉取脚本

# 先 smoke test 一个 rep（~5 分钟）确认链路通
MMPBSA_MODE=smoke REP=rep1 bash analysis/mmpbsa/run_6e7b_mmpbsa.sh

# 如果 smoke OK，跑全套 3 reps（每 rep ~30-60 分钟，3 reps 共 ~2-3 小时）
bash analysis/mmpbsa/run_6e7b_mmpbsa.sh 2>&1 | tee analysis/mmpbsa/full_run.log
```

**建议在 screen 里跑**：

```bash
screen -S mmpbsa
bash analysis/mmpbsa/run_6e7b_mmpbsa.sh 2>&1 | tee analysis/mmpbsa/full_run.log
# Ctrl+A D 退出
```

## 输出

完成后会生成：

```
analysis/mmpbsa/
├── work_rep1_full/rep1_last50ns_gb_FINAL_RESULTS.dat
├── work_rep1_full/rep1_last50ns_gb_perframe.csv
├── work_rep2_full/...
├── work_rep3_full/...
├── 6e7b_mmpbsa_summary.csv          ← 主输出！3 rep 汇总
└── full_run.log
```

**关键看 `6e7b_mmpbsa_summary.csv`**——格式和 5IJ0 的 `mmpbsa_summary.csv` 完全一样：

```csv
replicate,n_frames,delta_vdw_avg,delta_eel_avg,delta_egb_avg,delta_esurf_avg,delta_total_avg,delta_total_sd
rep1,51,...,-XX.XX,...
rep2,...
rep3,...
aggregate_across_reps,,mean_of_rep_avgs,sd_of_rep_avgs
ΔTOTAL,,-YY.YY,Z.ZZ                   ← 这个是要填进 manuscript 的数字
```

## 完成后报告

把以下三样贴给我：
1. **`6e7b_mmpbsa_summary.csv` 全文**
2. 任何 warning/error 的 log 节选
3. `ls analysis/mmpbsa/work_rep*/` 文件清单

## 常见问题

### Q: smoke test 报 "ERROR: gmx_path not found"
A: 检查 `mmpbsa_6e7b_last50ns_gb.in` 里 `gmx_path = ""`（空字符串）。脚本会把 gmx-lite 加进 PATH，gmx_MMPBSA 用 PATH 找 gmx。

### Q: cpptraj missing
A: 重建 mmpbsa_py311 env（见上面环境准备）

### Q: 报 "BOND = ******" 数值溢出
A: 这是已知现象（5IJ0 当时也遇到）。**不影响 ΔTOTAL**（bond 项在 Complex − Receptor − Ligand 相减时抵消）。继续跑。

### Q: 哪个 group 是 Protein / 哪个是 CPP？
A: 脚本会自动检测。如果失败，默认 Protein=1, Other=13（GROMACS 标准）。检查 `index.ndx`：
```bash
echo q | gmx make_ndx -f prep/em.gro -n prep/index.ndx -o /dev/null 2>&1 | grep -E "^ *[0-9]"
```

## 红线

- ❌ 不要改 `.in` 文件参数（igb/intdiel/extdiel/interval）——破坏 5IJ0 可比性
- ❌ 不要换 force field（必须 `oldff/leaprc.ff99SB,leaprc.gaff`）
- ❌ 不要省略 smoke test
- ✅ 在 screen 里跑（3 小时）

## 一句话

> 先跑 smoke (`REP=rep1 MMPBSA_MODE=smoke`)，OK 后在 screen 里跑全套 3 reps，跑完贴 `6e7b_mmpbsa_summary.csv`。
