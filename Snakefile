import pandas as pd
import os

#****************** FIX ISSUE WITH SESSIONS DROPPING LEAD ZEROS ******************
# REMOVE WORK AROUND FOR ABOVE FROM STEPS BEFORE FIRST LEVEL RULE

## To bypass permission issues caused by docker use: sudo chmod -R 777 ./
## If DAG or Rulegraph throwing error workaround is to comment out print statements in SnakeFile

### READ CONFIG ###
configfile: 'config.yml'

### DEFINE DATA TO PREPROCESS ###
# df = pd.read_csv('scan_list.csv')
# df['scan_id'] = df['scan_id'].str.replace(config['ethics_prefix'],'')
# df[['cohort', 'subject','session']] = df['scan_id'].str.split('_', 2, expand=True)
# print('\nSummary of data that is being processed:\n\n', df.iloc[:,1:], '\n')
# df = pd.read_csv('scan_list.csv')
# df['scan_id'] = df['scan_id'].str.replace('Conc_20Ntb14_','')
# df[['cohort', 'subject','session']] = df['scan_id'].str.split('_', 2, expand=True)
# df['session'].fillna("tbd",inplace=True)
# df = df.applymap(lambda s: s.lower() if type(s) == str else s)
# print('\nSummary of data that is being processed:\n\n', df.iloc[:,1:], '\n')
#
# COHORTS = df['cohort']
# SUBJECTS = df['subject']
# SESSIONS = df['session']
# NETWORKS = config['network_info']['networks']
#
# print("\nNetworks that will be processed: ", NETWORKS, '\n')

### DEFINE DATA FOR FIRST LEVEL ANALYSIS ###
# if os.path.isfile('first_level_dataset_clean.csv') == False:
#     print('First level dataset not available yet...')
#     pass
# else:
#     preproc_df = pd.read_csv('first_level_dataset_clean.csv')
#     preproc_df['session'] = preproc_df['scan_id'].str.strip().str[-3:]
#     preproc_df['networks'] = [NETWORKS for _ in range(len(preproc_df))]
#     preproc_df = preproc_df.explode('networks', ignore_index=True)
#     PP_COHORTS = preproc_df['cohort']
#     PP_SUBJECTS = preproc_df['subject']
#     PP_SESSIONS = preproc_df['session']
#     PP_NETWORKS = preproc_df['networks']

df = pd.read_csv('scan_list.csv')
COHORTS = df['cohort']
SUBJECTS = df['subject']
SESSIONS = df['session']
NETWORKS = config['network_info']['networks']
print('\nSummary of data that is being processed:\n\n', df.iloc[:,1:], '\n')

rule all:
    input:
        # "scan_list.csv"
        expand("bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
        # expand("bids/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-001_T1w.json", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
        # expand("bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_bold.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
        # expand("bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_bold.json", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
        # expand("bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_events.tsv", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
        # "first_level_dataset_clean.csv",
        #expand("results/{cohort}{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz", zip, subject = PP_SUBJECTS, session = PP_SESSIONS, cohort = PP_COHORTS, network = PP_NETWORKS)

rule tidy_and_compile:
    output:
        "scan_list.csv"
    shell:
        "bash ./scripts/unzip_and_tidy.sh {config[workingdir]} {config[projectdir]} ; \
        python ./scripts/tidying.py {config[workingdir]} {config[ethics_prefix]} {config[projectdir]}"

rule heudiconv:
    input:
        "scan_list.csv"
    output:
        "bids/sub-{cohort}_{subject}/ses-{session}/anat/sub-{cohort}_{subject}_ses-{session}_run-001_T1w.nii.gz",
        # "bids/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-001_T1w.json",
        # "bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_bold.nii.gz",
        # "bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_bold.json",
        # "bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_events.tsv"
    container:
        "docker://nipy/heudiconv:latest"
    shell: #CAN THIS BE SETUP TO RUN AS BASH WITH SYS ARG?
        # "bash ./scripts/heudiconv_convert.sh {config[workingdir]} {wildcards[cohort]} {wildcards[subject]} {wildcards[session]}"
        " docker run --rm -it -v {config[workingdir]}:/data -v {config[projectdir]}:/base \
            nipy/heudiconv:latest \
            -d /data/dicom/{{subject}}/{{session}}/*/* \
            -o /data/bids \
            -f /base/scripts/heuristic.py \
            -s {wildcards.cohort}_{wildcards.subject} \
            -ss {wildcards.session} \
            -c dcm2niix \
            -b \
            --overwrite"
        # "docker run --rm -it -v {config[workingdir]}:/base \
        #     nipy/heudiconv:latest \
        #     -d /base/{config[dicom_dir_structure]} \
        #     -o /base/bids \
        #     -f {config[projectdir]}/scripts/heuristic.py \
        #     -s {wildcards.cohort}_{wildcards.subject} \
        #     -ss {wildcards.session} \
        #     -c dcm2niix \
        #     -b \
        #     --overwrite"

# rule bids_validator:
#     input:
#         expand("bids/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-001_T1w.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
#         expand("bids/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-001_T1w.json", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
#         expand("bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_bold.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
#         expand("bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_bold.json", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
#         expand("bids/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-001_events.tsv", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS)
#     output:
#         touch('bids/bids_validate.done')
#     shell:
#         "python ./scripts/bids_check.py"
#
# # rule freesurfer:
# #     input:
# #         record = "bids_validate.done",
# #         # record = "workflow_record.csv",
# #         T1w = expand("bids/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-001_T1w.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS)
# #     output:
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/mri/T1.mgz",
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/mri/aseg.mgz",
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/surf/rh.white",
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/surf/lh.white",
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/surf/rh.pial",
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/surf/lh.pial",
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/surf/rh.inflated",
# #         "bids/derivatives/freesurfer/sub-{cohort}{subject}/surf/lh.inflated"
# #     container:
# #         "docker://freesurfer/freesurfer:7.1.1"
# #     shell:
# #         "docker run --rm -ti \
# #           -v {config[workingdir]}:/base:ro \
# #           -v {config[workingdir]}/bids/derivatives:/output \
# #           -e FS_LICENSE=/base/license.txt \
# #           freesurfer/freesurfer:7.1.1 \
# #           recon-all -sd /output/freesurfer \
# #           -i /base/{input.T1w} \
# #           -subjid sub-{wildcards.cohort}{wildcards.subject} \
# #           -all \
# #           -qcache \
# #           -3T"
#
# rule fmriprep:
#     input:
#         "bids/bids_validate.done"
#     output:
#         "bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_desc-confounds_timeseries.tsv",
#         "bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz",
#         "bids/derivatives/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_T1w.nii.gz",
#         "bids/derivatives/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-1_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz"
#     container:
#         "docker://nipreps/fmriprep:21.0.0"
#     shell:
#         "bash ./scripts/fmriprep.sh {config[workingdir]} {wildcards[cohort]} {wildcards[subject]} {config[fs_status]} {config[fs_dir]} {config[nthreads]} {config[mem]}"
#
# rule fmriprep_qc:
#     input:
#         expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_desc-confounds_timeseries.tsv", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
#         expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
#         expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_T1w.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS),
#         expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/anat/sub-{cohort}{subject}_ses-{session}_run-1_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS)
#     output:
#         temp("bids/derivatives/{cohort}{subject}_ses-{session}_qc.checked")
#     shell:
#         "python ./scripts/fmriprep_qc.py; touch {output}"
#
# rule confounds_and_frame_disp:
#     input:
#         expand("bids/derivatives/{cohort}{subject}_ses-{session}_qc.checked", zip, cohort = COHORTS, subject = SUBJECTS, session = SESSIONS),
#         "bids/derivatives/fmriprep_qc.done",
#         # "bids/bids_validate.done",
#         expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_desc-confounds_timeseries.tsv", zip, subject = SUBJECTS, session = SESSIONS, cohort = COHORTS)
#     output:
#         "first_level_dataset_clean.csv"
#     shell:
#         "python ./scripts/extract_confounds_and_frame_disp.py {config[fd_thresh]} {config[confound_info][num_confounds]} {config[confound_info][confounds]}"
#
# rule first_level:
#     input:
#         dataset = "first_level_dataset_clean.csv",
#         mask = expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz", zip, subject = PP_SUBJECTS, session = PP_SESSIONS, cohort = PP_COHORTS),
#         func = expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz", zip, subject = PP_SUBJECTS, session = PP_SESSIONS, cohort = PP_COHORTS),
#         confounds = expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/regressors.txt", zip, subject = PP_SUBJECTS, session = PP_SESSIONS, cohort = PP_COHORTS)
#     output:
#         "results/{cohort}{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz"
#     conda:
#         "envs/mri.yaml"
#     shell:
#         "python ./scripts/first_level_prob_atlas1.py \
#         {config[workingdir]} \
#         {wildcards.cohort} \
#         {wildcards.subject} \
#         {wildcards.session} \
#         {wildcards.network} \
#         {config[rep_time]} \
#         {config[high_pass]} \
#         {config[low_pass]} \
#         {config[fwhm]} \
#         {config[fdr_alpha]} \
#         {config[func_conn_thresh]} \
#         {config[network_info][num_networks]}"

# rule first_level:
#     input:
#         dataset = "first_level_dataset_clean.csv",
#         mask = expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz", zip, subject = PP_SUBJECTS, session = PP_SESSIONS, cohort = PP_COHORTS),
#         func = expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz", zip, subject = PP_SUBJECTS, session = PP_SESSIONS, cohort = PP_COHORTS),
#         confounds = expand("bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/regressors.txt", zip, subject = PP_SUBJECTS, session = PP_SESSIONS, cohort = PP_COHORTS)
#     output:
#         # temp("temp.txt"),
#         # "results/unthresholded_fc.nii.gz",
#         "results/{cohort}{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz"
#     conda:
#         "envs/mri.yaml"
#     shell:
#         # "echo {input}; touch {output}"
#         "python ./scripts/first_level_prob_atlas.py \
#         {wildcards.cohort} \
#         {wildcards.subject} \
#         {wildcards.session} \
#         {wildcards.network} \
#         {input.mask[0]} \
#         {input.func[0]} \
#         {input.confounds[0]} \
#         {config[rep_time]} \
#         {config[high_pass]} \
#         {config[low_pass]} \
#         {config[fwhm]} \
#         {config[fdr_alpha]} \
#         {config[func_conn_thresh]} \
#         {config[network_info][num_networks]}"
