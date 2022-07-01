#!/bin/bash

workingdir=/home/jpmcgeown/fmri_wf
cohort=rugby
subject=3
fs_status=--fs-subjects-dir
# fs_dir=
threads=4
mem=25
echo
echo FS STATUS IS
echo $fs_status

if [ $fs_status == None ]; then

  echo Run free surfer $fs_status $cohort$subject $threads $mem $workingdir
  # fmriprep-docker $workingdir/bids $workingdir/bids/derivatives \
  #     participant \
  #     --participant-label $cohort$subject \
  #     --skip-bids-validation \
  #     --md-only-boilerplate \
  #     --fs-license-file $workingdir/license.txt \
  #     --output-spaces MNI152NLin2009cAsym:res-2 \
  #     --nthreads $threads \
  #     --stop-on-first-crash \
  #     --mem_mb $mem \
  #     -w $workingdir/work

elif [ $fs_status == --fs-no-reconall ]; then

  echo Skip recon-all $fs_status $cohort$subject $threads $mem $workingdir

  # fmriprep-docker $workingdir/bids $workingdir/bids/derivatives \
  #     participant \
  #     --participant-label $cohort$subject \
  #     --skip-bids-validation \
  #     --md-only-boilerplate \
  #     --fs-license-file $workingdir/license.txt \
  #     $fs_status \
  #     --output-spaces MNI152NLin2009cAsym:res-2 \
  #     --nthreads $threads \
  #     --stop-on-first-crash \
  #     --mem_mb $mem \
  #     -w $workingdir/work

elif [ $fs_status == --fs-subjects-dir ]; then
  echo Run free surfer $fs_status $cohort$subject $threads $mem $workingdir

  # fmriprep-docker $workingdir/bids $workingdir/bids/derivatives \
  #     participant \
  #     --participant-label $cohort$subject \
  #     --skip-bids-validation \
  #     --md-only-boilerplate \
  #     --fs-license-file $workingdir/license.txt \
  #     $fs_status \
  #     $fs_dir \
  #     --output-spaces MNI152NLin2009cAsym:res-2 \
  #     --nthreads $threads \
  #     --stop-on-first-crash \
  #     --mem_mb $mem \
  #     -w $workingdir/work

fi
