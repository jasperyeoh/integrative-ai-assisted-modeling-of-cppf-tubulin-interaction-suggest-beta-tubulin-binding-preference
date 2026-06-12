# Repo Migration Plan: System Disk → autodl-tmp

## 触发条件
**只在 rep2 production 完全跑完后执行**。

确认方法：
```bash
screen -ls | grep md_rep2   # 应该没有这个 session（已 detach 退出）
ls -la /root/autodl-tmp/rep2_md/md_200ns.gro   # 最终 gro 文件存在
tail -5 /root/autodl-tmp/rep2_md/md_200ns.log  # 看到 "Finished mdrun"
```

## 问题

```
/root/integrative-ai-assisted-modeling-...    24G   在 overlay 30G 盘上（85% 满）
/root/tubulin-cppf-md                         → 指向上面
/root/autodl-tmp/tubulin-cppf-md              → 也指向上面（反向陷阱！）
/root/autodl-tmp/rep2_md/                     12G   rep2 production 输出
```

## 目标

```
/root/autodl-tmp/integrative-ai-assisted-modeling-...   24G   真正在数据盘
/root/integrative-ai-assisted-modeling-...              → 软链回 autodl-tmp 真盘
/root/tubulin-cppf-md                                   → 软链回 autodl-tmp 真盘
/root/autodl-tmp/tubulin-cppf-md                        → 同上
/root/autodl-tmp/integrative-...-md/revision_exec_6e7b/md/rep2/   合并 rep2_md 进来
```

## 迁移步骤

### Step 0 — 安全前置
```bash
# 确认 rep2 真的跑完了
tail -5 /root/autodl-tmp/rep2_md/md_200ns.log
grep -E "Finished mdrun|Finishing up" /root/autodl-tmp/rep2_md/md_200ns.log

# 看 screen 没有挂任何 mdrun
screen -ls
ps aux | grep gmx | grep -v grep
# 必须没有 gmx 进程

# 备份当前 git HEAD（保险）
cd /root/tubulin-cppf-md
git rev-parse HEAD > /tmp/repo_head_before_migrate.txt
git status > /tmp/repo_status_before_migrate.txt
```

### Step 1 — 复制 repo 到 autodl-tmp
```bash
# 用 rsync 而不是 mv，保留权限/时间戳，可中断恢复
REAL="/root/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference"
DEST="/root/autodl-tmp/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference"

# 实际 rsync（预计 5-15 分钟，24G）
rsync -a --info=progress2 "${REAL}/" "${DEST}/"

# 验证大小一致
du -sh "${REAL}" "${DEST}"
```

### Step 2 — 把 rep2_md/ 合并进 repo 的 md/rep2/
```bash
DEST="/root/autodl-tmp/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference"
mkdir -p "${DEST}/revision_exec_6e7b/md/rep2"

# 拷贝 rep2 所有文件到正式位置
rsync -a /root/autodl-tmp/rep2_md/ "${DEST}/revision_exec_6e7b/md/rep2/"

# 验证
ls -lh "${DEST}/revision_exec_6e7b/md/rep2/md_200ns.gro"
ls -lh "${DEST}/revision_exec_6e7b/md/rep2/md_200ns.xtc"
```

### Step 3 — 删除旧位置 + 重建 symlinks
```bash
REAL="/root/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference"

# 先删旧 symlinks（不删真目录，先保留作备份）
rm /root/tubulin-cppf-md
rm /root/autodl-tmp/tubulin-cppf-md

# 重建：都指向 autodl-tmp 真目录
ln -s /root/autodl-tmp/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference /root/tubulin-cppf-md
ln -s /root/autodl-tmp/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference /root/autodl-tmp/tubulin-cppf-md

# 验证 symlinks 都正确
readlink -f /root/tubulin-cppf-md
readlink -f /root/autodl-tmp/tubulin-cppf-md
# 必须都打印：/root/autodl-tmp/integrative-...

# 验证从 symlink 进入还能找到 rep2 数据
ls /root/tubulin-cppf-md/revision_exec_6e7b/md/rep2/md_200ns.gro
```

### Step 4 — 删除系统盘旧 repo + rep2_md/
```bash
# 双重确认（再看一次 git 是否能正常工作）
cd /root/tubulin-cppf-md
git log --oneline -3
git status

# 看新位置磁盘正常
df -h /root /root/autodl-tmp

# 删除系统盘上的旧 repo（不可逆，确认上面都 OK 再做）
REAL="/root/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference"
rm -rf "${REAL}"

# 删除 rep2_md/（数据已合并到 repo 的 md/rep2/）
rm -rf /root/autodl-tmp/rep2_md

# 最终确认
df -h /root /root/autodl-tmp
# 期望：overlay 用量降到 ~5G（清 24G + conda cache）
# autodl-tmp：100G+ 使用，300G+ 空闲
```

### Step 5 — git 完整性最终验证
```bash
cd /root/tubulin-cppf-md
git fsck --full           # 完整性检查，不应有 error
git status                # 不应有 unexpected 改动
git log --oneline -5      # 看历史

# 对比迁移前后
cat /tmp/repo_head_before_migrate.txt
git rev-parse HEAD
# 两个 hash 必须相同

git diff $(cat /tmp/repo_head_before_migrate.txt) HEAD
# 必须空（没有任何差异）
```

## 风险与回滚

### 如果 Step 1-2 中途断
- rsync 可重启：再跑一次 `rsync -a` 命令，会跳过已传输的
- 旧 repo 没动，回滚 = 删 `${DEST}` 重来

### 如果 Step 3 后 symlink 错了
- 旧 repo `${REAL}` 还在，删 symlinks 重建即可

### 如果 Step 4 已执行但发现问题
- 系统盘已空，autodl-tmp 是唯一副本
- 检查 git fsck 是否报错；用 `git push --force-with-lease` 把本地正确版本推到 GitHub 兜底（先确认本地没问题）

## 时间预估

| 步骤 | 时间 |
|------|------|
| Step 1 (rsync repo) | 5-15 min |
| Step 2 (rsync rep2_md) | 1-2 min |
| Step 3 (symlinks) | 1 sec |
| Step 4 (cleanup) | 1-2 min |
| Step 5 (git verify) | 1 min |
| **总计** | **10-20 min** |

## 完成后系统盘期望状态

```
overlay:  30G total, ~5-8G used (cache + binary + scattered files)
          22-25G free
autodl-tmp: 406G total, ~110G used (repo + envs + scattered)
            ~290G free
```

充裕安全。
