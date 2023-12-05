import pandas as pd
from pathlib import Path
import os

def correct_typos(root_folder, corrections):
    for path in Path(root_folder).iterdir():
        if path.is_file() or path.is_dir():
            for typo, correction in corrections.items():
                if typo in path.name:
                    print("TYPO FOUND - CORRECTING BASED ON CONFIG -", path.name)
                    corrected_name = path.name.replace(typo, correction)
                    corrected_path = path.with_name(corrected_name)
                    os.rename(path, corrected_path)
    

def list_scans(root_folder, prefix):
    mapping = {}

    for path in Path(root_folder).iterdir():
        if not path.is_dir() and not path.suffix == ".zip":
            continue
        
        parts = path.stem.split("_")
        desired_index = prefix
        if 0 <= desired_index < len(parts):
            desired_string = "_".join(parts[desired_index:])
        infos = [s.lower() for s in desired_string.split("_")]
        
#        infos = [s.lower() for s in path.stem.replace(prefix, "").split("_")]
        if len(infos) == 2:
            infos += ["a"]
        cohort, subject, session = infos

        if path.is_dir():
            mapping[(cohort + subject, session)] = path
        else:
            mapping[(cohort + subject, session)] = path.with_suffix("")

    return mapping

correct_typos(config["datadir"], config.get('corrections', {}))
MAPPING = list_scans(config["datadir"], config["prefix"])

SUBJECTS, SESSIONS = zip(*MAPPING)

rule all:
    localrule: True
    input:
        expand(
            expand(
                "{{resultsdir}}/bids/derivatives/mriqc/sub-{subject}/ses-{session}",
                zip,
                subject=SUBJECTS,
                session=SESSIONS,
            ),
            resultsdir=config["resultsdir"],
        )

rule unzip:
    input:
        expand("{datadir}/{{folder}}.zip", datadir=config['datadir'])
    output:
        directory(expand("{datadir}/{{folder}}", datadir=config['datadir']))
    resources:
        runtime=30
    shell:
        "unzip -q -d {output} {input}"

rule tidy_dicoms:
    input:
        lambda wildards: MAPPING[(wildards.subject, wildards.session)]
    output:
        directory("{resultsdir}/tidy/sub_{subject}/ses_{session}")
    resources:
        runtime=20
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
        "docker://ghcr.io/mataimri/heudiconv:jpeg2000_ci"
    threads: config["heudiconv"]["threads"]
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["heudiconv"]["mem_mb"],
        runtime=config["heudiconv"]["time_min"]
    shell:
        "heudiconv "
        "--dicom_dir_template '{wildcards.resultsdir}/tidy/sub_{{subject}}/ses_{{session}}/*/*' "
        "--outdir {wildcards.resultsdir}/bids "
        "--heuristic {config[heudiconv][heuristic]} "
        "--subjects {wildcards.subject} "
        "--ses {wildcards.session} "
        "--converter dcm2niix "
        "--bids notop "
        "--overwrite"

rule bids_template:
    input:
        expand(
            "{{resultsdir}}/bids/sub-{subject}/ses-{session}",
            zip,
            subject=SUBJECTS,
            session=SESSIONS,
        )
    output:
        "{resultsdir}/bids/dataset_description.json"
    container:
        "docker://ghcr.io/mataimri/heudiconv:jpeg2000_ci"
    shell:
        "heudiconv "
        "--files {wildcards.resultsdir}/bids "
        "--heuristic {config[heudiconv][heuristic]} "
        "--command populate-templates"

rule mriqc:
    input:
        "{resultsdir}/bids/dataset_description.json",
        "{resultsdir}/bids/sub-{subject}/ses-{session}"
    output:
        directory("{resultsdir}/bids/derivatives/mriqc/sub-{subject}/ses-{session}")
    container:
        "docker://nipreps/mriqc:23.0.1"
    resources:
        cpus=lambda wildcards, threads: threads,
        mem_mb=config["mriqc"]["mem_mb"],
        runtime=config["mriqc"]["time_min"]
    params:
        mem_gb=int(config["mriqc"]["mem_mb"] / 1000)
    threads: config["mriqc"]["threads"]
    shell:
        "mriqc {wildcards.resultsdir}/bids {wildcards.resultsdir}/bids/derivatives/mriqc "
        "participant "
        "--participant-label {wildcards.subject} "
        "--session-id {wildcards.session} "
        "--mem-gb {params.mem_gb} "
        "--nprocs {threads} "
        "--no-sub "
        "-vv "
        "-w {wildcards.resultsdir}/work && "
        "flock {wildcards.resultsdir}/.qc_status.csv.lock "
        "python workflow/scripts/update_qc_list.py {wildcards.resultsdir}/qc_status.csv "
        " {wildcards.subject} {wildcards.session}"
