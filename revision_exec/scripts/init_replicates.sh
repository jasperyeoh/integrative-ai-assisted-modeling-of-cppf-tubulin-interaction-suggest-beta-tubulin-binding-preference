#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_MDP_DIR="${ROOT_DIR}/input/mdp"

mkdir -p "${ROOT_DIR}/rep1/nvt" "${ROOT_DIR}/rep2/nvt" "${ROOT_DIR}/rep3/nvt"

cp "${INPUT_MDP_DIR}/nvt.mdp" "${ROOT_DIR}/rep1/nvt/nvt_rep1.mdp"
cp "${INPUT_MDP_DIR}/nvt.mdp" "${ROOT_DIR}/rep2/nvt/nvt_rep2.mdp"
cp "${INPUT_MDP_DIR}/nvt.mdp" "${ROOT_DIR}/rep3/nvt/nvt_rep3.mdp"

# Set replicate-specific random seeds for independent velocity initialization.
sed -i 's/^gen_seed.*/gen_seed = 11001/' "${ROOT_DIR}/rep1/nvt/nvt_rep1.mdp" || true
sed -i 's/^gen_seed.*/gen_seed = 22002/' "${ROOT_DIR}/rep2/nvt/nvt_rep2.mdp" || true
sed -i 's/^gen_seed.*/gen_seed = 33003/' "${ROOT_DIR}/rep3/nvt/nvt_rep3.mdp" || true

echo "Replicate NVT files initialized under:"
echo "  ${ROOT_DIR}/rep{1,2,3}/nvt/"
