# 6E7B Supplementary MD — Cursor Execution Briefing

**Last updated:** 2026-06-09
**Operator (this session):** Cursor on AutoDL RTX 4090 server
**Server path:** `/root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/`

---

## 1. 项目背景（你在做什么 + 为什么）

### 1.1 这个项目是什么
我们正在给 **PLOS Computational Biology** 投稿做 revision，论文主题是 **CPPF（一种候选抗微管药物）与 tubulin（微管蛋白）的结合机制**。Main text 已经基于 PDB **5IJ0** 跑了 3 个 replicate × 300+ ns 的 MD，结论是 CPPF 优先结合 β-tubulin。

### 1.2 你现在要做什么
**Reviewer 4.2 提出 major comment**：5IJ0 是 β-GDP 状态（可溶性弯曲二聚体），希望我们补充 **6E7B 状态**（β-GTP/GMPCPP，微管 lattice 直线构象）的 MD，证明 CPPF 在这个状态下也能稳定结合。

你的任务：**在 AutoDL RTX 4090 上跑 6E7B 的 supplementary MD，2 × 200 ns**。

### 1.3 关键科学决策：**MD 系统不包含 cofactor（GTP/G2P/Mg²⁺）**
这是有意为之，不是疏忽。三条理由（response letter 里已经写了）：

1. **空间分离**：CPPF 结合在 β-tubulin **N-site 附近的 colchicine 区域**（αβ 界面）；GTP/GDP/G2P 结合在 **E-site**（β-tubulin 另一侧），两者相距 ~15-20 Å。
2. **实验先验**：文献报道 colchicine 与 tubulin dimer 的 Kd **不依赖** β-tubulin 的核苷酸状态。CPPF 位点与 colchicine 重叠，所以推测同理。
3. **构象效应已上游捕获**：Protenix **预测时是带辅因子做的**，所以预测出的口袋形状已经隐含了核苷酸态对 backbone 的影响。MD 只需测试这个构象下 CPPF 的动力学稳定性。

**最关键的是：5IJ0 main-text MD 当时也是不含 cofactor 的**（我们核查过 `gate_topol.top` 和原子数）。所以 6E7B 不加 cofactor 是为了**与 5IJ0 直接可比**——这是 reviewer 想问的「conformational state 比较」的科学逻辑。

### 1.4 不要去碰的事
- ❌ **不要**尝试参数化 G2P（GMPCPP）。我们之前 GTP/GDP 的 tleap 都没跑通过，这条路是死胡同。
- ❌ **不要**改 MD protocol（force field、water model、cutoff、温度压力）。必须与 5IJ0 main-text 完全一致。
- ❌ **不要**用 Protenix CIF 直接做 MD 起点。必须先 Kabsch 对齐到 6E7B.pdb 模板（已写好脚本）。

---

## 2. 当前状态

### 2.1 服务器环境（之前已确认）
- ✅ GROMACS **2024.5 + CUDA** 在 conda env `gmx-lite`
- ✅ AmberTools/ACPYPE/RDKit 在 conda env `mdprep`（这个任务用不到）
- ✅ RTX 4090 24GB GPU
- ✅ Repo 已 clone 到 `/root/autodl-tmp/tubulin-cppf-md/`
- ⚠️ **重要**：系统盘 30G 已经很满，所有大文件（MD 输出、log、checkpoint）**必须写在 `/root/autodl-tmp/` 下**。Repo 本身也在那里，OK。

### 2.2 输入数据（已就位）
```
revision_exec_6e7b/
├── input/
│   ├── 6E7B.pdb                                      ← 模板（用于 Kabsch 对齐）
│   └── protenix_predictions/predictions/
│       ├── protenix_prediction_6E7B_250526_sample_0.cif  ← 最高 confidence，用这个
│       ├── ..._sample_1.cif ~ ..._sample_4.cif
│       └── ..._summary_confidence_sample_*.json
├── scripts/
│   ├── prepare_6e7b_complex.py        ← Step A: CIF → 对齐 → complex PDB
│   └── run_6e7b_md_pipeline.sh        ← Step B-G: 完整 system prep + EM/NVT/NPT
└── (prep/, md/, analysis/ 待创建)
```

### 2.3 复用自 5IJ0 main-text 的资源
脚本会自动从这些路径拷贝（**不要修改这些源文件**）：
- `revision_exec/input/ligand/CPPF_RESP2.itp` — CPPF 拓扑（GAFF2 + RESP2 电荷）
- `revision_exec/input/ligand/posre_CPPF_RESP2.itp` — CPPF position restraints
- `revision_exec/input/mdp/em.mdp` `nvt.mdp` `npt.mdp` `md_prod_200ns.mdp` — 所有 MDP 文件

---

## 3. 执行步骤

### 步骤 0：进入工作目录 + 检查环境

```bash
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b

# 验证 GROMACS GPU build
eval "$(conda shell.bash hook)"
conda activate gmx-lite
gmx --version | grep -E "GROMACS version|GPU support"
# 必须看到：GROMACS version: 2024.5-conda_forge
# 必须看到：GPU support: CUDA

# 验证 GPU 可见
nvidia-smi | head -10
# 必须看到 RTX 4090

# 拉取最新代码（脚本可能有更新）
cd /root/autodl-tmp/tubulin-cppf-md
git pull
cd revision_exec_6e7b
```

### 步骤 1：装 screen（如果还没装）

**所有 MD 命令都必须在 screen 里跑**，因为 SSH 一断 mdrun 就死。

```bash
which screen || apt-get update && apt-get install -y screen
```

### 步骤 2：运行 system preparation pipeline

这一步会完成：CIF→PDB 对齐 → pdb2gmx → 加 CPPF → solvate → ions → EM → NVT → NPT → 准备 rep1 production TPR。

**预计耗时**：30-60 分钟（包括 EM + NVT + NPT 在 GPU 上跑）。

```bash
# 在 screen 里跑（重要！）
screen -S prep

# screen 里执行：
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b
bash scripts/run_6e7b_md_pipeline.sh 2>&1 | tee prep_pipeline.log

# 跑起来后按 Ctrl+A 然后按 D 可以 detach
# 回来看进度：screen -r prep
```

**关键中间检查点**（pipeline 会自动 print，你要确认看到）：

| 阶段 | 期望输出 |
|------|---------|
| CIF→PDB 对齐 | `CA RMSD after alignment: < 1.0 Å` |
| pdb2gmx 后 | 生成 `processed.gro`、`topol_Protein_chain_A.itp`、`topol_Protein_chain_B.itp` |
| Topology 修改后 | `grep -A 5 'molecules' topol.top` 显示 `Protein_chain_A 1` + `Protein_chain_B 1` + `CPPF_RESP2 1` |
| Solvate 后 | 添加约 50000-60000 SOL（dimer 标准量级）|
| Ions 后 | `NA` 和 `CL` 数量大约 200/150 左右（0.15 M）|
| EM 后 | Maximum force < 1000 kJ/mol/nm；生成 `em.gro` |
| NVT 后 | 温度收敛到 ~300 K；生成 `nvt.gro`、`nvt.cpt` |
| NPT 后 | 密度收敛到 ~1000 kg/m³；生成 `npt.gro`、`npt.cpt` |
| 最后 | `md/rep1/md_200ns.tpr` 文件生成 |

**如果任何一步报错，停下来**，把完整 log 贴出来再决定。**不要自行修改 protocol**（force field、温度、cutoff 等绝对不要动）。

### 步骤 3：跑 rep1 production MD（200 ns）

```bash
# 新开一个 screen 专门给 rep1
screen -S md_rep1

# screen 里执行：
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/md/rep1
conda activate gmx-lite

# GPU 全开：nb（non-bonded）、PME、bonded 都 offload 到 GPU
# update gpu 让积分也在 GPU 跑，对 RTX 4090 提速明显
gmx mdrun -v -deffnm md_200ns \
    -ntmpi 1 -ntomp $(nproc) \
    -nb gpu -pme gpu -bonded gpu -update gpu \
    -gpu_id 0 \
    2>&1 | tee md_rep1.log

# 跑起来后 Ctrl+A 然后 D detach
```

**预计速度**：RTX 4090 在这种系统大小（~180k 原子）下应该跑 **50-60 ns/day**，200 ns 约 **3.5-4 天**。

**前 30 分钟检查**（确认稳定运行后再去做 rep2）：
```bash
# 回到 screen 看
screen -r md_rep1

# 看 log 末尾
tail -50 md_rep1.log
# 看到 "Writing checkpoint, step 50000" 类似的就是正常跑
# 看到 "Performance: XX.X ns/day" 就能确认速度
```

### 步骤 4：rep2 production（不同随机种子）

**等 rep1 确认稳定跑了**（30 分钟以上没崩）再启 rep2。RTX 4090 同时跑两个 MD 会拖速度。**所以 rep2 等 rep1 跑完再启动**，或者按 PI 决定。

**默认策略：rep1 跑完再跑 rep2，串行**。如果时间紧，再考虑并行。

rep2 setup：

```bash
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b
mkdir -p md/rep2

# 重新 grompp，用不同 random seed
# 修改 nvt.mdp 的 gen_seed（5IJ0 main text 用的是 -1 = 自动随机，所以 grompp 每次跑会生成不同种子）
# 但 npt 起点（initial velocities）不同就够区分 replicate 了

# 方法：从 EM 后重新做 NVT（新种子）→ NPT → production
cp prep/em.gro prep/em_for_rep2.gro
cd prep

gmx grompp -f nvt.mdp -c em_for_rep2.gro -r em_for_rep2.gro \
    -p topol.top -n index.ndx -o nvt_rep2.tpr -maxwarn 2
gmx mdrun -v -deffnm nvt_rep2 -ntmpi 1 -ntomp $(nproc) \
    -nb gpu -gpu_id 0

gmx grompp -f npt.mdp -c nvt_rep2.gro -r nvt_rep2.gro -t nvt_rep2.cpt \
    -p topol.top -n index.ndx -o npt_rep2.tpr -maxwarn 2
gmx mdrun -v -deffnm npt_rep2 -ntmpi 1 -ntomp $(nproc) \
    -nb gpu -gpu_id 0

gmx grompp -f md_prod_200ns.mdp -c npt_rep2.gro -t npt_rep2.cpt \
    -p topol.top -n index.ndx -o ../md/rep2/md_200ns.tpr -maxwarn 2

# 然后 production
screen -S md_rep2
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/md/rep2
conda activate gmx-lite
gmx mdrun -v -deffnm md_200ns \
    -ntmpi 1 -ntomp $(nproc) \
    -nb gpu -pme gpu -bonded gpu -update gpu \
    -gpu_id 0 \
    2>&1 | tee md_rep2.log
```

---

## 4. 持续监控

### 4.1 每 6-12 小时检查一次（用普通 SSH 登入即可）

```bash
# 看 screen 列表
screen -ls

# 看 rep1 跑到哪一步
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/md/rep1
tail -20 md_200ns.log
# 重点看：
#   "step XXXXXX" — 当前步数，目标 100000000（= 200 ns）
#   "Performance: XX.X ns/day" — 速度
#   不能有 "LINCS WARNING" / "Constraint failed" / "NaN"

# 看磁盘
df -h /root/autodl-tmp
# 一定要留 50G+ 给后续 rep2 + 分析
```

### 4.2 GPU 健康检查

```bash
nvidia-smi
# 期望：
#   GPU-Util: 95-100%
#   Memory: ~3-5 GB used (这种系统大小)
#   Temperature: < 85°C
```

### 4.3 如果 SSH 断了 / 服务器重启
AutoDL 实例可能会断电/重启。回来后：
```bash
screen -ls
# 如果 screen 还在，screen -r md_rep1 即可继续看

# 如果 mdrun 已经死了，用 checkpoint 续跑：
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/md/rep1
gmx mdrun -v -deffnm md_200ns -cpi md_200ns.cpt -append \
    -ntmpi 1 -ntomp $(nproc) \
    -nb gpu -pme gpu -bonded gpu -update gpu -gpu_id 0
```

---

## 5. 常见故障 + 解决

### 5.1 grompp 报 "Atomtype xx not found"
**原因**：`CPPF_RESP2.itp` 没有在 `topol.top` 最前面 include（必须在所有 `[ moleculetype ]` 之前）。
**修复**：pipeline 脚本已经处理，但如果手动改过 topology，确认 `#include "CPPF_RESP2.itp"` 在 `forcefield.itp` 之后、`gate_topol_Protein_chain_A.itp` 之前。

### 5.2 NVT 后温度异常（不在 295-305 K）
**原因**：tc-grps 没有正确合并 Protein + CPP 成一个 group。
**修复**：检查 `index.ndx`，重新 `gmx make_ndx`，确保 `Protein_CPP` group 同时包含 Protein 和 CPP 原子。

### 5.3 mdrun 报 "Fatal error: NaN" 或 LINCS warnings
**原因**：起始结构有 clash（CPPF 和蛋白重叠）。
**修复**：
- 检查 `complex_start.pdb` 的 CA RMSD 是否 < 1.0 Å（步骤 2 已验证）
- 重新跑 EM，emtol 改 100（更严）：`sed -i 's/emtol.*=.*1000/emtol = 100/' prep/em.mdp`
- 重做 EM → NVT → NPT

### 5.4 跑得极慢（< 20 ns/day）
**原因**：GPU 没被 mdrun 用上。
**修复**：
```bash
# 检查
gmx mdrun -version 2>&1 | grep -i cuda
# 必须看到 "CUDA support: enabled"

# 检查实际运行时 mdrun 是否找到 GPU
grep -i "gpu" md_200ns.log | head -10
# 必须看到 "Using 1 GPU"
```

### 5.5 磁盘满
```bash
df -h /root/autodl-tmp
# 如果 < 10G：
# 压缩老的 xtc
cd md/rep1
gmx trjconv -f md_200ns.xtc -o md_200ns_compressed.xtc -pbc mol -ur compact
```

---

## 6. 跑完之后（暂不需要执行，只是预告）

跑完后会做的分析（之后再讨论）：
- Backbone RMSD（与 5IJ0 main-text 对比）
- CPPF–protein 最小距离 / H-bond 时序
- Binding pocket distance（关键残基与 CPPF 的距离）
- PLIP / MM-PBSA（与 5IJ0 用同一套脚本）

完整的 200 ns trajectory + 所有中间文件，必须**留在 `/root/autodl-tmp/`**，跑完后通过 huggingface dataset 上传（之前已经为 5IJ0 做过）。

---

## 7. 一句话总结你现在要做什么

> 在 screen 会话里跑 `bash scripts/run_6e7b_md_pipeline.sh`，确认所有中间检查点通过，然后启 `md_rep1` screen 跑 200 ns production。**所有命令必须在 screen 里**，**所有文件必须在 `/root/autodl-tmp/` 下**，**不要修改 force field/protocol**，遇到错误**停下来贴 log**。

## 8. 不要做的事（再强调一遍）
- ❌ 不要参数化 G2P
- ❌ 不要改 force field 或 MDP 参数
- ❌ 不要把 cofactor（GTP/G2P/MG）放回 MD 系统
- ❌ 不要在 SSH 直接跑 mdrun（必须用 screen）
- ❌ 不要把任何 MD 输出写到 `/root/`（必须 `/root/autodl-tmp/`）
- ❌ 不要在 rep1 跑稳之前启动 rep2（GPU 会抢资源）
