#!/usr/bin/env bash
#
# Regenerate FEL (gmx sham → XPM → TXT → TIFF) for:
# - Supplement: monomer_{alpha,beta}_rep{1,2,3}
# - Main: combined/{alpha,beta} (and a side-by-side α|β panel)
#
# Inputs:
# - analysis_revision/raw_xvg/<system_id>/gsham_input_rg_rmsdBB_plain.xvg
# - analysis_revision/fel/combined/{alpha,beta}/gsham_input_rg_rmsdBB_plain.xvg
#
# Outputs (not committed to git by default; see `.gitignore`):
# - analysis_revision/fel/<system_id>/{FES.xpm,free_energy_landscape_kjmol.txt,gibbs_*.tif}
# - analysis_revision/figures/fel_combined_*.tif
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REV_EXEC="$(cd "$SCRIPT_DIR/.." && pwd)"

GMX="${GMX:-${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx}"
XPM2TXT="$REV_EXEC/analysis/external/gromacs-gibbs-pipeline/scripts/xpm2txt.py"
PLOT="$REV_EXEC/analysis/external/gromacs-gibbs-pipeline/scripts/plot_gibbs_landscape.py"

RAW="$SCRIPT_DIR/raw_xvg"
FEL="$SCRIPT_DIR/fel"
FIG="$SCRIPT_DIR/figures"

ZMAX="${ZMAX:-5}"
ENERGY_UNIT="${ENERGY_UNIT:-kcal_mol}"
DPI="${DPI:-300}"

[[ -x "$GMX" ]] || { echo "ERROR: GMX not executable: $GMX" >&2; exit 1; }
[[ -f "$XPM2TXT" ]] || { echo "ERROR: missing $XPM2TXT" >&2; exit 1; }
[[ -f "$PLOT" ]] || { echo "ERROR: missing $PLOT" >&2; exit 1; }

make_one_from_gsham_input() {
  local sys="$1" in="$2" outdir="$3"
  mkdir -p "$outdir"
  cp -f "$in" "$outdir/gsham_input_rg_rmsdBB_plain.xvg"
  pushd "$outdir" >/dev/null

  "$GMX" sham -f gsham_input_rg_rmsdBB_plain.xvg \
    -ls FES.xpm -lsh enthalpy.xpm -lss entropy.xpm -lp prob.xpm >/dev/null 2>&1

  python "$XPM2TXT" -f FES.xpm -o free_energy_landscape_kjmol.txt

  python "$PLOT" \
    --input free_energy_landscape_kjmol.txt \
    --output "gibbs_rg_rmsd_${sys}_zcap${ZMAX}.tif" \
    --format tif \
    --dpi "$DPI" \
    --energy-unit "$ENERGY_UNIT" \
    --z-max "$ZMAX" \
    --xlabel "Rg (nm)" \
    --ylabel "Backbone RMSD (nm)" \
    --title "FEL (${sys}; z capped at ${ZMAX} ${ENERGY_UNIT})" >/dev/null

  popd >/dev/null
}

echo "== FEL supplement: monomer alpha/beta rep1-3 =="
for sys in monomer_alpha_rep1 monomer_alpha_rep2 monomer_alpha_rep3 monomer_beta_rep1 monomer_beta_rep2 monomer_beta_rep3; do
  in="$RAW/$sys/gsham_input_rg_rmsdBB_plain.xvg"
  [[ -f "$in" ]] || { echo "ERROR: missing input $in" >&2; exit 1; }
  make_one_from_gsham_input "$sys" "$in" "$FEL/$sys"
done

echo "== FEL main: combined alpha/beta =="
for st in alpha beta; do
  in="$FEL/combined/$st/gsham_input_rg_rmsdBB_plain.xvg"
  [[ -f "$in" ]] || { echo "ERROR: missing combined input $in" >&2; exit 1; }
  make_one_from_gsham_input "combined_${st}" "$in" "$FEL/combined/$st"
done

mkdir -p "$FIG"
cp -f "$FEL/combined/alpha/gibbs_rg_rmsd_combined_alpha_zcap${ZMAX}.tif" "$FIG/fel_combined_alpha_zcap${ZMAX}.tif" || true
cp -f "$FEL/combined/beta/gibbs_rg_rmsd_combined_beta_zcap${ZMAX}.tif"   "$FIG/fel_combined_beta_zcap${ZMAX}.tif"  || true

echo "== FEL main panel: side-by-side (alpha | beta) =="
python - <<PY
from PIL import Image
from pathlib import Path

zmax = "${ZMAX}"
fig = Path("${FIG}")
a_path = fig / f"fel_combined_alpha_zcap{zmax}.tif"
b_path = fig / f"fel_combined_beta_zcap{zmax}.tif"

a = Image.open(a_path).convert("RGB")
b = Image.open(b_path).convert("RGB")

h = max(a.size[1], b.size[1])
def pad_to_h(im, h):
    if im.size[1] == h:
        return im
    out = Image.new("RGB", (im.size[0], h), (255, 255, 255))
    out.paste(im, (0, (h - im.size[1]) // 2))
    return out

a2 = pad_to_h(a, h)
b2 = pad_to_h(b, h)

pad = 40
panel = Image.new("RGB", (a2.size[0] + pad + b2.size[0], h), (255, 255, 255))
panel.paste(a2, (0, 0))
panel.paste(b2, (a2.size[0] + pad, 0))

out = fig / f"fel_combined_alpha_beta_zcap{zmax}.tif"
panel.save(out, format="TIFF", compression="tiff_lzw", dpi=(int("${DPI}"), int("${DPI}")))
print(out)
PY

echo "OK"
#!/usr/bin/env bash
#
# Regenerate FEL (gmx sham → XPM → TXT → TIFF) for:
# - Supplement: monomer_{alpha,beta}_rep{1,2,3}
# - Main: combined/{alpha,beta} (and a side-by-side α|β panel)
#
# Inputs:
# - analysis_revision/raw_xvg/<system_id>/gsham_input_rg_rmsdBB_plain.xvg
# - analysis_revision/fel/combined/{alpha,beta}/gsham_input_rg_rmsdBB_plain.xvg
#
# Outputs (not committed to git by default; see `.gitignore`):
# - analysis_revision/fel/<system_id>/{FES.xpm,free_energy_landscape_kjmol.txt,gibbs_*.tif}
# - analysis_revision/figures/fel_combined_*.tif
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REV_EXEC="$(cd "$SCRIPT_DIR/.." && pwd)"

GMX="${GMX:-${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx}"
XPM2TXT="$REV_EXEC/analysis/external/gromacs-gibbs-pipeline/scripts/xpm2txt.py"
PLOT="$REV_EXEC/analysis/external/gromacs-gibbs-pipeline/scripts/plot_gibbs_landscape.py"

RAW="$SCRIPT_DIR/raw_xvg"
FEL="$SCRIPT_DIR/fel"
FIG="$SCRIPT_DIR/figures"

ZMAX="${ZMAX:-5}"
ENERGY_UNIT="${ENERGY_UNIT:-kcal_mol}"
DPI="${DPI:-300}"

[[ -x "$GMX" ]] || { echo "ERROR: GMX not executable: $GMX" >&2; exit 1; }
[[ -f "$XPM2TXT" ]] || { echo "ERROR: missing $XPM2TXT" >&2; exit 1; }
[[ -f "$PLOT" ]] || { echo "ERROR: missing $PLOT" >&2; exit 1; }

make_one_from_gsham_input() {
  local sys="$1" in="$2" outdir="$3"
  mkdir -p "$outdir"
  cp -f "$in" "$outdir/gsham_input_rg_rmsdBB_plain.xvg"
  pushd "$outdir" >/dev/null

  "$GMX" sham -f gsham_input_rg_rmsdBB_plain.xvg \
    -ls FES.xpm -lsh enthalpy.xpm -lss entropy.xpm -lp prob.xpm >/dev/null 2>&1

  python "$XPM2TXT" -f FES.xpm -o free_energy_landscape_kjmol.txt

  python "$PLOT" \
    --input free_energy_landscape_kjmol.txt \
    --output "gibbs_rg_rmsd_${sys}_zcap${ZMAX}.tif" \
    --format tif \
    --dpi "$DPI" \
    --energy-unit "$ENERGY_UNIT" \
    --z-max "$ZMAX" \
    --xlabel "Rg (nm)" \
    --ylabel "Backbone RMSD (nm)" \
    --title "FEL (${sys}; z capped at ${ZMAX} ${ENERGY_UNIT})" >/dev/null

  popd >/dev/null
}

echo "== FEL supplement: monomer alpha/beta rep1-3 =="
for sys in monomer_alpha_rep1 monomer_alpha_rep2 monomer_alpha_rep3 monomer_beta_rep1 monomer_beta_rep2 monomer_beta_rep3; do
  in="$RAW/$sys/gsham_input_rg_rmsdBB_plain.xvg"
  [[ -f "$in" ]] || { echo "ERROR: missing input $in" >&2; exit 1; }
  make_one_from_gsham_input "$sys" "$in" "$FEL/$sys"
done

echo "== FEL main: combined alpha/beta =="
for st in alpha beta; do
  in="$FEL/combined/$st/gsham_input_rg_rmsdBB_plain.xvg"
  [[ -f "$in" ]] || { echo "ERROR: missing combined input $in" >&2; exit 1; }
  make_one_from_gsham_input "combined_${st}" "$in" "$FEL/combined/$st"
done

mkdir -p "$FIG"
cp -f "$FEL/combined/alpha/gibbs_rg_rmsd_combined_alpha_zcap${ZMAX}.tif" "$FIG/fel_combined_alpha_zcap${ZMAX}.tif" || true
cp -f "$FEL/combined/beta/gibbs_rg_rmsd_combined_beta_zcap${ZMAX}.tif"   "$FIG/fel_combined_beta_zcap${ZMAX}.tif"  || true

echo "== FEL main panel: side-by-side (alpha | beta) =="
python - <<PY
from PIL import Image
from pathlib import Path

zmax = "${ZMAX}"
fig = Path("${FIG}")
a_path = fig / f"fel_combined_alpha_zcap{zmax}.tif"
b_path = fig / f"fel_combined_beta_zcap{zmax}.tif"

a = Image.open(a_path).convert("RGB")
b = Image.open(b_path).convert("RGB")

h = max(a.size[1], b.size[1])
def pad_to_h(im, h):
    if im.size[1] == h:
        return im
    out = Image.new("RGB", (im.size[0], h), (255, 255, 255))
    out.paste(im, (0, (h - im.size[1]) // 2))
    return out

a2 = pad_to_h(a, h)
b2 = pad_to_h(b, h)

pad = 40
panel = Image.new("RGB", (a2.size[0] + pad + b2.size[0], h), (255, 255, 255))
panel.paste(a2, (0, 0))
panel.paste(b2, (a2.size[0] + pad, 0))

out = fig / f"fel_combined_alpha_beta_zcap{zmax}.tif"
panel.save(out, format="TIFF", compression="tiff_lzw", dpi=(int("${DPI}"), int("${DPI}")))
print(out)
PY

echo "OK"
