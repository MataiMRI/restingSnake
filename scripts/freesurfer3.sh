#!/bin/bash
#set-up environment
# export FREESURFER_HOME=/usr/local/freesurfer
# source $FREESURFER_HOME/SetUpFreeSurfer.sh
# export FS_LICENSE=~/Desktop/fmri_dev/license.txt

#user inputs
# bids_root_dir=~/Desktop/fmri_dev
subj=rugby2
ses=001

# echo $bids_root_dir
echo $subj
echo $ses

docker run --rm -ti \
  -v ~/fmri_wf:/base \
  -v ~/fmri_wf/bids:/input:ro \
  -v ~/fmri_wf/bids/derivatives:/output \
  -e FS_LICENSE=/base/license.txt \
  freesurfer/freesurfer:7.1.1 \
  recon-all -sd /output/ -i /input/sub-$subj/ses-$ses/anat/sub-rugby2_ses-001_run-001_T1w.nii.gz -subjid sub-$subj -all -qcache -3T


# recon-all -sd $bids_root_dir/derivatives/freesurfer -subjid sub-$subj \
# -i $bids_root_dir/sub-$subj/ses-$ses/anat/*T1w.nii.gz -all -qcache -3T
