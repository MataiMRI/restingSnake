#!/bin/bash

# script_runsmoothing.sh
# date created: 24-08-2021
# This script automatically runs fsl maths filtering (high and low pass) for all subjects

# Note: `fslmaths` uses sigma filtering. Convert mm values into sigma values. E.g.:
#8 mm / 2.354 = sigma 3.40
#6 mm / 2.354 = sigma 2.55

fmriprepdir=/home/jpmcgeown/Desktop/fmri_dev
echo $fmriprepdir
subjectlist=$(cat $fmriprepdir/subject_list.txt ) 
echo $subjectlist

GREEN='\033[1;32m' #ANSI escape codes
NC='\033[0m'


for subject in $subjectlist;
  do
    echo -e "${GREEN}Performing smoothing on ${subject} session 1: ${NC}"
    fslmaths ${fmriprepdir}/derivatives/${subject}/ses-001/func/rest_func_data_regressors_filtered.nii.gz -s 3.40 ${fmriprepdir}/derivatives/${subject}/ses-001/func/rest_func_data_regressors_filtered_smooth.nii.gz
done
