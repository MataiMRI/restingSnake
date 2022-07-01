#!/bin/bash

# script_runfiltering.sh
# date created: 24-08-2021
# This script automatically runs fsl maths filtering (high and low pass) for all subjects

#Note that `fslmaths` uses sigma filtering rather than mm values. This means that we need to convert appropriate mm values to sigma values. 
#hp_sigma = (1/0.01)/1 = 100
#lp_sigma = (1/0.1)/1 = 10

fmriprepdir=/home/jpmcgeown/Desktop/fmri_dev
echo $fmriprepdir
subjectlist=$(cat $fmriprepdir/subject_list.txt ) 
echo $subjectlist

GREEN='\033[1;32m' #ANSI escape codes
NC='\033[0m'


for subject in $subjectlist;
  do
    echo -e "${GREEN}Performing filtering on ${subject} session 1: ${NC}"
    fslmaths ${fmriprepdir}/derivatives/${subject}/ses-001/func/rest_func_data_regressors.nii.gz -bptf 100 10 ${fmriprepdir}/derivatives/${subject}/ses-001/func/rest_func_data_regressors_filtered.nii.gz
done
