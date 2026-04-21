#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Checking gmx availability"
if ! command -v gmx >/dev/null 2>&1; then
  echo "ERROR: gmx not found in PATH. Activate gmx-lite first."
  exit 1
fi
gmx --version | sed -n '1,8p'

echo "[2/3] Checking core input files"
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required=(
  "${BASE}/input/5IJ0.pdb"
  "${BASE}/input/protenix_pose1_abTub_CPPF.pdb"
  "${BASE}/input/mdp/em.mdp"
  "${BASE}/input/mdp/nvt.mdp"
  "${BASE}/input/mdp/npt.mdp"
  "${BASE}/input/mdp/ions.mdp"
)

for f in "${required[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "ERROR: missing ${f}"
    exit 1
  fi
done
echo "Core inputs found."

echo "[3/3] Checking optional MM-PBSA command"
if command -v gmx_MMPBSA >/dev/null 2>&1; then
  echo "Found gmx_MMPBSA in PATH."
else
  echo "NOTE: gmx_MMPBSA not found in current PATH yet."
fi

echo "Environment check finished."
