#!/bin/bash
#set-up environment
export FREESURFER_HOME=/usr/local/freesurfer
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export FS_LICENSE=~/Desktop/fmri_dev/license.txt

#user inputs
# bids_root_dir=~/Desktop/fmri_dev
# subj=02
# ses=001
#
# echo $bids_root_dir
# echo $subj
# echo $ses
#
# recon-all -sd $bids_root_dir/derivatives/freesurfer -subjid sub-$subj \
# -i $bids_root_dir/sub-$subj/ses-$ses/anat/*T1w.nii.gz -all -qcache -3T
