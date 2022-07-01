#!/bin/bash
#set-up environment
# export FREESURFER_HOME=/usr/local/freesurfer
# source $FREESURFER_HOME/SetUpFreeSurfer.sh
# export FS_LICENSE=~/Desktop/fmri_dev/license.txt

# export SUBJECTS_DIR=/usr/local/freesurfer/subjects/fsaverage


#user inputs
bids_root_dir=~/fmri_wf
subj=rugby2

docker run -ti --rm \
  -v $bids_root_dir:/base:ro \
  -v $bids_root_dir/bids/derivatives:/outputs \
  -v $bids_root_dir/scripts/license.txt:/license.txt \
  bids/freesurfer \
  /base/bids/ \
  /outputs/freesurfer/ \
  participant --participant_label $subj \
  --license_file "/license.txt" \
  --stages all \
  --qcache \
  --3T true \
  --skip_bids_validator

    # -e SUBJECTS_DIR=/usr/local/freesurfer/subjects \
