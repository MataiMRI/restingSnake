#!/bin/bash

workingdir=$1
cohort=$2
subject=$3
fs_status=$4
fs_dir=$5
threads=$6
mem=$7
echo
echo Fressurfer option selected $fs_status
echo

if [ $fs_status == None ]; then

  fmriprep-docker $workingdir/bids $workingdir/bids/derivatives \
      participant \
      --participant-label $cohort$subject \
      --skip-bids-validation \
      --md-only-boilerplate \
      --fs-license-file $workingdir/license.txt \
      --output-spaces MNI152NLin2009cAsym:res-2 \
      --nthreads $threads \
      --stop-on-first-crash \
      --mem_mb $mem \
      -w $workingdir/work

elif [ $fs_status == --fs-no-reconall ]; then

  fmriprep-docker $workingdir/bids $workingdir/bids/derivatives \
      participant \
      --participant-label $cohort$subject \
      --skip-bids-validation \
      --md-only-boilerplate \
      --fs-license-file $workingdir/license.txt \
      $fs_status \
      --output-spaces MNI152NLin2009cAsym:res-2 \
      --nthreads $threads \
      --stop-on-first-crash \
      --mem_mb $mem \
      -w $workingdir/work

elif [ $fs_status == --fs-subjects-dir ]; then

  fmriprep-docker $workingdir/bids $workingdir/bids/derivatives \
      participant \
      --participant-label $cohort$subject \
      --skip-bids-validation \
      --md-only-boilerplate \
      --fs-license-file $workingdir/license.txt \
      $fs_status \
      $fs_dir \
      --output-spaces MNI152NLin2009cAsym:res-2 \
      --nthreads $threads \
      --stop-on-first-crash \
      --mem_mb $mem \
      -w $workingdir/work
fi
