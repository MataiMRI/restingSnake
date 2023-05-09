import shutil
from pathlib import Path

### READ CONFIG ###
configfile: 'config.yml'

NETWORKS = config['atlas_info']['networks']

def list_scans(root_folder, prefix):
    mapping = {}

    for path in Path(root_folder).iterdir():
        if not path.is_dir() and not path.suffix == ".zip":
            continue

        infos = [s.lower() for s in path.stem.replace(prefix, "").split("_")]
        if len(infos) == 2:
            infos += ["a"]
        cohort, subject, session = infos

        if path.is_dir():
            mapping[(cohort + subject, session)] = path
        else:
            mapping[(cohort + subject, session)] = path.with_suffix("")

    return mapping

MAPPING = list_scans(config["datadir"], config["ethics_prefix"])
SUBJECTS, SESSIONS = zip(*MAPPING)

localrules: all, fmriprep_cleanup

rule all:
    input:
        expand(
            expand(
                "{{resultsdir}}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{{network}}_{{figname}}",
                zip,
                subject=SUBJECTS,
                session=SESSIONS,
            ),
            resultsdir=config["resultsdir"],
            network=config["atlas_info"]["networks"],
            figname=["unthresholded_fc.nii.gz", "figure.png"],
        )

ruleorder: freesurfer_longitudinal > freesurfer_long_template > freesurfer_cross_sectional

rule unzip:
    input:
        expand("{datadir}/{{folder}}.zip", datadir=config['datadir'])
    output:
        directory(expand("{datadir}/{{folder}}", datadir=config['datadir']))
    shell:
        "unzip -q -d {output} {input}"

rule tidy_dicoms:
    input:
        lambda wildards: MAPPING[(wildards.subject, wildards.session)]
    output:
        directory("{resultsdir}/tidy/sub_{subject}/ses_{session}")
    run:
        output_folder = Path(output[0])
        for dicom_file in Path(input[0]).rglob("*.dcm"):
            target_folder = output_folder / dicom_file.parent.name
            target_folder.mkdir(parents=True, exist_ok=True)
            (target_folder / dicom_file.name).symlink_to(dicom_file)

rule heudiconv:
    input:
        "{resultsdir}/tidy/sub_{subject}/ses_{session}"
    output:
        directory("{resultsdir}/bids/sub-{subject}/ses-{session}"),
        directory("{resultsdir}/bids/.heudiconv/{subject}/ses-{session}")
    container:
        "docker://ghcr.io/jennan/heudiconv:jpeg2000_ci"
    resources:
        cpus=2,
        mem_mb=4000,
        time_min=60
    shell:
        "heudiconv "
        "--dicom_dir_template '{wildcards.resultsdir}/tidy/sub_{{subject}}/ses_{{session}}/*/*' "
        "--outdir {wildcards.resultsdir}/bids "
        "--heuristic scripts/heuristic.py "
        "--subjects {wildcards.subject} "
        "--ses {wildcards.session} "
        "--converter dcm2niix "
        "--bids "
        "--overwrite"

rule freesurfer_cross_sectional:
    input:
        "{resultsdir}/bids/sub-{subject}/ses-{session}"
    output:
        directory("{resultsdir}/bids/derivatives/freesurfer/sub-{subject}_ses-{session}")
    container:
        "docker://bids/freesurfer:v6.0.1-6.1"
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["freesurfer"]["mem_mb"],
        time_min=config["freesurfer"]["time_min"]
    threads: 8
    shell:
        "export FS_LICENSE=$(realpath {config[freesurfer][license_path]}) && "
        "recon-all "
        "-sd {wildcards.resultsdir}/bids/derivatives/freesurfer "
        "-i {input}/anat/sub-{wildcards.subject}_ses-{wildcards.session}_run-001_T1w.nii.gz "
        "-subjid sub-{wildcards.subject}_ses-{wildcards.session} "
        "-all "
        "-qcache "
        "-3T "
        "-openmp {threads} "

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
        "docker://bids/freesurfer:v6.0.1-6.1"
    params:
        license_path=config["freesurfer"]["license_path"],
        timepoints=sessions_for_template
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["freesurfer"]["mem_mb"],
        time_min=config["freesurfer"]["time_min"]
    threads: 8
    shell:
        "export FS_LICENSE=$(realpath {params.license_path}) && "
        "recon-all "
        "-base {wildcards.subject}_template "
        "{params.timepoints} "
        "-sd {wildcards.resultsdir}/bids/derivatives/freesurfer "
        "-all "
        "-3T "
        "-openmp {threads} "

rule freesurfer_longitudinal:
    input:
        "{resultsdir}/bids/sub-{subject}/ses-{session}",
        "{resultsdir}/bids/derivatives/freesurfer/{subject}_template"
    output:
        directory("{resultsdir}/bids/derivatives/freesurfer/sub-{subject}_ses-{session}.long.{subject}_template")
    container:
        "docker://bids/freesurfer:v6.0.1-6.1"
    params:
        license_path=config["freesurfer"]["license_path"],
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["freesurfer"]["mem_mb"],
        time_min=config["freesurfer"]["time_min"]
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
        "-openmp {threads} " 

def list_bids_sessions(wildcards):
    inputs = []
    for subject, session in zip(SUBJECTS, SESSIONS):
        if subject != wildcards.subject:
            continue
        inputs.append(f"{wildcards.resultsdir}/bids/sub-{subject}/ses-{session}")
    return inputs

def list_long_sessions(wildcards):
    inputs = []
    freesurferdir = f"{wildcards.resultsdir}/bids/derivatives/freesurfer"
    for subject, session in zip(SUBJECTS, SESSIONS):
        if subject != wildcards.subject:
            continue
        if config["use_longitudinal"]:
            input_path = f"{freesurferdir}/sub-{subject}_ses-{session}.long.{subject}_template"
        else:
            input_path = f"{freesurferdir}/sub-{subject}_ses-{session}"
        inputs.append(input_path)
    return inputs

# TODO make sure fmriprep has functionality to handle multiple runs within the same session
# TODO add flexibility for both resting-state and task
# TODO Experiment with --longitudinal in fMRIPREP

rule fmriprep:
    input:
        list_bids_sessions,
        list_long_sessions
    output:
        directory("{resultsdir}/bids/derivatives/fmriprep/sub-{subject}"),
        "{resultsdir}/bids/derivatives/fmriprep/sub-{subject}.html"
    container:
        "docker://nipreps/fmriprep:22.0.2"
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["fmriprep"]["mem_mb"],
        time_min=config["fmriprep"]["time_min"]
    threads: config["fmriprep"]["threads"]
    shell:
        "fmriprep {wildcards.resultsdir}/bids {wildcards.resultsdir}/bids/derivatives/fmriprep "
        "participant "
        "--participant-label {wildcards.subject} "
        "--skip-bids-validation "
        "--md-only-boilerplate "
        "--fs-subjects-dir {wildcards.resultsdir}/bids/derivatives/freesurfer "
        "--output-spaces MNI152NLin2009cAsym:res-2 "
        "--stop-on-first-crash "
        "--low-mem "
        "--mem-mb {resources.mem_mb} "
        "--nprocs {threads} "
        "-w {wildcards.resultsdir}/work "
        "--fs-license-file {config[freesurfer][license_path]}"

rule fmriprep_cleanup:
    input:
        expand(
            "{resultsdir}/bids/derivatives/fmriprep/sub-{subject}",
            resultsdir=config["resultsdir"],
            subject=SUBJECTS,
        )
    output:
        touch(expand("{resultsdir}/.work.completed", resultsdir=config["resultsdir"]))
    shell:
        "rm -rf {config[resultsdir]}/work"

#Query with Mangor:
### handling multiple runs within a session???
#whether mask should be from anat or func folder?

### MAKE SURE CONFOUND REGRESSION IS DONE ON SHORTLIST FROM CONFIG file

def atlas_image(wildcards):
    a_img = config["atlas_info"].get("atlas_image")
    if (a_img is not None) and (len(a_img.strip()) > 0):
        return f"-a_img {a_img}"
    else:
        return ""
        
def atlas_labels(wildcards):
    a_lab = config["atlas_info"].get("atlas_labels")
    if (a_lab is not None) and (len(a_lab.strip()) > 0):
        return f"-a_lab {a_lab}"
    else:
        return ""

rule first_level:
    input:
        "{resultsdir}/bids/derivatives/fmriprep/sub-{subject}"
    output:
        "{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz",
        "{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_figure.png"
    conda:
        "envs/mri.yaml"
    params:
        a_img=atlas_image,
        a_lab=atlas_labels
    resources:
        mem_mb=6000,
        cpus=2,
        time_min=10
    log:
        "{resultsdir}/first_level_results/sub-{subject}_ses-{session}_{network}.log"
    shell:
        "python ./scripts/first_level.py "
        "{input}/ses-{wildcards.session}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-001_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz "
        "{input}/ses-{wildcards.session}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-001_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz "
        "{input}/ses-{wildcards.session}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-001_desc-confounds_timeseries.tsv "
        "{output} "
        "{params.a_img} "
        "{params.a_lab} "
        "-tr {config[rep_time]} "
        "-rg {config[confounds]} "
        "-ntwk {wildcards.network} "
        "-hp {config[preprocessing][high_pass]} "
        "-lp {config[preprocessing][low_pass]} "
        "-fwhm {config[preprocessing][smooth_fwhm]} "
        "-fdr {config[resting_first_level][fdr_alpha]} "
        "-fc {config[resting_first_level][func_conn_thresh]} "
        "-v "
        "2> {log}"
