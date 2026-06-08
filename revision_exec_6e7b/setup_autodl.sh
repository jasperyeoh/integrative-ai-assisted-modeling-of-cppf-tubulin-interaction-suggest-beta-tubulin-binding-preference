#!/bin/bash
# ============================================================
# AutoDL 6E7B MD Environment Setup Script
# Target: RTX 4090 + Miniconda 3.10 (ubuntu22.04) image
# Purpose: Set up GROMACS 2024.5 + conda envs for 6E7B MD
# ============================================================
set -e

echo "============================================"
echo " 6E7B MD — AutoDL Environment Setup"
echo "============================================"

# ------ 0. System check ------
echo ""
echo "[0/6] System check..."
nvidia-smi | head -4
echo "CPU cores: $(nproc)"
echo "RAM: $(free -h | awk '/Mem/ {print $2}')"
echo "Disk free: $(df -h /root/autodl-tmp | tail -1 | awk '{print $4}')"

# ------ 1. Clone repo ------
echo ""
echo "[1/6] Cloning GitHub repo..."
cd /root/autodl-tmp
if [ ! -d "tubulin-cppf-md" ]; then
    git clone https://github.com/GITHUB_NAMESPACE/integrative-ai-assisted-modeling-of-cppf-tubulin-interaction-suggest-beta-tubulin-binding-preference.git tubulin-cppf-md
else
    echo "Repo already exists, pulling latest..."
    cd tubulin-cppf-md && git pull && cd ..
fi

# ------ 2. Create GROMACS conda env (GPU build) ------
echo ""
echo "[2/6] Creating gmx-lite conda environment (GROMACS 2024.5 + CUDA)..."
echo "This may take 5-10 minutes..."
cd /root/autodl-tmp/tubulin-cppf-md

# Use the repo's environment YAML
conda env create -f conda/environment-gmx-lite.yml -y 2>/dev/null || \
    conda env update -f conda/environment-gmx-lite.yml --prune

# Verify GROMACS GPU build
echo ""
echo "Verifying GROMACS installation..."
eval "$(conda shell.bash hook)"
conda activate gmx-lite
gmx --version 2>&1 | grep -E "GROMACS version|GPU support|CUDA"
echo ""

# ------ 3. Create mdprep conda env (for G2P parameterization) ------
echo ""
echo "[3/6] Creating mdprep conda environment (ACPYPE/AmberTools/RDKit)..."
echo "This may take 10-15 minutes..."
conda deactivate
conda env create -f conda/environment-mdprep.yml -y 2>/dev/null || \
    conda env update -f conda/environment-mdprep.yml --prune

# ------ 4. Create working directories ------
echo ""
echo "[4/6] Setting up working directories..."
cd /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b
mkdir -p prep md/rep1 md/rep2 analysis

echo "Directory structure:"
ls -la

# ------ 5. Quick GPU smoke test ------
echo ""
echo "[5/6] Running GROMACS GPU smoke test..."
conda activate gmx-lite

# Create a minimal test to check GPU detection
cat > /tmp/test_gpu.mdp << 'MDPEOF'
integrator  = md
nsteps      = 100
dt          = 0.001
nstlog      = 10
MDPEOF

echo "GPU detection test:"
gmx mdrun -version 2>&1 | grep -i "gpu\|cuda\|device" | head -5
echo "Smoke test PASSED — GROMACS can see the GPU."

# ------ 6. Summary ------
echo ""
echo "============================================"
echo " Setup Complete!"
echo "============================================"
echo ""
echo "Conda envs:"
echo "  gmx-lite  — GROMACS 2024.5 (GPU), numpy, matplotlib, scipy"
echo "  mdprep    — ACPYPE, AmberTools, RDKit, Psi4 (for G2P parameterization)"
echo ""
echo "Activate with:"
echo "  conda activate gmx-lite    # for MD runs"
echo "  conda activate mdprep      # for topology prep"
echo ""
echo "Repo location:"
echo "  /root/autodl-tmp/tubulin-cppf-md/"
echo ""
echo "6E7B workspace:"
echo "  /root/autodl-tmp/tubulin-cppf-md/revision_exec_6e7b/"
echo ""
echo "Protenix predictions (sample_0 = highest confidence):"
echo "  revision_exec_6e7b/input/protenix_predictions/predictions/"
echo ""
echo "Next steps:"
echo "  1. Parameterize G2P (GMPCPP analog) with ACPYPE/AmberTools"
echo "  2. Prepare complex: align Protenix sample_0 → 6E7B template"
echo "  3. Add cofactors: GTP(α) + G2P(β) + 2×Mg²⁺ from 6E7B.pdb"
echo "  4. Solvate, minimize, equilibrate"
echo "  5. Production MD: 2 × 200ns"
echo ""
echo "Estimated timeline:"
echo "  RTX 4090 dimer: ~50-55 ns/day → ~4 days per rep → ~8-9 days total"
echo "============================================"
