import pandas as pd
from pathlib import Path

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
        "--bids "
        "--overwrite"

rule mriqc:
    input:
        "{resultsdir}/bids/sub-{subject}/ses-{session}"
    output:
        # TODO list all files generated
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
        "-w {wildcards.resultsdir}/work && "
        "flock {wildcards.resultsdir}/.qc_status.csv.lock "
        "python workflow/scripts/update_qc_list.py {wildcards.resultsdir}/qc_status.csv "
        " {wildcards.subject} {wildcards.session}"