import pandas as pd
import os

## To bypass permission issues caused by docker on local machine use: sudo chmod -R 777 ./
## If DAG or Rulegraph throwing error workaround is to comment out print statements in SnakeFile

### READ CONFIG ###
configfile: 'config.yml'

df = pd.read_csv('scan_list.csv')
COHORTS = df['cohort']
SUBJECTS = df['subject']
SESSIONS = df['session']
NETWORKS = config['network_info']['networks']
# print('\nSummary of data that is being processed:\n\n', df.iloc[:,1:], '\n')

rule all:
    input:
        # "scans.txt",
        # "scan_list.csv"
        expand("bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),

rule tidy_and_compile:
    output:
        temp("scans.txt")
    shell:
        "python ./scripts/prep_data.py {config[projectdir]} {config[workingdir]} {config[ethics_prefix]} {config[dicom_compression_ext]}; touch {output}"

rule heudiconv:
    input:
        "scans.txt",
        "scan_list.csv"
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
