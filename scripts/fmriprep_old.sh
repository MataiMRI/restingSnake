#!/bin/bash
#User inputs:
bids_root_dir=~/Desktop/fmri_dev
subj=06
nthreads=4
mem=25 #gb
container=docker #docker or singularity
fs_status=--fs-subjects-dir #--fs-no-reconall to skip fsl or blank space to run fsl
fs_dir=$bids_root_dir/derivatives/freesurfer

echo $bids_root_dir
echo $subj
echo $fs_status $fs_dir

#Begin:

#Convert virtual memory from gb to mb
mem=`echo "${mem//[!0-9]/}"` #remove gb at end
mem_mb=`echo $(((mem*1000)-5000))` #reduce some memory for buffer space during pre-processing

export FS_LICENSE=$bids_root_dir/derivatives/license.txt

#Run fmriprep
if [ $container == singularity ]; then
  unset PYTHONPATH; singularity run -B ~/.cache/templateflow:/opt/templateflow ~/fmriprep.simg \
    $bids_root_dir $bids_root_dir/derivatives \
    participant \
    --participant-label $subj \
    --skip-bids-validation \
    --md-only-boilerplate \
    --fs-license-file $bids_root_dir/derivatives/license.txt \
    $fs_status $fs_dir \
    --output-spaces MNI152NLin2009cAsym:res-2 \
    --nthreads $nthreads \
    --stop-on-first-crash \
    --mem_mb $mem_mb \
    -w ~/scratch/work
else
  fmriprep-docker $bids_root_dir $bids_root_dir/derivatives \
    participant \
    --participant-label $subj \
    --skip-bids-validation \
    --md-only-boilerplate \
    --fs-license-file $bids_root_dir/derivatives/license.txt \
    $fs_status $fs_dir \
    --output-spaces MNI152NLin2009cAsym:res-2 \
    --nthreads $nthreads \
    --stop-on-first-crash \
    --mem_mb $mem_mb \
    -w ~/scratch/work

fi
