#!/bin/bash

#User inputs
workingdir=/home/jpmcgeown/fmri_wf/
#heudiconv_img=nipy/heudiconv:latest
cohort=rugby
subject=2
session=001

echo $workingdir
echo $rugby$subject
echo $session

# Generate dicom_info.tsv to develop heuristic.py for Bids/Nifti conversion using Heudiconv

docker run --rm -it -v $workingdir:/base \
nipy/heudiconv:latest \
-d /base/dicom/sub_{subject}/ses_{session}/SCANS/*/DICOM/* \
-o /base/ \
-f convertall \
-s $cohort$subject \
-ss $session \
-c none \
--overwrite
# *** Don't forget to delete .heudiconv folder after updating heuristic.py or conversion won't work
