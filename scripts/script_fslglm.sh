#!/bin/bash

# script_runfslglm.sh
# date created: 24-08-2021
# This script automatically runs fsl glm for all subjects


fmriprepdir=/home/jpmcgeown/fmri_wf
echo $fmriprepdir
subject=sub-02
# subjectlist=$(cat $fmriprepdir/subject_list.txt)
# echo $subjectlist

GREEN='\033[1;32m' #ANSI escape codes
NC='\033[0m'

echo -e "${GREEN}Performing fsl_glm on ${subject} session 1: ${NC}"
fsl_glm -i ${fmriprepdir}/bids/derivatives/${subject}/ses-001/func/${subject}_ses-001_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz -d ${fmriprepdir}/bids/derivatives/${subject}/ses-001/func/regressors.txt --out_res=${fmriprepdir}/bids/derivatives/${subject}/ses-001/func/rest_func_data_regressors.nii.gz

# for subject in $subjectlist;
#   do
#     echo -e "${GREEN}Performing fsl_glm on ${subject} session 1: ${NC}"
#     fsl_glm -i ${fmriprepdir}/derivatives/${subject}/ses-001/func/${subject}_ses-001_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz -d ${fmriprepdir}/derivatives/${subject}/ses-001/func/regressors.txt --out_res=${fmriprepdir}/derivatives/${subject}/ses-001/func/rest_func_data_regressors.nii.gz
# done
