import pandas as pd
import os

## To bypass permission issues caused by docker on local machine use: sudo chmod -R 777 ./
## If DAG or Rulegraph throwing error workaround is to comment out print statements in SnakeFile

### READ CONFIG ###
configfile: 'config.yml'

NETWORKS = config['network_info']['networks']

def available_scans(wildcards):
    try:
        files = pd.read_csv('scan_list.csv')
    except FileNotFoundError:
        return []

    df = files.loc[files['bids_formatted'] == False]
    print(df)
    cohorts = df['cohort']
    subjects = df['subject']
    sessions = df['session']

    res =  expand("bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz", zip, subject = subjects, session = sessions, cohort = cohorts)
    print(res)
    return res

rule all:
    input:
        available_scans,
        "scan_list.csv"

checkpoint tidy_and_compile:
    output:
        "scan_list.csv"
    shell:
        "python ./scripts/prep_data.py {config[projectdir]} {config[workingdir]} {config[ethics_prefix]} {config[dicom_compression_ext]}; touch {output}"

rule heudiconv:
    output:
        "bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz",
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
