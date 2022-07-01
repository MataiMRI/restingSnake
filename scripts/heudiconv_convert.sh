#!/bin/bash

workingdir=$1
cohort=$2
subject=$3
session=$4

docker run --rm -it -v $workingdir:/base \
    nipy/heudiconv:latest \
    -d /base/dicom/sub_{{subject}}/ses_{{session}}/SCANS/*/DICOM/* \
    -o /base/bids \
    -f /base/scripts/heuristic.py \
    -s $cohort$subject \
    -ss $session \
    -c dcm2niix \
    -b \
    --overwrite
