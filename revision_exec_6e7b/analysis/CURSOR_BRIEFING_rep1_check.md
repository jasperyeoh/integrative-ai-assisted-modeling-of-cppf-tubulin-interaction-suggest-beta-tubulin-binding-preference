# Cursor Briefing: rep1 Convergence Check

## 任务

判断 6E7B rep1（已完成 200 ns）是否在 binding-relevant 指标上收敛了。结果决定是否要把 rep1 延长到 400 ns。

## 背景（必读）

- 6E7B 的 rep1 已经跑完 200 ns。rep2 正在跑（**不要打断 rep2，它在用 GPU**）。
- 本次检查**只用 CPU**，读 rep1 的 xtc/edr/tpr，不会影响 rep2。
- 5IJ0 main-text 跑了 400 ns × 3 reps，但 rep1 在 ~50 ns 就 plateau 到 ~0.3 nm RMSD；rep2/rep3 仍 drift。这意味着「跑更长」不一定收敛——我们需要看 rep1 的实际行为，**不是机械地延长到 400 ns**。
- 6E7B 是 lattice straight conformation，物理上预期比 5IJ0 更受约束，可能 100-150 ns 就稳定。

## 执行

**确认 rep2 还在跑后**，运行：

```bash
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b
git pull   # 拉取最新分析脚本
bash analysis/rep1_convergence_check.sh 2>&1 | tee analysis/rep1_health/check.log
```

预计耗时 5-15 分钟（PBC correction 是主要瓶颈）。**全程不动 GPU**。

## 脚本会做什么

1. PBC correction（nojump → cluster -center）
2. 计算 5 个指标的时间序列：
   - **Backbone RMSD**（主指标）
   - Ligand RMSD（CPPF 是否原地稳定）
   - **min(CPPF–protein)**（主指标，binding 是否丢失）
   - Rg（蛋白整体大小变化）
   - H-bond count
3. 自动判定每个指标是否「收敛/不确定/drift」
4. 输出 OVERALL VERDICT + 推荐 action

## 怎么读输出

脚本最后会打印一个表 + verdict block。两种典型结果：

### 情况 A: CONVERGED（最可能）

```
>>> OVERALL: rep1 has CONVERGED on the binding-relevant metrics.
>>> RECOMMENDATION: 200 ns is sufficient. No extension needed.
```

→ **什么都不用做**，等 rep2 跑完后做完整分析。

### 情况 B: DRIFTING

```
>>> OVERALL: rep1 has NOT converged on binding-relevant metrics.
>>> RECOMMENDATION: Consider extending rep1 to 400 ns AFTER rep2 finishes.
```

→ **不要立刻延长**。先把输出贴给我看，由 PI 决定是否延长（rep2 跑完后再操作，避免抢 GPU）。

### 情况 C: UNCERTAIN

→ 看具体指标。如果 RMSD 稳但 min-dist 在飘 → 可能是 CPPF 在口袋里换位姿但没解离 → **接受**。
   如果 min-dist 持续上涨 → CPPF 可能正在解离 → **严重**，需要看图。

## 视觉检查（可选）

如果服务器装了 gnuplot，会打印 ASCII RMSD 图。否则把 `analysis/rep1_health/*.xvg` scp 回本地：

```bash
# 从 Mac 本地跑：
scp -P 36037 -r root@connect.nmb1.seetacloud.com:/root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/analysis/rep1_health ./
```

然后用任何能开 xvg 的工具看（VMD、xmgrace、或 Python+matplotlib）。

## 重要规则

- ❌ **不要打断 rep2**——它是另一个 screen 会话 `md_queue`，让它继续跑
- ❌ **不要自行 `convert-tpr -extend`**——决定要不要延长是 PI 的事
- ❌ **不要重新跑 rep1 MD** —— 我们只是分析它，trajectory 不变
- ✅ **要做的**：跑脚本，把 verdict 输出贴出来
- ✅ 如果脚本报错，停下来贴 log，不要瞎改

## 一句话

> 运行 `bash analysis/rep1_convergence_check.sh`，把最后的 VERDICT block 完整贴出来。结束。
