#!/bin/bash

# Author: Dr Josh McGeown - Matai Medical Research Institute
# 22/3/22

#For snakemake rules to work input and ouput file extensions are needed.
#Step 1 in workflow is to convert dicoms to nifti files in BIDS format but sometimes
#on Ubuntu the .dcm extension is not present for dicoms which prevents snakemake from running
#This script is meant to be run before calling the snakefile to ensure raw dicoms include .dcm extension

base=/home/jpmcgeown/fmri_wf

# User needs to define a list of expected subjects, sessions, and sequences to run this script.
# Could pull from spreadsheet but here each list is saved to it's own .txt file for simplicity.

subjectlist=$(cat $base/subject_list.txt)
seslist=$(cat $base/ses_list.txt)
seqlist=$(cat $base/seq_list.txt)

# anat_slice_num=304
# rest_func_slice_num=10000
# echo $anat_slice_num $rest_func_slice_num

echo "Base directory located at:" $base
echo
echo "Data available for the following subjects:" $subjectlist
echo "Expected sessions in dataset:" $seslist
echo 'Expected sequences per session:' $seqlist
echo

GREEN='\033[1;32m' #ANSI escape codes
NC='\033[0m'

for subject in $subjectlist; do # loop through subjects
    echo -e "${GREEN}Correcting dicom extension for ${subject} ${NC}"

    for ses in $seslist; do # loop through each session per subject
    # make sure session data is available for current subject and raise if missing
      if [ ! -d "${base}/data/${subject}/${ses}/" ]; then
        echo '********' $ses 'UNAVAILABLE for' $subject '*******'
        echo
        :

      else
        for seq in $seqlist; do # loop through sequence for each session
        # make sure all expected sequences are available for current sesion and raise if missing
          if [ ! -d "${base}/data/${subject}/${ses}/SCANS/${seq}/DICOM" ]; then
            echo '*******' $seq 'UNAVAILABLE for' $subject $ses '*******'
            echo
            :

          else
            # if session and sequence  dirs available change dir to add file extension
            cd ${base}/data/${subject}/${ses}/SCANS/${seq}/DICOM
            files=(*)
            # check if extension is already present. Skip if TRUE, add extension if FALSE
            if [[ $files == "sub"*".dcm" ]]; then
              echo "FILE EXTENSION CORRECT for" $subject $ses $seq
              echo
              :
            else
              echo "Adding dicom file extensions for" $subject $ses $seq
              slice=1
              for f in *; do
                if [[ $f == *"v_header"* ]]; then
                  echo 'DID NOT RENAME:' $f
                  echo
                  :
                else
                  mv "$f" "${subject}_${ses}_${seq}_slice${slice}.dcm"
                  slice=$((slice+1))

                fi
              done
            fi
          fi
        done
      fi
  done
done
