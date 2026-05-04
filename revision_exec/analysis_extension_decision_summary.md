# Extension decision summary (2026-05-01)

## Dimer rep1 (300–350 ns segment, `md_350ns.part0004.xtc`)

### rmsd_backbone_nm

- 300–325 ns: mean=4.3261, std=0.4342, n=2500
- 325–350 ns: mean=4.4228, std=0.3964, n=2500
- slope(300–350 ns): **0.002814** per ns

### rmsd_ligand_nm

- 300–325 ns: mean=4.5445, std=0.4738, n=2500
- 325–350 ns: mean=4.5686, std=0.4317, n=2500
- slope(300–350 ns): **-0.000281** per ns

### Rg_protein_nm

- 300–325 ns: mean=5.4790, std=0.2960, n=2501
- 325–350 ns: mean=5.6726, std=0.2960, n=2501
- slope(300–350 ns): **0.006684** per ns

### mindist_protein_UNL_nm

- 300–325 ns: mean=0.2061, std=0.0112, n=2501
- 325–350 ns: mean=0.2066, std=0.0110, n=2501
- slope(300–350 ns): **0.000045** per ns

### contacts_0p35nm

- 300–325 ns: mean=152.7601, std=12.1533, n=2501
- 325–350 ns: mean=154.6869, std=11.9978, n=2501
- slope(300–350 ns): **0.090905** per ns

## Monomer (150–200 ns late window, completed reps only)

### monomer_alpha_rep1

- **rmsd_backbone_nm**
  - 150–175 ns: mean=0.5552, std=0.0164, n=2500
  - 175–200 ns: mean=0.5367, std=0.0177, n=2500
  - slope(150–200 ns): **-0.000476** per ns
- **rmsd_ligand_nm**
  - 150–175 ns: mean=0.9181, std=0.0961, n=2500
  - 175–200 ns: mean=1.0243, std=0.0364, n=2500
  - slope(150–200 ns): **0.004676** per ns
- **Rg_protein_nm**
  - 150–175 ns: mean=2.1893, std=0.0064, n=2501
  - 175–200 ns: mean=2.1880, std=0.0055, n=2501
  - slope(150–200 ns): **-0.000047** per ns
- **mindist_protein_lig_nm**
  - 150–175 ns: mean=0.2092, std=0.0097, n=2501
  - 175–200 ns: mean=0.2109, std=0.0097, n=2501
  - slope(150–200 ns): **0.000079** per ns
- **contacts_0p35nm**
  - 150–175 ns: mean=145.8469, std=21.1541, n=2501
  - 175–200 ns: mean=139.5414, std=15.0801, n=2501
  - slope(150–200 ns): **-0.371109** per ns

### monomer_alpha_rep2

- **rmsd_backbone_nm**
  - 150–175 ns: mean=0.5890, std=0.0124, n=2500
  - 175–200 ns: mean=0.6014, std=0.0153, n=2500
  - slope(150–200 ns): **0.000610** per ns
- **rmsd_ligand_nm**
  - 150–175 ns: mean=0.4104, std=0.0283, n=2500
  - 175–200 ns: mean=0.9045, std=2.3358, n=2500
  - slope(150–200 ns): **0.001348** per ns
- **Rg_protein_nm**
  - 150–175 ns: mean=2.2238, std=0.0055, n=2501
  - 175–200 ns: mean=2.2143, std=0.0062, n=2501
  - slope(150–200 ns): **-0.000267** per ns
- **mindist_protein_lig_nm**
  - 150–175 ns: mean=0.2139, std=0.0097, n=2501
  - 175–200 ns: mean=0.2142, std=0.0097, n=2501
  - slope(150–200 ns): **-0.000014** per ns
- **contacts_0p35nm**
  - 150–175 ns: mean=153.7349, std=15.8043, n=2501
  - 175–200 ns: mean=161.6265, std=15.9552, n=2501
  - slope(150–200 ns): **0.224634** per ns

### monomer_beta_rep1

- **rmsd_backbone_nm**
  - 150–175 ns: mean=0.3702, std=0.0839, n=2500
  - 175–200 ns: mean=0.3570, std=0.0679, n=2500
  - slope(150–200 ns): **-0.002149** per ns
- **rmsd_ligand_nm**
  - 150–175 ns: mean=0.5846, std=0.0189, n=2500
  - 175–200 ns: mean=0.5724, std=0.0199, n=2500
  - slope(150–200 ns): **-0.000520** per ns
- **Rg_protein_nm**
  - 150–175 ns: mean=2.2139, std=0.0202, n=2501
  - 175–200 ns: mean=2.1906, std=0.0213, n=2501
  - slope(150–200 ns): **-0.001205** per ns
- **mindist_protein_lig_nm**
  - 150–175 ns: mean=0.2100, std=0.0088, n=2501
  - 175–200 ns: mean=0.2099, std=0.0094, n=2501
  - slope(150–200 ns): **0.000001** per ns
- **contacts_0p35nm**
  - 150–175 ns: mean=169.2619, std=15.0698, n=2501
  - 175–200 ns: mean=164.0052, std=14.9018, n=2501
  - slope(150–200 ns): **-0.205136** per ns

### monomer_beta_rep2

- **rmsd_backbone_nm**
  - 150–175 ns: mean=0.4436, std=0.0360, n=2500
  - 175–200 ns: mean=0.4171, std=0.0238, n=2500
  - slope(150–200 ns): **-0.000564** per ns
- **rmsd_ligand_nm**
  - 150–175 ns: mean=7.7191, std=4.3415, n=2500
  - 175–200 ns: mean=7.1251, std=4.1974, n=2500
  - slope(150–200 ns): **0.007266** per ns
- **Rg_protein_nm**
  - 150–175 ns: mean=2.2010, std=0.0073, n=2501
  - 175–200 ns: mean=2.1890, std=0.0136, n=2501
  - slope(150–200 ns): **-0.000495** per ns
- **mindist_protein_lig_nm**
  - 150–175 ns: mean=0.2101, std=0.0103, n=2501
  - 175–200 ns: mean=0.2106, std=0.0094, n=2501
  - slope(150–200 ns): **0.000012** per ns
- **contacts_0p35nm**
  - 150–175 ns: mean=187.5558, std=16.2641, n=2501
  - 175–200 ns: mean=183.1204, std=15.7870, n=2501
  - slope(150–200 ns): **-0.158669** per ns

## In-progress runs (not used for late-window stats)

- `monomer_alpha_rep3`: checkpoint **~185.2 ns** (still running; snapshot 2026-05-01)

- `monomer_beta_rep3`: checkpoint **~41.5 ns** (still running; snapshot 2026-05-01)

## Recommendations

### Dimer (rep1, 300–350 ns)

- **Binding-site proxies look stable:** `mindist` slope **+4.5e-5 nm/ns** (flat); `contacts` slope **+0.091 /ns** (slow increase, not a collapse).
- **Whole-complex geometry still drifts:** `Rg` slope **+0.00668 nm/ns** and backbone RMSD slope **+0.00281 nm/ns** (slow upward drift vs plateau).
- **Verdict:** **不必为了“配体是否还在结合位点”而延长**；若论文/审稿更在意“整体结构是否已进入平台期”，**建议再加 50 ns 到 400 ns** 复核 350–400 ns 是否趋于平稳。否则 **350 ns 可接受**（用结合位点指标支撑）。

### Monomer (150–200 ns, 已完成 rep)

- **mindist（蛋白–配体最近距离）四条轨迹斜率都接近 0**：结合几何没有系统性“越跑越远离”。
- **contacts 有升有降**（例如 α1 末段略降、α2 末段略升），更像 **接触网络重排/噪声**，不是一边倒的崩解信号。
- **配体 RMSD（相对 backbone fit）**：β2 末段均值高且方差大（`rmsd_ligand` 175–200 ns std ~4.2 nm），更像是 **配体内部构象/取向自由度大**；但 **mindist 仍稳定**，因此 **不等于已明显解离**。
- **Verdict（基于已完成 α1/α2、β1/β2）：** **默认不需要把 monomer 从 200 ns 再系统性延长**；更关键的是 **等 α3、β3 跑完后**对它们重复同一套 150–200 ns 检查。若某条 replicate 在末段出现 **mindist 持续下降 + contacts 持续下降** 或 **ligand RMSD 单调发散**，再单独延长那条即可。

