from pathlib import Path

## To bypass permission issues caused by docker on local machine use: sudo chmod -R 777 ./
## If DAG or Rulegraph throwing error workaround is to comment out print statements in SnakeFile

### READ CONFIG ###
configfile: 'config.yml'

NETWORKS = config['network_info']['networks']

def scan_infos(path, prefix):
    infos = [s.lower() for s in Path(path).stem.replace(prefix, "").split("_")]
    if len(infos) == 2:
        infos += ["a"]
    assert len(infos) == 3
    return tuple(infos)

def list_scans(root_folder, prefix):
    root_folder = Path(root_folder)
    zip_files = list(root_folder.glob("*.zip"))
    folders = [path for path in root_folder.iterdir() if path.is_dir()]
    candidates = zip_files + folders
    infos = [scan_infos(path, prefix) for path in candidates]
    subjects, sessions, cohorts = zip(*infos)
    mapping = {key: path for key, path in zip(infos, candidates)}
    return subjects, sessions, cohorts, mapping

SUBJECTS, SESSIONS, COHORTS, MAPPING = list_scans(config["datadir"], config["ethics_prefix"])

rule all:
    input:
        expand(
            "{results}/bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz",
            zip,
            results=config["resultsdir"],
            subject=SUBJECTS,
            session=SESSIONS,
            cohort=COHORTS
        )

#rule tidy_dicoms:
#    input:
#        TODO
#    output:
#        "{results}/sub_{subject}/ses_{session}"
#    shell:
#        TODO

rule heudiconv:
    output:
        "bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz"
    container:
        "docker://nipy/heudiconv:latest"
    shell:
        " echo Creating {output}; touch {output}"
        # " docker run --rm -it -v {config[workingdir]}:/data -v {config[projectdir]}:/base \
        #     nipy/heudiconv:latest \
        #     -d /data/dicom/sub_{{subject}}/ses_{{session}}/*/* \
        #     -o /data/bids \
        #     -f /base/scripts/heuristic.py \
        #     -s {wildcards.cohort}_{wildcards.subject} \
        #     -ss {wildcards.session} \
        #     -c dcm2niix \
        #     -b \
        #     --overwrite"
