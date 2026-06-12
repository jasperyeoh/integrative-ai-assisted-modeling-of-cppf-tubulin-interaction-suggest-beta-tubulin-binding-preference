#!/usr/bin/env bash
# Resume 6E7B prep from EM (ions + index already done).
set -eo pipefail

REPO="/root/autodl-tmp/tubulin-cppf-md"
WORK="${REPO}/revision_exec_6e7b"
NTOMP=$(nproc)

eval "$(conda shell.bash hook)"
conda activate gmx-lite
cd "${WORK}"

GMX_GPU="-nb gpu -pme gpu -bonded gpu -update gpu -gpu_id 0"

echo "[G] EM / NVT / NPT (GPU)..."
gmx grompp -f prep/mdp/em.mdp -c prep/solv_ions.gro -p prep/topol.top \
  -o prep/em.tpr -n prep/index.ndx -maxwarn 2
gmx mdrun -v -deffnm prep/em -ntomp "${NTOMP}"
grep -E "Maximum force|Potential Energy" prep/em.log | tail -3

gmx grompp -f prep/mdp/nvt.mdp -c prep/em.gro -r prep/em.gro \
  -p prep/topol.top -n prep/index.ndx -o prep/nvt.tpr -maxwarn 2
gmx mdrun -v -deffnm prep/nvt -ntomp "${NTOMP}" ${GMX_GPU}
grep "Temperature" prep/nvt.log | tail -3

gmx grompp -f prep/mdp/npt.mdp -c prep/nvt.gro -r prep/nvt.gro -t prep/nvt.cpt \
  -p prep/topol.top -n prep/index.ndx -o prep/npt.tpr -maxwarn 2
gmx mdrun -v -deffnm prep/npt -ntomp "${NTOMP}" ${GMX_GPU}
grep -E "Density|Pressure" prep/npt.log | tail -4

echo "[H] grompp production (200 ns) for rep1..."
gmx grompp -f prep/mdp/md_prod_200ns.mdp -c prep/npt.gro -t prep/npt.cpt \
  -p prep/topol.top -n prep/index.ndx -o md/rep1/md_200ns.tpr -maxwarn 2

echo "Pipeline complete. TPR: md/rep1/md_200ns.tpr"
