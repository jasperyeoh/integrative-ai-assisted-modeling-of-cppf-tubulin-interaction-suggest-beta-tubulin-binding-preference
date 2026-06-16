#!/usr/bin/env bash
# Recover from gmx_MMPBSA trjconv zombie: pre-extract last-50ns xtc, then run GB MM-PBSA.
set -eo pipefail

WORK6E7B="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MMPBSA_DIR="${WORK6E7B}/analysis/mmpbsa"
export PATH="/root/miniconda3/envs/gmx-lite/bin.AVX2_256:${PATH}"
export TMPDIR="${TMPDIR:-/root/autodl-tmp/tmp}"
mkdir -p "${TMPDIR}"

eval "$(conda shell.bash hook)"
conda activate gmx-lite
conda activate mmpbsa_py311

GMX_MMPBSA="$(which gmx_MMPBSA)"
[[ -x "$GMX_MMPBSA" ]] || { echo "ERROR: gmx_MMPBSA not in mmpbsa_py311"; exit 1; }

# Auto-detect Protein / CPP (Other) groups
NDX="${WORK6E7B}/prep/index.ndx"
PROT_IDX="$(gmx make_ndx -f "${WORK6E7B}/prep/em.gro" -n "$NDX" -o /dev/null 2>&1 <<< "q" | awk '/Protein +:/ {print $1; exit}')"
CPP_IDX="$(gmx make_ndx -f "${WORK6E7B}/prep/em.gro" -n "$NDX" -o /dev/null 2>&1 <<< "q" | awk '/Other +:/ {print $1; exit}')"
PROT_IDX="${PROT_IDX:-1}"
CPP_IDX="${CPP_IDX:-12}"
echo "Groups: Protein=${PROT_IDX}  CPP=${CPP_IDX}"

echo "=== Step 1: Pre-extract last-50ns subsampled xtc (51 frames) ==="
cd "${WORK6E7B}"
for i in 1 2 3; do
    REP="rep${i}"
    TPR="md/${REP}/md_200ns.tpr"
    XTC="md/${REP}/md_200ns.xtc"
    OUT="md/${REP}/md_200ns_last50ns_sub.xtc"
    [[ -f "$TPR" && -f "$XTC" ]] || { echo "ERROR: missing $TPR or $XTC"; exit 1; }
    if [[ -f "${OUT}" ]]; then
        echo "${REP}: ${OUT} exists, skip"
    else
        echo "${REP}: extracting 150-200 ns @ 1 ns interval..."
        echo "System" | gmx trjconv \
            -s "${TPR}" -f "${XTC}" -o "${OUT}" \
            -b 150000 -e 200000 -skip 100 \
            -pbc mol -ur compact
    fi
    ls -lh "${OUT}"
done

echo ""
echo "=== Step 2: MM-PBSA-GB per rep (presampled xtc) ==="
cd "${MMPBSA_DIR}"
INFILE="${MMPBSA_DIR}/mmpbsa_6e7b_presampled_gb.in"
[[ -f "$INFILE" ]] || { echo "ERROR: $INFILE missing"; exit 1; }

for i in 1 2 3; do
    REP="rep${i}"
    WORKDIR="${MMPBSA_DIR}/work_${REP}_full"
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"
    cd "${WORKDIR}"
    echo "=== ${REP} ==="
    "$GMX_MMPBSA" -O -nogui \
        -i "${INFILE}" \
        -cs "${WORK6E7B}/md/${REP}/md_200ns.tpr" \
        -ci "${WORK6E7B}/prep/index.ndx" \
        -cg "${PROT_IDX}" "${CPP_IDX}" \
        -cp "${WORK6E7B}/prep/topol.top" \
        -ct "${WORK6E7B}/md/${REP}/md_200ns_last50ns_sub.xtc" \
        -eo "${REP}_last50ns_gb_perframe.csv" \
        -o "${REP}_last50ns_gb_FINAL_RESULTS.dat" \
        2>&1 | tee "mmpbsa_${REP}.log"
    echo "${REP} done."
done

echo ""
echo "=== Step 3: Summarize ==="
SUMMARIZE_PY="${WORK6E7B}/../revision_exec/analysis/mmpbsa/summarize_mmpbsa_gb_last50ns.py"
SUMMARY_CSV="${MMPBSA_DIR}/6e7b_mmpbsa_summary.csv"
python3 "${SUMMARIZE_PY}" \
    --rep1 "${MMPBSA_DIR}/work_rep1_full/rep1_last50ns_gb_FINAL_RESULTS.dat" \
    --rep2 "${MMPBSA_DIR}/work_rep2_full/rep2_last50ns_gb_FINAL_RESULTS.dat" \
    --rep3 "${MMPBSA_DIR}/work_rep3_full/rep3_last50ns_gb_FINAL_RESULTS.dat" \
    --out-csv "${SUMMARY_CSV}" \
    --n-frames 51

echo ""
echo "Summary: ${SUMMARY_CSV}"
cat "${SUMMARY_CSV}"
