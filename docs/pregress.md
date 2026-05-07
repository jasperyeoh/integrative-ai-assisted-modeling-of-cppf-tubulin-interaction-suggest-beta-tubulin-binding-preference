## 2026-04-16
- **建立 MD 修回主线框架**：锁定 heterodimer（5IJ0）+ 3×replicates + 200 ns + MM-PBSA 作为回应 reviewer 的主证据链。
- **锁定 CPPF 结构来源**：PubChem CID `763830`，并记录 Canonical SMILES / InChIKey；下载 3D conformer SDF 用于后续参数化一致性。
- **建立参数化/准备环境**：创建 `mdprep` conda 环境并安装 AmberTools/OpenBabel/RDKit/ParmEd/ACPYPE。
- **补齐开源 QM**：在 `mdprep` 安装 Psi4（`psi4 1.10`），使 RESP2 流程不依赖 Gaussian/ORCA。
- **结构准备自动化**：完成 pose1 + 5IJ0 对齐与清理脚本链路，生成并验证 `complex_start_clean.pdb`；将 ligand 统一命名为 `CPP`、链 `C`。
- **CPPF 临时拓扑打通管线**：用 ACPYPE 生成 CPPF 的 GAFF2 拓扑（临时 BCC 电荷用于 gate），并将“带氢配体”刚体拟合回 pose 位点，完成溶剂化/加离子/EM gate 跑通。
- **吸收外部反馈并升级 cofactor 策略**：否决 “GTP/GDP 用 GAFF2 + gas charge 当主路线”，转为 **reviewer-proof** 的权威参数路线：
  - 下载 Bryce/AMBER Parameter Database 的 `GTP.prep`、`GDP.prep`、`frcmod.phos`（polyphosphate）。
  - 发现 residue 名大小写与 atom-name 记号不一致（prime vs star），新增预处理脚本：
    - `rename_resname_case.py`：将 `GTP/GDP` → `gtp/gdp`
    - `rename_nucleotide_prime_to_star.py`：对需要的残基做 prime→star
  - **tleap gate 验证通过**：加载 `GTP.prep/GDP.prep + frcmod.phos` 后，`does not have a type` 消失，且总电荷检查为 **-5**（与 GTP(-4)+GDP(-3)+Mg2+(+2)一致）。
- **整理项目工作区结构**：将 MD 工作区统一为 `tubulin-cppf-md/`，并按 `docs/ inputs/ work/ legacy/` 重新归档；关键执行入口（`revision_exec/`、`cppf/`、`legacy_templates/`）为真实目录（无软链接）。
- **Phase 1.5 gate 点火前静态自检（通过）**：
  - `grompp` 预检确认 **EM/NVT/NPT 输入拓扑自洽**（无 Fatal error）。
  - 修复 NVT/NPT 的关键依赖：
    - 生成并补齐 `revision_exec/input/index.ndx`（创建 `Protein_CPP`；将配体 group 从 `MOL` 重命名为 `CPP` 以匹配 `energygrps`）。
    - 恢复蛋白 `posre_Protein_chain_{A,B}.itp` 到 `revision_exec/prep/` 以满足链 `.itp` 的相对 include。
    - 在 `revision_exec/prep/gate_topol.top` 中加入 `CPPF` 的 `posre_CPPF.itp`（`#ifdef POSRES`）以提升 NVT/NPT 稳定性。
- **Phase 1.5 gate（rep1）实跑完成**：
  - **EM 完成并收敛**：`revision_exec/rep1/em/em.log` 显示 `Potential Energy = -2.8607960e+06`，`Maximum force = 9.6687445e+02 (<1000)`。
  - **NVT 完成**：`revision_exec/rep1/nvt/nvt.log` 运行至 `step 50000 (100 ps)`，无 Fatal error。
  - **NPT 完成**：`revision_exec/rep1/npt/npt.log` 运行至 `step 50000 (100 ps)`，无 Fatal error。
  - **关键输出已落盘**：`revision_exec/rep1/npt/{npt.gro,npt.cpt,npt.edr,npt.log,npt.tpr}`。
- **Phase 1.5 gate（rep2）完成**：
  - **EM 完成并收敛**：与 rep1 同量级（`Epot ~ -2.86e6`，`Fmax < 1000`）。
  - **NVT 完成**：`revision_exec/rep2/nvt/` 产出 `nvt.gro`、`nvt.cpt` 等。
  - **NPT 完成**：`revision_exec/rep2/npt/npt.log` 正常结束（`Finished mdrun`）。
- **Phase 1.5 gate（rep3）完成**：
  - **EM 完成并收敛**：`Potential Energy = -2.8607960e+06`，`Maximum force = 9.6687445e+02 (<1000)`。
  - **NVT 完成**：`revision_exec/rep3/nvt/` 产出 `nvt.gro`、`nvt.cpt` 等。
  - **NPT 完成**：`revision_exec/rep3/npt/` 产出 `npt.gro`、`npt.cpt`、`npt.log`，`mdrun` 正常结束。
- **阶段里程碑**：`rep1/rep2/rep3` 的 Phase 1.5 gate（EM+NVT+NPT）已全部跑通，可进入 200 ns production。

## 2026-04-17
- **RESP2 阻塞已解除（方案1落地）**：安装并验证 `Multiwfn`（noGUI 版），建立 `Psi4 + Multiwfn` 可执行链路。
- **CPPF RESP2(0.5) 电荷已产出**：
  - `revision_exec/input/ligand/charges_gas.txt`
  - `revision_exec/input/ligand/charges_water.txt`
  - `revision_exec/input/ligand/charges_resp2_05.txt`
  - 原子数 `n=32`，总电荷近似 `0`（数值误差级别）。
- **RESP2 拓扑已生成并入库**：
  - `revision_exec/input/ligand/CPPF_RESP2.mol2`
  - `revision_exec/input/ligand/CPPF_RESP2.itp`
  - `revision_exec/input/ligand/CPPF_RESP2.gro`
  - `revision_exec/input/ligand/posre_CPPF_RESP2.itp`
- **主拓扑切换到 RESP2**：`revision_exec/prep/gate_topol.top` 已把配体 include 从 BCC 版本替换为 `CPPF_RESP2.itp`，并切换对应 `posre` 与 `[molecules]` 的配体名。
- **预检状态**：已完成 RESP2 版本的 `grompp` 预检查（EM），下一步执行短回归 gate（EM + NVT + NPT）确认动力学稳定后启动 200 ns production。
- **RESP2 回归 gate（rep1，短程）完成**：
  - 路径：`revision_exec/rep1_resp2_gate/`
  - **EM 收敛**：`Potential Energy = -2.8656418e+06`，`Maximum force = 8.8533337e+02 (<1000)`。
  - **NVT（20 ps）完成**：`step 10000` 写 checkpoint 并正常 `Finished mdrun`。
  - **NPT（20 ps）完成**：`step 10000` 写 checkpoint 并正常 `Finished mdrun`。
  - 结论：RESP2 拓扑替换后体系可稳定通过短程回归 gate，可进入 200 ns 生产阶段。
- **dimer 生产阶段已启动（RESP2）**：
  - 新增生产参数文件：`revision_exec/input/mdp/md_prod_200ns.mdp`（`dt=0.002`, `nsteps=100000000`，目标 200 ns）。
  - 已生成 `rep1/rep2/rep3` 的生产 `tpr`：`revision_exec/rep{1,2,3}/prod/md_200ns.tpr`。
  - `rep1` 已启动正式 production：`revision_exec/rep1/prod/md_200ns.*` 持续写出（`log/edr/xtc` 已增长）。
- **GPU 利用修复（关键）**：
  - 发现原 `gmx-lite` 为 OpenCL 构建，`mdrun` 提示 GPU 检测失败，导致 production 回落到 CPU。
  - 已在 `gmx-lite` 环境替换为 CUDA 构建的 `gromacs 2024.5`（`GPU support: CUDA`）。
  - 生产参数中移除 `energygrps`（避免 `Multiple energy groups ... falling back to CPU`）。
  - `rep1` 已按 GPU offload 重启：`-nb gpu -pme gpu -bonded gpu`（`-update gpu` 因约束耦合限制不适用）。
  - 运行态验证通过：`md_200ns.log` 显示 `1 compatible GPU`（A800），`nvidia-smi` 显示 `gmx` 进程占用 GPU（util ~66%）。
- **后台可靠性与串行队列提交（dimer）**：
  - 新增脚本：`revision_exec/scripts/dimer_queue_nohup.sh`，顺序执行 `rep1 -> rep2 -> rep3` 的 200 ns production。
  - 采用 `nohup` 提交队列，日志：`revision_exec/logs/dimer_queue_20260417_164735.log`，PID 文件：`revision_exec/logs/dimer_queue.pid`。
  - 当前状态：队列已启动并自动从 checkpoint 续跑 `rep1`；`nvidia-smi` 显示 `gmx` 正在占用 A800（util ~67%）。

## 2026-04-21
- **rep1 production 完成**：
  - `revision_exec/rep1/prod/md_200ns.log` 已记录 `Finished mdrun on rank 0`（200 ns 完整跑完）。
  - 产物完整：`md_200ns.{xtc,edr,tpr,cpt,gro,log}` 均已落盘。
- **rep2 / rep3 并行双卡启动（nohup，抗 SSH 断线）**：
  - 采用独立后台命令并固定 GPU：`rep2 -> CUDA_VISIBLE_DEVICES=0`，`rep3 -> CUDA_VISIBLE_DEVICES=1`。
  - nohup 日志：
    - `revision_exec/logs/rep2_gpu0_200ns.nohup.log`
    - `revision_exec/logs/rep3_gpu1_200ns.nohup.log`
  - 生产日志持续写入：
    - `revision_exec/rep2/prod/md_200ns.log`
    - `revision_exec/rep3/prod/md_200ns.log`
  - 进程与 GPU 运行态已核验：两个 `gmx mdrun` 进程均在运行，双 A800 同时有占用（util ~60-70%）。
- **并行启动中的修复点（已处理）**：
  - 首次并行启动失败原因为 `rep2/rep3` 的旧 `md_200ns.tpr` 仍含 `energygrps`，触发 `Nonbonded interactions on the GPU were required, but not supported`。
  - 已用当前 `md_prod_200ns.mdp`（去除 `energygrps`）重新 `grompp` 生成 `rep2/rep3` 的生产 `tpr`，随后后台重启成功。
  - 结论：当前 `rep2/rep3` **可直接并行 GPU 跑，无需再改配置**；若后续重建 `tpr`，请继续使用同一份无 `energygrps` 的生产 mdp。

## 2026-04-22
- **任务状态巡检（新增日期记录）**：
  - `rep1`：已完成（`Finished mdrun` 已在 `revision_exec/rep1/prod/md_200ns.log` 记录）。
  - `rep2`：运行中，最新约 `95.184 ns / 200 ns`（`Step 47592000`）。
  - `rep3`：运行中，最新约 `90.366 ns / 200 ns`（`Step 45183000`）。
  - `monomer_beta_rep1`：运行中，最新约 `33.692 ns / 200 ns`（`Step 16846000`）。
  - `monomer_alpha_rep1`：运行中，最新约 `0.356 ns / 200 ns`（`Step 178000`，新启动）。
- **monomer 新任务（fresh reruns, 非 legacy 证据）**：
  - 新建并启动 `revision_exec/monomer_beta_rep1`（`prod/md_200ns.tpr` 已生成并后台运行）。
  - 新建并启动 `revision_exec/monomer_alpha_rep1`（`prod/md_200ns.tpr` 已生成并后台运行）。
  - 对应日志：
    - `revision_exec/logs/monomer_beta_gpu1_200ns.nohup.log`
    - `revision_exec/logs/monomer_alpha_gpu0_200ns.nohup.log`
- **GPU 与进程状态（30秒窗口均值）**：
  - GPU0：`util_avg ~55.5%`（min `45%`, max `63%`），`mem ~1027 MiB`。
  - GPU1：`util_avg ~55.7%`（min `48%`, max `62%`），`mem ~1011 MiB`。
  - 活跃 `mdrun` 进程共 4 条（`rep2`、`rep3`、`monomer_beta_rep1`、`monomer_alpha_rep1`），当前均在运行。

## 2026-04-25
- **调度调整：单体 production 全部安全暂停（为 dimer 让路）**：
  - 动机：多任务同卡争用后整体 `ns/day` 明显下降；优先把 `rep2/rep3` 尽快推到 200 ns。
  - 操作：对 `monomer_alpha_rep1`、`monomer_beta_rep1` 发送 `SIGTERM`，由 GROMACS 在约 100 step 内优雅停机并写 checkpoint（与此前已暂停的 `monomer_alpha_rep2` 一致）。
  - Checkpoint 落盘（续跑入口）：
    - `revision_exec/monomer_alpha_rep1/prod/md_200ns.cpt`
    - `revision_exec/monomer_beta_rep1/prod/md_200ns.cpt`
    - `revision_exec/monomer_alpha_rep2/prod/md_200ns.cpt`（此前已停）
  - **当前仅 dimer 在跑**：`rep2`（GPU0）、`rep3`（GPU1）；`nvidia-smi` 显存占用回落至约单任务量级（每卡 ~529 MiB 快照，随运行波动）。
  - **后续安全重启模板**（与启动时一致，仅追加 `-cpi` / `-append`；按需设 `CUDA_VISIBLE_DEVICES` 与 `-ntomp`）：
    - `gmx mdrun -deffnm .../prod/md_200ns -cpi .../prod/md_200ns.cpt -append -v -nb gpu -pme gpu -bonded gpu -ntmpi 1 -ntomp <N>`

## 2026-04-24
- **Dimer 由 200 ns 延长至 300 ns（rep1 + rep2，一卡一条）**：
  - 与 `rep1` 分析结论一致，对 **rep1、rep2** 各延长 **100 ns**（`gmx convert-tpr ... -extend 100000`，即 +100000 ps）。
  - 产物：`rep{1,2}/prod/md_200ns_ext100ns.tpr`；原 `md_200ns.tpr` 备份为 `md_200ns.tpr.before_300ns_extend`。
  - **启动方式**：
    - `rep2`：`CUDA_VISIBLE_DEVICES=1`，`deffnm` 使用 **绝对路径** 至 `rep2/prod/md_200ns`；nohup：`revision_exec/logs/rep2_gpu1_extend100ns.nohup.log`，PID：`rep2_gpu1_extend100ns.pid`。
    - `rep1`：`CUDA_VISIBLE_DEVICES=0`；因 checkpoint 中记录的是相对路径 `rep1/prod/md_200ns.*`，必须在 **`tubulin-cppf-md/revision_exec` 为当前目录** 下启动：`deffnm rep1/prod/md_200ns`（首次从仓库根目录用绝对 `deffnm` 会因找不到 `rep1/prod/md_200ns.log` 等而被 GROMACS 拒绝续跑）。nohup：`revision_exec/logs/rep1_gpu0_extend100ns.nohup.log`，PID：`rep1_gpu0_extend100ns.pid`。
  - **验证**：两任务日志均出现 `150000000 steps, 300000.0 ps (continuing from step 100000000, 200000.0 ps)`。
  - **rep3**：本次未与 rep1/rep2 并行延长；后续单独 `convert-tpr` + 占一空卡或排队即可。

## 2026-04-27
- **rep3 dimer 300 ns production 完成**：`revision_exec/rep3/prod/md_200ns.log` 记录 `Finished mdrun on rank 0`，checkpoint 写在 `step 150000000`（300 ns）。至此 **rep1 / rep2 / rep3** 均在 **300 ns** 停点。
- **三条 dimer 200-300 ns 定量分析已落盘**（同一套指标：backbone/ligand RMSD、Rg、SASA、mindist、contacts、Cα RMSF）：
  - 报告：`revision_exec/analysis_dimer_rep123_300ns/dimer_monomer_analysis_2026-04-27.md`
  - 可复现脚本：`revision_exec/analysis_dimer_rep123_300ns/run_rep_analysis.sh`、`summarize_xvgs.py`
- **方法学共识（平行试验）**：extension 策略从「单条优先」调整为 **三条 dimer 同步延长**，先做 **350 ns** 统一里程碑，再视指标决定是否继续。

## 2026-04-28
- **rep1：300 ns → 350 ns 延长已启动**：在 `revision_exec/rep1/prod/` 使用 `md_350ns.tpr`（`gmx dump` 可见 `nsteps=175000000`, `dt=0.002`，总时长 350 ns），自 `md_200ns.cpt` 续跑；`mdrun` 使用 `-noappend`，并指定 `-gpu_id 1`（见该目录 `md_350ns.log`）。
- **monomer 恢复生产**：`monomer_alpha_rep1`、`monomer_beta_rep1` 自 checkpoint 续跑并完成至 **200 ns**；`monomer_alpha_rep2` 继续在 GPU 上推进 production。

## 2026-04-29（进度快照，提交 git 当日巡检）
- **GPU / 任务**：
  - **GPU0**：`monomer_alpha_rep2/prod/md_200ns` 约 **193.6 ns / 200 ns**（收尾）。
  - **GPU1**：`rep1/prod/md_350ns` 约 **335.6 ns / 350 ns**（350 ns 延长约 **96%**）。
- **已完成**：`monomer_alpha_rep1`、`monomer_beta_rep1` **200 ns**；dimer **rep1–rep3** 各 **300 ns**。
- **待排队（与「每体系 ≥3 平行」一致）**：
  - Dimer：`rep2`、`rep3` 的 **300→350 ns**（与 rep1 对齐）。
  - Monomer：新增 **α rep3**、**β rep2**、**β rep3**（目录与 `tpr` 需按 rep1/rep2 流程准备）。
- **说明**：大轨迹（`.xtc`）、checkpoint（`.cpt`）等仍保留在计算节点工作区；**本仓库仅跟踪 Markdown 报告与脚本**，避免将巨型二进制纳入 git。

## 2026-05-04 ~ 2026-05-07（Revision 数据分析/可视化落盘 + 复现/归档）

### 0）与本段相关的「权威时间窗」（写 Methods / Results 时可直接照抄）
- **权威末端时间**：`revision_exec/analysis_revision/T_end_registry.yaml`
  - **Dimer** `dimer_rep{1,2,3}`：**`T_end_ns: 400.0`**（checkpoint：`revision_exec/rep{1,2,3}/prod/md_400ns.cpt`）。
  - **Monomer** `monomer_{alpha,beta}_rep{1,2,3}`：**`T_end_ns: 200.0`**（`.../prod/md_200ns.cpt`）。
- **`summary_by_window.csv` 汇总窗口**（与 `revision_plot_summary_table.py` 默认一致）：
  - Dimer 各行：**`[350, 400] ns`**（`window_kind=time_tail`）。
  - Monomer 各行：**`[150, 200] ns`**（即 **last 50 ns**，与 monomer boxplot 一致）。
- **图 `dimer_rep123_panels_0-400ns` 的横轴**：**0–400 ns**（全时长曲线）；与上表 **350–400 ns** 汇总窗 **不是同一表述**，写正文时注意区分。

### 1）Pipeline 入口（Step 2 导出 `.xvg`，Step 3 出图/表）
| 用途 | 路径 |
|------|------|
| 九体系批量导出 | `revision_exec/analysis_revision/run_export_all.sh` |
| `.xvg` 合并供 SHAM（时间戳 inner join） | `revision_exec/analysis_revision/merge_xvg_for_sham.py`、`prepare_fel_gsham_input.sh` |
| 统一 TIFF（LZW）/ DPI | `revision_exec/analysis_revision/revision_figure_export.py` |
| 说明文档 | `revision_exec/analysis_revision/README.md` |
| **原始 `.xvg` 树（体积大，默认不进 git）** | `revision_exec/analysis_revision/raw_xvg/<system_id>/`（生成于 Step 2） |

### 2）主文插图：路径 + 子图 **A–D** 对照 + 复现命令

#### 2.1 Dimer 三复现 time series（2×2，已标 **A–D**）
| 输出文件 | 说明 |
|----------|------|
| `revision_exec/analysis_revision/figures/dimer_rep123_panels_0-400ns.tif` | 投稿/preflight |
| `revision_exec/analysis_revision/figures/dimer_rep123_panels_0-400ns.png` | 本地预览 |

**子图映射**（与 `revision_plot_dimer_timeseries.py` 内 `PANEL_METRICS` **行优先**一致）：

| 标注 | 面板内容（文件名关键字） | Y 轴 / 含义 |
|------|---------------------------|-------------|
| **A** | `rmsd_backbone` | Backbone RMSD (nm)，rep1–3 彩线 + rep 间 min–max 带 |
| **B** | `rg` | Rg protein (nm) |
| **C** | `mindist_pl` | Min distance protein–ligand (nm) |
| **D** | `hbond_num` | H-bonds (#)，来自 `gmx hbond-legacy` |

**复现（在 `tubulin-cppf-md/revision_exec/analysis_revision/`）**：
```bash
python revision_plot_dimer_timeseries.py --mode panels --raw-root raw_xvg \
  --t-end-ns 400 --window-ns 50 \
  --out-fig figures/dimer_rep123_panels_0-400ns.tif
```

#### 2.2 Monomer α vs β（last **50 ns**，2×2 boxplot，已标 **A–D**）
| 输出文件 |
|----------|
| `revision_exec/analysis_revision/figures/monomer_alpha_vs_beta_last50ns_boxplots.tif` |
| `revision_exec/analysis_revision/figures/monomer_alpha_vs_beta_last50ns_boxplots.png` |

**数据窗口**：`T_end=200 ns`，`--window-ns 50` → **`[150, 200] ns`**（图题中会打印）。

**子图映射**（`revision_plot_monomer_boxplot.py` 内 `PANELS` 顺序）：

| 标注 | metric | Y 轴 |
|------|--------|------|
| **A** | `mindist_pl` | Min distance protein–ligand (nm) |
| **B** | `hbond_num` | H-bonds (#) |
| **C** | `rmsd_ligand` | RMSD ligand (nm) |
| **D** | `rg` | Rg protein (nm) |

**复现**：
```bash
python revision_plot_monomer_boxplot.py --raw-root raw_xvg --window-ns 50 \
  --out-fig figures/monomer_alpha_vs_beta_last50ns_boxplots.tif
```

#### 2.3 FEL：combined α \| combined β（一行 **四**面板 **A–D**）
| 输出文件 |
|----------|
| `revision_exec/analysis_revision/figures/fel_combined_alpha_beta_zcap5.tif` |
| `revision_exec/analysis_revision/figures/fel_combined_alpha_beta_zcap5.png` |

**从左到右**：**A** = combined α **3D**；**B** = combined α **2D contour**；**C** = combined β **3D**；**D** = combined β **2D contour**。CV：**Rg (nm)** × **Backbone RMSD (nm)**；能量：**G (kcal/mol)**（由 SHAM 的 kJ/mol ÷ 4.184）；色标 **上限 cap = 5 kcal/mol**。

**分拆单张（备用）**：
- `revision_exec/analysis_revision/figures/fel_combined_alpha_zcap5.tif`（及 `.png`）
- `revision_exec/analysis_revision/figures/fel_combined_beta_zcap5.tif`（及 `.png`）

**SHAM 输入（combined）**：
- `revision_exec/analysis_revision/fel/combined/alpha/gsham_input_rg_rmsdBB_plain.xvg`
- `revision_exec/analysis_revision/fel/combined/beta/gsham_input_rg_rmsdBB_plain.xvg`

**一键重生成（含 main + supp）**：
```bash
cd revision_exec/analysis_revision
ZMAX=5 ENERGY_UNIT=kcal_mol DPI=300 bash make_fel_supp_and_main.sh
```

#### 2.4 FEL：补充材料（单 rep，文件名已含 rep id；每张图为 **3D|2D** 拼接的一张 TIFF）

**Alpha**
- `revision_exec/analysis_revision/fel/monomer_alpha_rep1/gibbs_rg_rmsd_monomer_alpha_rep1_zcap5.tif` + `.png`
- `revision_exec/analysis_revision/fel/monomer_alpha_rep2/gibbs_rg_rmsd_monomer_alpha_rep2_zcap5.tif` + `.png`
- `revision_exec/analysis_revision/fel/monomer_alpha_rep3/gibbs_rg_rmsd_monomer_alpha_rep3_zcap5.tif` + `.png`

**Beta**
- `revision_exec/analysis_revision/fel/monomer_beta_rep1/gibbs_rg_rmsd_monomer_beta_rep1_zcap5.tif` + `.png`
- `revision_exec/analysis_revision/fel/monomer_beta_rep2/gibbs_rg_rmsd_monomer_beta_rep2_zcap5.tif` + `.png`
- `revision_exec/analysis_revision/fel/monomer_beta_rep3/gibbs_rg_rmsd_monomer_beta_rep3_zcap5.tif` + `.png`

**绘图依赖**：`revision_exec/analysis/external/gromacs-gibbs-pipeline/scripts/plot_gibbs_landscape.py`、`xpm2txt.py`。

### 3）数值表（论文逐句引用）

#### 3.1 `summary_by_window.csv`
- **路径**：`revision_exec/analysis_revision/tables/summary_by_window.csv`
- **生成**：`revision_exec/analysis_revision/revision_plot_summary_table.py`（见 `--help`）
- **列**：`system_id`, `metric`, `xvg_file`, `window_t_start_ns`, `window_t_end_ns`, `window_kind`, `n_points`, `mean`, `std`
- **注意**：`rmsf_residue` 行 `window_*` 为 `NA`（横轴为残基，不是时间）。

#### 3.2 MM-PBSA（GB，轨迹末段 **350–400 ns**，**51** 帧，`interval=100`，≈1 ns）
- **汇总**：`revision_exec/analysis/mmpbsa/mmpbsa_summary.csv`
- **输入**：`revision_exec/analysis/mmpbsa/mmpbsa_dimer_rep1_last50ns_gb.in`（`&gb` 中 **`igb=5`** 等）
- **摘自当前 CSV 的数值（kcal/mol，mean ± SD）**：
  - **rep1**：ΔVDW −40.57±3.07；ΔEEL −4.95±3.52；ΔEGB +23.01±3.26；ΔESURF −5.40±0.18；**ΔTOTAL −27.92±3.33**
  - **rep2**：ΔVDW −42.07±1.99；ΔEEL −4.34±3.53；ΔEGB +22.04±3.09；ΔESURF −5.57±0.14；**ΔTOTAL −29.94±2.40**
  - **rep3**：ΔVDW −43.23±2.87；ΔEEL −8.45±28.33；ΔEGB +21.83±25.90；ΔESURF −5.86±0.14；**ΔTOTAL −35.71±4.58**
  - **三 rep ΔTOTAL（对三条 rep 的均值再汇总）**：**−31.19 ± 4.04**
- **运行**：`revision_exec/analysis/mmpbsa/run_dimer_rep1_last50ns_mmpbsa.sh`，例：`MMPBSA_MODE=full REP=rep2 bash ...`
- **汇总脚本**：`revision_exec/analysis/mmpbsa/summarize_mmpbsa_gb_last50ns.py`
- **BOND overflow 文案**：`docs/RUNBOOK.md` MM-PBSA 小节、`revision_exec/analysis/mmpbsa/README.md`

### 4）与 `@Manu_v4_plos` 旧稿的对照（改哪张图 / 哪段字）

| 旧稿资产 | 旧稿含义 | Revision 替换素材 |
|----------|----------|-------------------|
| `Manu_v4_plos/Fig4.png` | ~50 ns 单体 RMSD/Rg/mindist/SASA | **`dimer_rep123_panels_0-400ns`**（二聚体三 rep）及/或 **`monomer_*_boxplots`**；**时间尺度与旧稿不同**，正文必须重写 |
| `Manu_v4_plos/Fig5.png` | 旧 FEL（PC 等，50 ns 语境） | **`fel_combined_alpha_beta_zcap5`**；SI 用 **`fel/monomer_*_rep{1,2,3}`** 六张 |
| `Results.tex` + Table 2（PISA ΔG） | 静态界面能 | 与 **MM-PBSA ΔTOTAL** 分工表述，避免混为一谈 |
| `Materials and methods.tex` MD 段 | 50 ns、旧分析 | 更新为 **400 ns dimer / 200 ns monomer**、**hbond-legacy**、FEL、MM-PBSA 窗口与帧数 |

### 5）索引与归档路径
- **Reviewer → 证据**：`docs/REVIEWER_EVIDENCE_CHECKLIST.md`
- **GitHub**：`https://github.com/GITHUB_NAMESPACE/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference`
- **Hugging Face Dataset（示例）**：`HUB_NAMESPACE/MD-trajectories-CPPF-tubulin-heterodimer-and-monomers`（见 `docs/HUGGINGFACE_DATASET.md`）
- **HF 小镜像上传记录**：`revision_exec/logs/hf_mirror_small_20260507_020247.log`；索引：`revision_exec/logs/HF_AND_PIPELINE_LOG_INDEX.md`

### 6）论文改写 checklist（逐项打钩）
- [ ] Methods：MD 时长、三 rep、`hbond-legacy`、轨迹分段命名 `docs/DIMER_TRAJECTORY_NAMING.md`
- [ ] Methods：FEL（CV、合并 rep、kcal/mol、cap=5、`gmx sham`）
- [ ] Methods：MM-PBSA（350–400 ns、51 帧、GB `igb=5`、BOND overflow）
- [ ] Results / Fig：替换 Fig4 逻辑 → `dimer_rep123_panels_0-400ns` +（可选）monomer boxplots
- [ ] Results / Fig：替换 Fig5 → `fel_combined_alpha_beta_zcap5`；SI → 六张 `fel/monomer_*`
- [ ] Results：Table 2（PISA）与 MM-PBSA 并列时的措辞
- [ ] Response letter：逐条链接 `REVIEWER_EVIDENCE_CHECKLIST.md` + 上图路径 + `mmpbsa_summary.csv`
