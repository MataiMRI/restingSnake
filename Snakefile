import shutil
from pathlib import Path

## If DAG or Rulegraph throwing error workaround is to comment out print statements in SnakeFile

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

def list_tidy_scans(root_folder):
    infos = []
    for path in Path(root_folder).glob("tidy/sub_*/ses_*"):
        _, session = path.name.split("_")
        _, subject = path.parent.name.split("_")
        infos.append([subject, session])
    return infos

MAPPING = list_scans(config["datadir"], config["ethics_prefix"])
TIDY_SCANS = list_tidy_scans(config["resultsdir"])
SUBJECTS, SESSIONS = zip(*list(MAPPING.keys()) + TIDY_SCANS)

localrules: all, fmriprep_cleanup

rule all:
    input:
        expand("{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz",
            resultsdir=config["resultsdir"],
            subject=SUBJECTS,
            session=SESSIONS,
            network=config["atlas_info"]["networks"]),
            
        expand("{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_figure.png",
            resultsdir=config["resultsdir"],
            subject=SUBJECTS,
            session=SESSIONS,
            network=config["atlas_info"]["networks"]
            )

ruleorder: fmriprep > freesurfer > freesurfer_aggregate > unzip

rule unzip:
    input:
        "{folder}.zip"
    output:
        directory("{folder}")
    shell:
        "unzip -q -d {output} {input} && rm {input}"

rule tidy_dicoms:
    input:
        lambda wildards: MAPPING[(wildards.subject, wildards.session)]
    output:
        "{resultsdir}/tidy/sub_{subject}/ses_{session}/.completed"
    run:
        output_folder = Path(output[0]).parent
        for dicom_file in Path(input[0]).rglob("*.dcm"):
            target_path = output_folder / dicom_file.parent.name
            target_path.mkdir(parents=True, exist_ok=True)
            shutil.move(dicom_file, target_path)
        shutil.rmtree(input[0])
        Path(output[0]).touch()

rule heudiconv:
    input:
        "{resultsdir}/tidy/sub_{subject}/ses_{session}/.completed"
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

# RUN BIDS/FREESURFER
# inspect image using singularity exec docker://bids/freesurfer recon-all --help

# TODO remove fs license from repo
# Snakemake locks after freesurfer execution?

rule freesurfer:
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

# TODO decide how to properly aggregate multi-session data
rule freesurfer_aggregate:
    input:
        list_freesurfer_sessions
    output:
        directory("{resultsdir}/bids/derivatives/freesurfer_agg/sub-{subject}")
    container:
        "docker://bids/freesurfer:v6.0.1-6.1"
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["freesurfer"]["mem_mb"],
        time_min=config["freesurfer"]["time_min"]
    threads: config["freesurfer"]["threads"]
    shell:
        "cp -r {input[0]} {output}"

def list_bids_sessions(wildcards):
    inputs = []
    for subject, session in zip(SUBJECTS, SESSIONS):
        if subject != wildcards.subject:
            continue
        inputs.append(f"{wildcards.resultsdir}/bids/sub-{subject}/ses-{session}")
    return inputs

# TODO make sure fmriprep has functionality to handle multiple runs within the same session
# TODO add flexibility for both resting-state and task
# TODO Experiment with --longitudinal in fMRIPREP

rule fmriprep:
    input:
        list_bids_sessions,
        "{resultsdir}/bids/derivatives/freesurfer_agg/sub-{subject}"
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
        "--fs-subjects-dir {wildcards.resultsdir}/bids/derivatives/freesurfer_agg "
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

rule first_level:
    input:
        "{resultsdir}/bids/derivatives/fmriprep/sub-{subject}"
    output:
        "{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz",
        "{resultsdir}/first_level_results/sub-{subject}/ses-{session}/sub-{subject}_ses-{session}_{network}_figure.png"
    conda:
        "envs/mri.yaml"
    resources:
        mem_mb=6000,
        cpus=2,
        time_min=10        
    shell:
        "python ./scripts/first_level.py "
        "{input}/ses-{wildcards.session}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-001_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz "
        "{input}/ses-{wildcards.session}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-001_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz "
        "{input}/ses-{wildcards.session}/func/sub-{wildcards.subject}_ses-{wildcards.session}_task-rest_run-001_desc-confounds_timeseries.tsv "
        "{output} "
        "-a_img {config[atlas_info][atlas_image]} "
        "-a_lab {config[atlas_info][atlas_labels]} "
        "-tr {config[rep_time]} "
        "-rg {config[confounds]} "
        "-ntwk {wildcards.network} "
        "-hp {config[preprocessing][high_pass]} "
        "-lp {config[preprocessing][low_pass]} "
        "-fwhm {config[preprocessing][smooth_fwhm]} "
        "-fdr {config[resting_first_level][fdr_alpha]} "
        "-fc {config[resting_first_level][func_conn_thresh]} "
        "-v"
        
