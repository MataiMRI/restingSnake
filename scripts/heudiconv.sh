#!/bin/bash

#User inputs
dicom_root_dir=/home/jpmcgeown/fmri_wf/
#heudiconv_img=nipy/heudiconv:latest
subj=06
ses=001
task=convert #generate_heuristic or convert

echo $dicom_root_dir
#echo $heudiconv_img
echo $subj
echo $ses
echo $task

# Generate dicom_info.tsv to develop heuristic.py for Bids/Nifti conversion using Heudiconv

if [ $task == generate_heuristic ]; then
	docker run --rm -it -v $dicom_root_dir:/base \
	nipy/heudiconv:latest \
	-d /base/data/dicom/sub_{subject}/ses_{session}/SCANS/*/DICOM/* \
	-o /base/ \
	-f convertall \
	-s $subj \
	-ss $ses \
	-c none \
	--overwrite
# *** Don't forget to delete .heudiconv folder after updating heuristic.py or conversion won't work

# Run heudiconv to convert dicoms into bids formatted nifti files to feed through fmriprep-docker
else
	docker run --rm -it -v $dicom_root_dir:/base \
	nipy/heudiconv:latest \
	-d /base/data/dicom/sub_{subject}/ses_{session}/SCANS/*/DICOM/* \
	-o /base/data/ \
	-f /base/code/heuristic.py \
	-s $subj \
	-ss $ses \
	-c dcm2niix \
	-b \
	--overwrite

fi
