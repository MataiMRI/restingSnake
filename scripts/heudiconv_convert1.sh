#!/bin/bash

#User inputs
wf_dir=/home/jpmcgeown/fmri_wf/
#heudiconv_img=nipy/heudiconv:latest

subjectlist=$(cat $wf_dir/subject_list.txt )
seslist=$(cat $wf_dir/ses_list.txt)
echo $subjectlist
echo $seslist

# subj=02
ses=001


# echo $dicom_root_dir
# #echo $heudiconv_img
# echo $subj
# echo $ses

for subj in $subjectlist; do # loop through subjects
    # echo -e "${GREEN}Running Heudiconv for ${subject} ${NC}"
		# docker run --rm -it -v $wf_dir:/base \
		# nipy/heudiconv:latest \
		# -d /base/data/dicom/sub_{subject}/ses_{session}/SCANS/*/DICOM/* \
		# -o /base/data \
		# -f /base/code/heuristic.py \
		# -s $subj \
		# -ss $ses \
		# -c dcm2niix \
		# -b \
		# --overwrite

    for ses in $seslist; do # loop through each session per subject
    # make sure session data is available for current subject and raise if missing
		# 		# Run heudiconv to convert dicoms into bids formatted nifti files to feed through fmriprep-docker
			docker run --rm -it -v $wf_dir:/base \
			nipy/heudiconv:latest \
			-d /base/dicom/sub_{subject}/ses_{session}/SCANS/*/DICOM/* \
			-o /base/bids \
			-f /base/code/heuristic.py \
			-s $subj \
			-ss $ses \
			-c dcm2niix \
			-b \
			--overwrite
		done
done
