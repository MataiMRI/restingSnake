#!/bin/bash

#User inputs
wf_dir=/home/jpmcgeown/fmri_wf/
#heudiconv_img=nipy/heudiconv:latest

# subjectlist=$(cat $wf_dir/subject_list.txt )
# seslist=$(cat $wf_dir/ses_list.txt)
echo $subjectlist
echo $seslist

subj=2
ses=001


docker run --rm -it -v $wf_dir:/base \
nipy/heudiconv:latest \
-d /base/dicom/sub_{subject}/ses_{session}/SCANS/*/DICOM/* \
-o /base/bids \
-f /base/scripts/heuristic.py \
-s $subj \
-ss $ses \
-c dcm2niix \
-b \
--overwrite
