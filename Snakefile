import shutil
from pathlib import Path

## To bypass permission issues caused by docker on local machine use: sudo chmod -R 777 ./
## If DAG or Rulegraph throwing error workaround is to comment out print statements in SnakeFile

### READ CONFIG ###
configfile: 'config.yml'

NETWORKS = config['network_info']['networks']

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
            mapping[(cohort, subject, session)] = path
        else:
            mapping[(cohort, subject, session)] = path.with_suffix("")

    return mapping

def list_tidy_scans(root_folder):
    infos = []
    for path in Path(root_folder).glob("tidy/sub_*/ses_*"):
        _, session = path.name.split("_")
        _, cohort, subject = path.parent.name.split("_")
        infos.append([cohort, subject, session])
    return infos

MAPPING = list_scans(config["datadir"], config["ethics_prefix"])
TIDY_SCANS = list_tidy_scans(config["resultsdir"])
COHORTS, SUBJECTS, SESSIONS = zip(*list(MAPPING.keys()) + TIDY_SCANS)

rule all:
    input:
        expand(
            "{resultsdir}/bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz",
            zip,
            resultsdir=[config["resultsdir"]] * len(SUBJECTS),
            subject=SUBJECTS,
            session=SESSIONS,
            cohort=COHORTS
        )

rule unzip:
    input:
        "{folder}.zip"
    output:
        directory("{folder}")
    shell:
        "unzip -q -d {output} {input} && rm {input}"

rule tidy_dicoms:
    input:
        lambda wildards: MAPPING[(wildards.cohort, wildards.subject, wildards.session)]
    output:
        "{resultsdir}/tidy/sub_{cohort}_{subject}/ses_{session}/.completed"
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
        "{resultsdir}/tidy/sub_{cohort}_{subject}/ses_{session}/.completed"
    output:
        "{resultsdir}/bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz"
    container:
        "docker://nipy/heudiconv:v0.11.3"
    resources:
        cpus=6,
        mem_mb=4000,
        time_min=120
    shell:
        "heudiconv "
        "--dicom_dir_template '{wildcards.resultsdir}/tidy/sub_{{subject}}/ses_{{session}}/*/*' "
        "--outdir {wildcards.resultsdir}/bids "
        "--heuristic scripts/heuristic.py "
        "--subjects {wildcards.cohort}_{wildcards.subject} "
        "--ses {wildcards.session} "
        "--converter dcm2niix "
        "--bids "
        "--overwrite"
