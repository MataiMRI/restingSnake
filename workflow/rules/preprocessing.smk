from pathlib import Path
import pandas as pd

def pass_qc(qc_df):
    valid_anat = qc_df['anat_qc'] | (qc_df['session'] != qc_df['anat_template'])
    qc_true = qc_df.loc[valid_anat & qc_df['func_qc']]
    return qc_true["subject"].to_list(), qc_true["session"].to_list()

try:
    QC_DF = pd.read_csv(Path(config["resultsdir"]) / "qc_status.csv")
    SUBJECTS, SESSIONS = pass_qc(QC_DF)
except FileNotFoundError:
    SUBJECTS = []
    SESSIONS = []

NETWORKS = [
    network.replace(' ', '-')
    for network in config["first_level"]["atlas_info"]["networks"]
]

rule all:
    localrule: True
    input:
        expand(
            expand(
                "{{resultsdir}}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{{network}}_{{figname}}",
                zip,
                subject=SUBJECTS,
                session=SESSIONS,
            ),
            resultsdir=config["resultsdir"],
            network=NETWORKS,
            figname=["unthresholded_fc.nii.gz", "figure.png"],
        ),
        expand("{resultsdir}/.work_completed", resultsdir=config["resultsdir"])

ruleorder: freesurfer_longitudinal > freesurfer_long_template > freesurfer_cross_sectional

rule freesurfer_cross_sectional:
    input:
        "{resultsdir}/bids/sub-{subject}/ses-{session}"
    output:
        directory("{resultsdir}/bids/derivatives/freesurfer/sub-{subject}_ses-{session}")
    container:
        "docker://nipreps/fmriprep:21.0.4"
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["freesurfer"]["mem_mb"],
        runtime=config["freesurfer"]["time_min"]
    threads: config["freesurfer"]["threads"]
    shell:
        "export FS_LICENSE=$(realpath {config[freesurfer][license_path]}) && "
        "recon-all "
        "-sd {wildcards.resultsdir}/bids/derivatives/freesurfer "
        "-i {input}/anat/sub-{wildcards.subject}_ses-{wildcards.session}_run-001_T1w.nii.gz "
        "-subjid sub-{wildcards.subject}_ses-{wildcards.session} "
        "-all "
        "-qcache "
        "-3T "
        "-openmp {threads}"

def list_freesurfer_sessions(wildcards):
    inputs = []
    for subject, session in zip(SUBJECTS, SESSIONS):
        if subject != wildcards.subject:
            continue
        inputs.append(f"{wildcards.resultsdir}/bids/derivatives/freesurfer/sub-{subject}_ses-{session}")
    return inputs

def sessions_for_template(wildcards):
    inputs = []
    for subject, session in zip(SUBJECTS, SESSIONS):
        if subject != wildcards.subject:
            continue
        inputs.append(f"sub-{subject}_ses-{session}")
    inputs = sorted(inputs)
    tps = " ".join(f"-tp {session}" for session in inputs)
    return tps

# TODO decide how to properly aggregate multi-session data
rule freesurfer_long_template:
    input:
        list_freesurfer_sessions
    output:
        directory("{resultsdir}/bids/derivatives/freesurfer/{subject}_template")
    container:
        "docker://nipreps/fmriprep:21.0.4"
    params:
        license_path=config["freesurfer"]["license_path"],
        timepoints=sessions_for_template
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["freesurfer"]["mem_mb"],
        runtime=config["freesurfer"]["time_min"]
    threads: config["freesurfer"]["threads"]
    shell:
        "export FS_LICENSE=$(realpath {params.license_path}) && "
        "recon-all "
        "-base {wildcards.subject}_template "
        "{params.timepoints} "
        "-sd {wildcards.resultsdir}/bids/derivatives/freesurfer "
        "-all "
        "-3T "
        "-openmp {threads}"

rule freesurfer_longitudinal:
    input:
        "{resultsdir}/bids/sub-{subject}/ses-{session}",
        "{resultsdir}/bids/derivatives/freesurfer/{subject}_template"
    output:
        directory("{resultsdir}/bids/derivatives/freesurfer/sub-{subject}_ses-{session}.long.{subject}_template")
    container:
        "docker://nipreps/fmriprep:21.0.4"
    params:
        license_path=config["freesurfer"]["license_path"],
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["freesurfer"]["mem_mb"],
        runtime=config["freesurfer"]["time_min"]
    threads: config["freesurfer"]["threads"]
    shell:
        "export FS_LICENSE=$(realpath {params.license_path}) && "
        "recon-all "
        "-long sub-{wildcards.subject}_ses-{wildcards.session} "
        "{wildcards.subject}_template "
        "-sd {wildcards.resultsdir}/bids/derivatives/freesurfer "
        "-all "
        "-qcache "
        "-3T "
        "-openmp {threads}"

def freesurfer_rename_input(wildcards):
    if config["use_longitudinal"]:
        suffix = ".long.{subject}_template"
    else:
        suffix = ""
    index = (wildcards.subject, wildcards.session)
    session = QC_DF.set_index(["subject", "session"]).loc[index, "anat_template"]
    return f"{{resultsdir}}/bids/derivatives/freesurfer/sub-{{subject}}_ses-{session}{suffix}"

rule freesurfer_rename:
    localrule: True
    input:
        freesurfer_rename_input
    output:
        temp(directory("{resultsdir}/bids/derivatives/freesurfer_sub-{subject}_ses-{session}"))
    shell:
        "mkdir -p {output} && ln -s {input} {output}/sub-{wildcards.subject}"

rule fmriprep_filter:
    localrule: True
    input:
        workflow.source_path("../templates/bids_filter.json")
    output:
        temp("{resultsdir}/bids/derivatives/fmriprep/bids_filter_sub-{subject}_ses-{session}.json")
    template_engine:
        "jinja2"

# TODO make sure fmriprep has functionality to handle multiple runs within the same session
# TODO add flexibility for both resting-state and task
# TODO Experiment with --longitudinal in fMRIPREP

def previous_session(wildcards):
    """find the previous fmriprep session folder for a given session"""

    last_session = None

    for subject, session in zip(SUBJECTS, SESSIONS):
        if subject != wildcards.subject:
            continue
        if session != wildcards.session:
            last_session = session
        else:
            break

    if last_session is None:
        dependency = {}
    else:
        dependency = {
            "previous": f"{{resultsdir}}/bids/derivatives/fmriprep/sub-{{subject}}/ses-{last_session}"
        }

    return dependency

rule fmriprep:
    input:
        unpack(previous_session),
        bids="{resultsdir}/bids/sub-{subject}/ses-{session}",
        bids_filter="{resultsdir}/bids/derivatives/fmriprep/bids_filter_sub-{subject}_ses-{session}.json",
        freesurfer="{resultsdir}/bids/derivatives/freesurfer_sub-{subject}_ses-{session}"
    output:
        # TODO list all files generated
        directory("{resultsdir}/bids/derivatives/fmriprep/sub-{subject}/ses-{session}"),
        #"{resultsdir}/bids/derivatives/fmriprep/sub-{subject}.html"
    container:
        "docker://nipreps/fmriprep:21.0.4"
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["fmriprep"]["mem_mb"],
        runtime=config["fmriprep"]["time_min"]
    threads: config["fmriprep"]["threads"]
    shell:
        "fmriprep {wildcards.resultsdir}/bids {wildcards.resultsdir}/bids/derivatives/fmriprep "
        "participant "
        "--participant-label {wildcards.subject} "
        "--skip-bids-validation "
        "--md-only-boilerplate "
        "--fs-subjects-dir {input.freesurfer} "
        "--output-spaces MNI152NLin2009cAsym:res-2 "
        "--stop-on-first-crash "
        "--low-mem "
        "--mem-mb {resources.mem_mb} "
        "--nprocs {threads} "
        "-w {wildcards.resultsdir}/work "
        "--fs-license-file {config[freesurfer][license_path]} "
        "--bids-filter-file {input.bids_filter}"

rule fmriprep_cleanup:
    localrule: True
    input:
        expand(
            "{{resultsdir}}/bids/derivatives/fmriprep/sub-{subject}/ses-{session}",
            zip,
            subject=SUBJECTS,
            session=SESSIONS
        ),
    output:
        touch("{resultsdir}/.work_completed")
    shell:
        "rm -rf {wildcards.resultsdir}/work"

#Query with Mangor:
### handling multiple runs within a session???
#whether mask should be from anat or func folder?

def atlas_image(wildcards):
    a_img = config["first_level"]["atlas_info"].get("atlas_image")
    if (a_img is not None) and (len(a_img.strip()) > 0):
        return f"-a_img {a_img}"
    else:
        return ""

def atlas_labels(wildcards):
    a_lab = config["first_level"]["atlas_info"].get("atlas_labels")
    if (a_lab is not None) and (len(a_lab.strip()) > 0):
        return f"-a_lab {a_lab}"
    else:
        return ""

rule first_level:
    input:
        "{resultsdir}/bids/derivatives/fmriprep/sub-{subject}/ses-{session}"
    output:
        "{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz",
        "{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_figure.png"
    conda:
        "../envs/mri.yaml"
    params:
        a_img=atlas_image,
        a_lab=atlas_labels
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["first_level"]["mem_mb"],
        runtime=config["first_level"]["time_min"]
    threads: config["first_level"]["threads"]
    log:
        "{resultsdir}/first_level_results/sub-{subject}_ses-{session}_{network}.log"
    shell:
        "python workflow/scripts/first_level.py "
        "{input}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz "
        "{input}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz "
        "{input}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-1_desc-confounds_timeseries.tsv "
        "{output} "
        "{params.a_img} "
        "{params.a_lab} "
        "-tr {config[first_level][rep_time]} "
        "-rg {config[first_level][confounds]} "
        "-ntwk {wildcards.network} "
        "-hp {config[first_level][preprocessing][high_pass]} "
        "-lp {config[first_level][preprocessing][low_pass]} "
        "-fwhm {config[first_level][preprocessing][smooth_fwhm]} "
        "-fdr {config[first_level][resting_first_level][fdr_alpha]} "
        "-fc {config[first_level][resting_first_level][func_conn_thresh]} "
        "-v "
        "2> {log}"