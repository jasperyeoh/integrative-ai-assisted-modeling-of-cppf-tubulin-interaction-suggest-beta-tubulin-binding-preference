#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
 * CPPF–Tubulin Phase 1 Nextflow workflow
 *
 * Scope:
 *   Stages 3–6 from the revision plan: prepared topology handoff,
 *   EM/NVT/NPT, production MD, PBC correction, XVG export, MM-PBSA,
 *   FEL calculation, figure generation, and summary reporting.
 *
 * Design note:
 *   The RESP2/cofactor/topology route is already gate-validated in
 *   revision_exec/prep. This workflow starts from those locked assets by
 *   default rather than pretending that cofactor parameterization is a
 *   single generic command. Full docking/topology construction remains
 *   Phase 2 / optional extension.
 */

// ── Parameters ─────────────────────────────────────────────────────────────
params.outdir              = "revision_exec/nf_output"
params.repo_root           = null
params.stage               = "full"           // prepare_topology | prepare_and_equil | full
params.system              = "dimer"
params.replicates          = [1, 2, 3]
params.seeds               = [11001, 22002, 33003]
params.smoke               = false
params.skip_mmpbsa          = false

// Locked / gate-validated inputs.
params.input_complex        = "revision_exec/prep/complex_start_clean.pdb"
params.prepared_gro         = "revision_exec/prep/solv_ions_cppf.gro"
params.topology_file        = "revision_exec/prep/gate_topol.top"
params.index_file           = "revision_exec/input/index.ndx"
params.mdp_dir              = "revision_exec/input/mdp"
params.em_mdp               = "${params.mdp_dir}/em.mdp"
params.nvt_mdp              = "${params.mdp_dir}/nvt.mdp"
params.npt_mdp              = "${params.mdp_dir}/npt.mdp"
params.prod_mdp             = "${params.mdp_dir}/md_prod_200ns.mdp"
params.production_nsteps    = 200000000       // 400 ns at dt=0.002 ps
params.production_prefix    = "md_400ns"
params.grompp_maxwarn       = 1               // known gate warning: ligand atom-name mismatch

// Executables / helper scripts.
params.gmx_bin              = "${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256/gmx"
params.gmx_mmpbsa_bin       = "${HPC_WORKSPACE}/miniconda3/envs/mmpbsa/bin/gmx_MMPBSA"
params.mmpbsa_env_bin       = "${HPC_WORKSPACE}/miniconda3/envs/mmpbsa/bin"
params.gmx_env_bin          = "${HPC_WORKSPACE}/miniconda3/envs/gmx-lite/bin.AVX2_256"
params.analysis_revision_dir = "revision_exec/analysis_revision"
params.mmpbsa_dir           = "revision_exec/analysis/mmpbsa"
params.gibbs_scripts_dir    = "revision_exec/analysis/external/gromacs-gibbs-pipeline/scripts"

// Analysis settings.
params.mmpbsa_input_full    = "${params.mmpbsa_dir}/mmpbsa_dimer_rep1_last50ns_gb.in"
params.mmpbsa_input_smoke   = "${params.mmpbsa_dir}/mmpbsa_dimer_rep1_smoke_gb.in"
params.mmpbsa_start_ps      = 350000
params.mmpbsa_end_ps        = 400000
params.fel_zmax             = 5
params.fel_energy_unit      = "kcal_mol"
params.dpi                  = 300
params.mdrun_em_flags       = ""
params.mdrun_equil_flags    = ""
params.mdrun_prod_flags     = "-nb gpu -pme gpu -bonded gpu -update gpu"

def seedForRep(rep_id) {
    def reps = params.replicates as List
    def seeds = params.seeds as List
    def idx = reps.indexOf(rep_id)
    if (idx < 0 || idx >= seeds.size()) {
        throw new IllegalArgumentException("No seed configured for replicate ${rep_id}")
    }
    return seeds[idx]
}

def absPath(p) {
    def root = params.repo_root ? file(params.repo_root).toString() : launchDir.toString()
    def s = p.toString()
    return s.startsWith('/') ? s : "${root}/${s}"
}

// ── Processes ──────────────────────────────────────────────────────────────

process RESP2_CHARGES {
    tag "stub"
    publishDir "${params.outdir}/prep/resp2", mode: 'copy'

    output:
    path "RESP2_CHARGES_STUB.txt", emit: stub

    script:
    """
    cat > RESP2_CHARGES_STUB.txt <<'EOF'
    RESP2 charge generation is intentionally not re-run by the Phase 1
    Nextflow workflow. The revision uses the locked RESP2/GAFF2 ligand
    assets documented in docs/RUNBOOK.md and revision_exec/input/ligand/.
    EOF
    """
}

process PREPARE_TOPOLOGY_PROC {
    tag "${params.system}"
    publishDir "${params.outdir}/prep", mode: 'copy'

    input:
    path input_complex

    output:
    tuple path("complex_start_clean.pdb"), path("solv_ions_cppf.gro"), path("gate_topol.top"), path("index.ndx"), emit: prepared
    path "PREPARE_TOPOLOGY_MANIFEST.txt", emit: manifest

    script:
    """
    set -euo pipefail

    for f in "${absPath(params.prepared_gro)}" "${absPath(params.topology_file)}" "${absPath(params.index_file)}" "${absPath(params.em_mdp)}" "${absPath(params.nvt_mdp)}" "${absPath(params.npt_mdp)}" "${absPath(params.prod_mdp)}"; do
      [[ -f "\$f" ]] || { echo "ERROR: missing required input \$f" >&2; exit 1; }
    done

    if [[ "${input_complex}" != "complex_start_clean.pdb" ]]; then
      cp -f "${input_complex}" complex_start_clean.pdb
    fi
    cp -f "${absPath(params.prepared_gro)}" solv_ions_cppf.gro
    cp -f "${absPath(params.topology_file)}" gate_topol.top
    cp -f "${absPath(params.index_file)}" index.ndx

    cat > PREPARE_TOPOLOGY_MANIFEST.txt <<EOF
    system=${params.system}
    input_complex=${absPath(params.input_complex)}
    prepared_gro=${absPath(params.prepared_gro)}
    topology_file=${absPath(params.topology_file)}
    index_file=${absPath(params.index_file)}
    mdp_dir=${absPath(params.mdp_dir)}
    note=Phase 1 starts from gate-validated prepared topology assets.
    EOF
    """
}

process ENERGY_MINIMIZE {
    tag { "rep${rep_id}" }
    publishDir { "${params.outdir}/replicates/rep${rep_id}/em" }, mode: 'copy'

    input:
    tuple val(rep_id), val(seed), path(prepared_gro), path(topology), path(index_file)

    output:
    tuple val(rep_id), val(seed), path("em.gro"), path("em.tpr"), emit: em

    script:
    def override_nsteps = task.ext.nsteps ?: ''
    def maxwarn = params.grompp_maxwarn ? "-maxwarn ${params.grompp_maxwarn}" : ""
    """
    set -euo pipefail
    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"

    cp -f "${absPath(params.em_mdp)}" em.mdp
    if [[ -n "${override_nsteps}" ]]; then
      sed -i -E 's/^nsteps\\s*=.*/nsteps = ${override_nsteps}/' em.mdp
    fi

    "\$GMX" grompp \
      -f em.mdp \
      -c "${prepared_gro}" \
      -p "${absPath(params.topology_file)}" \
      -o em.tpr \
      -n "${index_file}" \
      ${maxwarn}
    "\$GMX" mdrun -deffnm em ${params.mdrun_em_flags}
    """
}

process NVT_EQUIL {
    tag { "rep${rep_id}" }
    publishDir { "${params.outdir}/replicates/rep${rep_id}/nvt" }, mode: 'copy'

    input:
    tuple val(rep_id), val(seed), path(em_gro)

    output:
    tuple val(rep_id), val(seed), path("nvt.gro"), path("nvt.cpt"), path("nvt.tpr"), emit: nvt

    script:
    def override_nsteps = task.ext.nsteps ?: ''
    def maxwarn = params.grompp_maxwarn ? "-maxwarn ${params.grompp_maxwarn}" : ""
    """
    set -euo pipefail
    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"

    cp -f "${absPath(params.nvt_mdp)}" nvt_rep${rep_id}.mdp
    if grep -q '^gen_seed' nvt_rep${rep_id}.mdp; then
      sed -i -E 's/^gen_seed\\s*=.*/gen_seed = ${seed}/' nvt_rep${rep_id}.mdp
    else
      printf '\\ngen_seed = ${seed}\\n' >> nvt_rep${rep_id}.mdp
    fi
    if [[ -n "${override_nsteps}" ]]; then
      sed -i -E 's/^nsteps\\s*=.*/nsteps = ${override_nsteps}/' nvt_rep${rep_id}.mdp
    fi

    "\$GMX" grompp \
      -f nvt_rep${rep_id}.mdp \
      -c "${em_gro}" \
      -r "${em_gro}" \
      -p "${absPath(params.topology_file)}" \
      -o nvt.tpr \
      -n "${absPath(params.index_file)}" \
      ${maxwarn}
    "\$GMX" mdrun -deffnm nvt ${params.mdrun_equil_flags}
    """
}

process NPT_EQUIL {
    tag { "rep${rep_id}" }
    publishDir { "${params.outdir}/replicates/rep${rep_id}/npt" }, mode: 'copy'

    input:
    tuple val(rep_id), val(seed), path(nvt_gro), path(nvt_cpt)

    output:
    tuple val(rep_id), val(seed), path("npt.gro"), path("npt.cpt"), path("npt.tpr"), emit: npt

    script:
    def override_nsteps = task.ext.nsteps ?: ''
    def maxwarn = params.grompp_maxwarn ? "-maxwarn ${params.grompp_maxwarn}" : ""
    """
    set -euo pipefail
    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"

    cp -f "${absPath(params.npt_mdp)}" npt.mdp
    if [[ -n "${override_nsteps}" ]]; then
      sed -i -E 's/^nsteps\\s*=.*/nsteps = ${override_nsteps}/' npt.mdp
    fi

    "\$GMX" grompp \
      -f npt.mdp \
      -c "${nvt_gro}" \
      -r "${nvt_gro}" \
      -t "${nvt_cpt}" \
      -p "${absPath(params.topology_file)}" \
      -o npt.tpr \
      -n "${absPath(params.index_file)}" \
      ${maxwarn}
    "\$GMX" mdrun -deffnm npt ${params.mdrun_equil_flags}
    """
}

process PRODUCTION_MD {
    tag { "rep${rep_id}" }
    publishDir { "${params.outdir}/replicates/rep${rep_id}/prod" }, mode: 'copy'

    input:
    tuple val(rep_id), val(seed), path(npt_gro), path(npt_cpt)

    output:
    tuple val(rep_id), val("dimer_rep${rep_id}"), path("${params.production_prefix}.tpr"), path("${params.production_prefix}.xtc"), emit: prod

    script:
    def nsteps = task.ext.nsteps ?: params.production_nsteps
    def maxwarn = params.grompp_maxwarn ? "-maxwarn ${params.grompp_maxwarn}" : ""
    """
    set -euo pipefail
    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"

    cp -f "${absPath(params.prod_mdp)}" production.mdp
    if grep -q '^nsteps' production.mdp; then
      sed -i -E 's/^nsteps\\s*=.*/nsteps = ${nsteps}/' production.mdp
    else
      printf '\\nnsteps = ${nsteps}\\n' >> production.mdp
    fi

    "\$GMX" grompp \
      -f production.mdp \
      -c "${npt_gro}" \
      -t "${npt_cpt}" \
      -p "${absPath(params.topology_file)}" \
      -o "${params.production_prefix}.tpr" \
      -n "${absPath(params.index_file)}" \
      ${maxwarn}

    if [[ -f "${params.production_prefix}.cpt" ]]; then
      "\$GMX" mdrun -deffnm "${params.production_prefix}" -cpi "${params.production_prefix}.cpt" -append ${params.mdrun_prod_flags}
    else
      "\$GMX" mdrun -deffnm "${params.production_prefix}" ${params.mdrun_prod_flags}
    fi
    """
}

process PBC_CORRECTION {
    tag { sid }
    publishDir { "${params.outdir}/analysis/pbc/${sid}" }, mode: 'copy'

    input:
    tuple val(rep_id), val(sid), path(tpr), path(xtc)

    output:
    tuple val(rep_id), val(sid), path("clean_pbc.xtc"), path("traj.tpr"), emit: clean

    script:
    """
    set -euo pipefail
    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"
    cp -f "${tpr}" traj.tpr

    printf '0\\n' | "\$GMX" trjconv \
      -s traj.tpr \
      -f "${xtc}" \
      -n "${absPath(params.index_file)}" \
      -pbc nojump \
      -o nojump.xtc > trjconv.log 2>&1

    printf '21\\n21\\n0\\n' | "\$GMX" trjconv \
      -s traj.tpr \
      -f nojump.xtc \
      -n "${absPath(params.index_file)}" \
      -pbc cluster \
      -center \
      -o clean_pbc.xtc >> trjconv.log 2>&1
    """
}

process EXPORT_XVG {
    tag { sid }
    publishDir { "${params.outdir}/analysis/raw_xvg/${sid}" }, mode: 'copy'

    input:
    tuple val(rep_id), val(sid), path(clean_xtc), path(tpr)

    output:
    tuple val(rep_id), val(sid), path("${sid}"), emit: xvg

    script:
    """
    set -euo pipefail
    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"
    MERGE="${absPath(params.analysis_revision_dir)}/merge_xvg_for_sham.py"

    mkdir -p "${sid}"
    cd "${sid}"

    printf '4\\n4\\n' | "\$GMX" rms -s "../${tpr}" -f "../${clean_xtc}" -n "${absPath(params.index_file)}" -o rmsd_backbone.xvg -tu ns
    printf '4\\n13\\n' | "\$GMX" rms -s "../${tpr}" -f "../${clean_xtc}" -n "${absPath(params.index_file)}" -o rmsd_ligand.xvg -tu ns
    printf '1\\n13\\n' | "\$GMX" mindist -s "../${tpr}" -f "../${clean_xtc}" -n "${absPath(params.index_file)}" -od mindist_pl.xvg -tu ns
    printf '1\\n13\\n' | "\$GMX" hbond-legacy -f "../${clean_xtc}" -s "../${tpr}" -n "${absPath(params.index_file)}" -num hbond_num.xvg -tu ns
    printf '1\\n' | "\$GMX" gyrate -f "../${clean_xtc}" -s "../${tpr}" -n "${absPath(params.index_file)}" -o rg.xvg -tu ns
    printf '1\\n' | "\$GMX" sasa -s "../${tpr}" -f "../${clean_xtc}" -n "${absPath(params.index_file)}" -o sasa.xvg -tv sasa_volume.xvg -tu ns
    printf '1\\n' | "\$GMX" rmsf -f "../${clean_xtc}" -s "../${tpr}" -n "${absPath(params.index_file)}" -o rmsf_residue.xvg -res

    python3 "\$MERGE" rg.xvg rmsd_backbone.xvg -o gsham_input_rg_rmsdBB_plain.xvg --plain
    """
}

process MMPBSA {
    tag { sid }
    publishDir { "${params.outdir}/analysis/mmpbsa/${sid}" }, mode: 'copy'

    input:
    tuple val(rep_id), val(sid), path(clean_xtc), path(tpr)

    output:
    tuple val(rep_id), val(sid), path("mmpbsa_${sid}"), emit: results

    script:
    def input_file = params.smoke ? absPath(params.mmpbsa_input_smoke) : absPath(params.mmpbsa_input_full)
    """
    set -euo pipefail
    mkdir -p "mmpbsa_${sid}"
    cd "mmpbsa_${sid}"

    if [[ "${params.skip_mmpbsa}" == "true" ]]; then
      cat > last50ns_gb_subsample_FINAL_RESULTS.dat <<'EOF'
Delta (Complex - Receptor - Ligand):
ΔVDWAALS              0.0000        0.0000        0.0000        0.0000
ΔEEL                  0.0000        0.0000        0.0000        0.0000
ΔEGB                  0.0000        0.0000        0.0000        0.0000
ΔESURF                0.0000        0.0000        0.0000        0.0000
ΔTOTAL                0.0000        0.0000        0.0000        0.0000
EOF
      exit 0
    fi

    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"
    export PATH="${params.mmpbsa_env_bin}:${params.gmx_env_bin}:\$PATH"

    if [[ "${params.smoke}" == "true" ]]; then
      cp -f "../${clean_xtc}" mmpbsa_window.xtc
    else
      printf '0\\n' | "\$GMX" trjconv \
        -s "../${tpr}" \
        -f "../${clean_xtc}" \
        -n "${absPath(params.index_file)}" \
        -b "${params.mmpbsa_start_ps}" \
        -e "${params.mmpbsa_end_ps}" \
        -o mmpbsa_window.xtc
    fi

    "${params.gmx_mmpbsa_bin}" -O -nogui \
      -i "${input_file}" \
      -cs "../${tpr}" \
      -ci "${absPath(params.index_file)}" \
      -cg 1 13 \
      -cp "${absPath(params.topology_file)}" \
      -ct mmpbsa_window.xtc \
      -eo last50ns_gb_subsample_perframe.csv \
      -o last50ns_gb_subsample_FINAL_RESULTS.dat
    """
}

process FEL_CALCULATION {
    tag { sid }
    publishDir { "${params.outdir}/analysis/fel/${sid}" }, mode: 'copy'

    input:
    tuple val(rep_id), val(sid), path(raw_dir)

    output:
    tuple val(rep_id), val(sid), path("fel_${sid}"), emit: fel

    script:
    """
    set -euo pipefail
    GMX="${params.gmx_bin}"
    [[ -x "\$GMX" ]] || GMX="\$(command -v gmx)"
    XPM2TXT="${absPath(params.gibbs_scripts_dir)}/xpm2txt.py"
    PLOT="${absPath(params.gibbs_scripts_dir)}/plot_gibbs_landscape.py"

    mkdir -p "fel_${sid}"
    cp -f "${raw_dir}/gsham_input_rg_rmsdBB_plain.xvg" "fel_${sid}/"
    cd "fel_${sid}"

    "\$GMX" sham -f gsham_input_rg_rmsdBB_plain.xvg \
      -ls FES.xpm -lsh enthalpy.xpm -lss entropy.xpm -lp prob.xpm >/dev/null 2>&1
    python "\$XPM2TXT" -f FES.xpm -o free_energy_landscape_kjmol.txt
    python "\$PLOT" \
      --input free_energy_landscape_kjmol.txt \
      --output "gibbs_rg_rmsd_${sid}_zcap${params.fel_zmax}.tif" \
      --format tif \
      --dpi "${params.dpi}" \
      --energy-unit "${params.fel_energy_unit}" \
      --z-max "${params.fel_zmax}" \
      --xlabel "Rg (nm)" \
      --ylabel "Backbone RMSD (nm)" \
      --title "FEL (${sid}; z capped at ${params.fel_zmax} ${params.fel_energy_unit})" >/dev/null
    """
}

process PLOT_DIMER_TIMESERIES {
    tag "dimer_panels"
    publishDir "${params.outdir}/figures", mode: 'copy'

    input:
    path raw_dirs

    output:
    path "dimer_rep123_panels_0-400ns.tif", emit: figure
    path "dimer_rep123_panels_window_stats.csv", emit: table

    script:
    """
    set -euo pipefail
    mkdir -p raw_xvg
    for d in dimer_rep*; do
      [[ -d "\$d" ]] || continue
      cp -a "\$d" "raw_xvg/"
    done

    PYTHONPATH="${absPath(params.analysis_revision_dir)}:\${PYTHONPATH:-}" \
    python "${absPath(params.analysis_revision_dir)}/revision_plot_dimer_timeseries.py" \
      --mode panels \
      --raw-root raw_xvg \
      --t-end-ns 400 \
      --window-ns 50 \
      --out-fig dimer_rep123_panels_0-400ns.tif \
      --out-csv dimer_rep123_panels_window_stats.csv \
      --fig-format tif \
      --dpi "${params.dpi}"
    """
}

process AGGREGATE_MMPBSA {
    tag "mmpbsa_summary"
    publishDir "${params.outdir}/tables", mode: 'copy'

    input:
    path result_files

    output:
    path "mmpbsa_summary.csv", emit: summary

    script:
    """
    set -euo pipefail

    python "${absPath(params.mmpbsa_dir)}/summarize_mmpbsa_gb_last50ns.py" \
      --rep1 mmpbsa_dimer_rep1/last50ns_gb_subsample_FINAL_RESULTS.dat \
      --rep2 mmpbsa_dimer_rep2/last50ns_gb_subsample_FINAL_RESULTS.dat \
      --rep3 mmpbsa_dimer_rep3/last50ns_gb_subsample_FINAL_RESULTS.dat \
      --out-csv mmpbsa_summary.csv
    """
}

process GENERATE_REPORT {
    tag "summary_json"
    publishDir "${params.outdir}", mode: 'copy'

    input:
    path mmpbsa_summary
    path dimer_figure

    output:
    path "summary.json", emit: report

    script:
    """
    set -euo pipefail
    python - <<'PY'
import json
from pathlib import Path

summary = {
    "pipeline": "CPPF-tubulin Phase 1 Nextflow workflow",
    "system": "${params.system}",
    "replicates": ${params.replicates},
    "production_nsteps": ${params.production_nsteps},
    "outputs": {
        "mmpbsa_summary": str(Path("${mmpbsa_summary}")),
        "dimer_figure": str(Path("${dimer_figure}")),
    },
    "notes": [
        "RESP2/cofactor/topology construction is a gate-validated handoff in Phase 1.",
        "Use -resume for Nextflow-level restart.",
    ],
}
Path("summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
PY
    """
}

// ── Workflow entry points ─────────────────────────────────────────────────

workflow PREPARE_TOPOLOGY {
    input_complex_ch = Channel.fromPath(absPath(params.input_complex), checkIfExists: true)
    PREPARE_TOPOLOGY_PROC(input_complex_ch)
}

workflow PREPARE_AND_EQUIL {
    input_complex_ch = Channel.fromPath(absPath(params.input_complex), checkIfExists: true)
    prepared_ch = PREPARE_TOPOLOGY_PROC(input_complex_ch).prepared

    reps_ch = Channel
        .fromList(params.replicates as List)
        .map { rep -> tuple(rep as Integer, seedForRep(rep as Integer)) }

    em_in = reps_ch
        .combine(prepared_ch)
        .map { rep, seed, complex_pdb, prepared_gro, topology, index_file -> tuple(rep, seed, prepared_gro, topology, index_file) }

    em_ch = ENERGY_MINIMIZE(em_in).em
    nvt_in = em_ch.map { rep, seed, em_gro, em_tpr -> tuple(rep, seed, em_gro) }
    nvt_ch = NVT_EQUIL(nvt_in).nvt
    npt_in = nvt_ch.map { rep, seed, nvt_gro, nvt_cpt, nvt_tpr -> tuple(rep, seed, nvt_gro, nvt_cpt) }
    NPT_EQUIL(npt_in)
}

workflow {
    if (!(params.stage in ['prepare_topology', 'prepare_and_equil', 'full'])) {
        throw new IllegalArgumentException("Unknown --stage '${params.stage}'. Use prepare_topology, prepare_and_equil, or full.")
    }

    input_complex_ch = Channel.fromPath(absPath(params.input_complex), checkIfExists: true)
    prepared_ch = PREPARE_TOPOLOGY_PROC(input_complex_ch).prepared

    if (params.stage != 'prepare_topology') {
        reps_ch = Channel
            .fromList(params.replicates as List)
            .map { rep -> tuple(rep as Integer, seedForRep(rep as Integer)) }

        em_in = reps_ch
            .combine(prepared_ch)
            .map { rep, seed, complex_pdb, prepared_gro, topology, index_file -> tuple(rep, seed, prepared_gro, topology, index_file) }

        em_ch = ENERGY_MINIMIZE(em_in).em
        nvt_ch = NVT_EQUIL(em_ch.map { rep, seed, em_gro, em_tpr -> tuple(rep, seed, em_gro) }).nvt
        npt_ch = NPT_EQUIL(nvt_ch.map { rep, seed, nvt_gro, nvt_cpt, nvt_tpr -> tuple(rep, seed, nvt_gro, nvt_cpt) }).npt

        if (params.stage == 'full') {
            prod_ch = PRODUCTION_MD(npt_ch.map { rep, seed, npt_gro, npt_cpt, npt_tpr -> tuple(rep, seed, npt_gro, npt_cpt) }).prod
            clean_ch = PBC_CORRECTION(prod_ch).clean
            xvg_ch = EXPORT_XVG(clean_ch).xvg
            fel_ch = FEL_CALCULATION(xvg_ch).fel
            mmpbsa_ch = MMPBSA(clean_ch).results

            dimer_fig = PLOT_DIMER_TIMESERIES(xvg_ch.map { rep, sid, raw_dir -> raw_dir }.collect()).figure
            mmpbsa_summary = AGGREGATE_MMPBSA(mmpbsa_ch.map { rep, sid, result -> result }.collect()).summary
            GENERATE_REPORT(mmpbsa_summary, dimer_fig)
        }
    }
}
