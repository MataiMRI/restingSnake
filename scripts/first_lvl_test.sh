#!/bin/bash

python ./scripts/first_level_prob_atlas_hcp1.py \
/nesi/nobackup/uoa03264/fMRIpipeline_data/processed_test_josh/bids/derivatives/fmriprep/sub-rugby1/ses-a/func/sub-rugby1_ses-a_task-rest_run-001_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz \
/nesi/nobackup/uoa03264/fMRIpipeline_data/processed_test_josh/bids/derivatives/fmriprep/sub-rugby1/ses-a/func/sub-rugby1_ses-a_task-rest_run-001_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz \
/nesi/nobackup/uoa03264/fMRIpipeline_data/processed_test_josh/bids/derivatives/fmriprep/sub-rugby1/ses-a/func/sub-rugby1_ses-a_task-rest_run-001_desc-confounds_timeseries.tsv \
/nesi/nobackup/uoa03264/fMRIpipeline_data/processed_test_josh/first_level_results/sub-rugby1/ses-a/sub-rugby1_ses-a_DMN_unthresholded_fc.nii.gz \
/nesi/nobackup/uoa03264/fMRIpipeline_data/processed_test_josh/first_level_results/sub-rugby1/ses-a/sub-rugby1_ses-a_DMN_figure.png \
-a_img ./atlas/MSDL_rois/msdl_rois.nii \
-a_lab ./atlas/MSDL_rois/msdl_rois_labels.csv \
-tr 1.5 \
-rg csf white_matter trans_x trans_y trans_z rot_x rot_y rot_z \
-ntwk DMN \
-hp 0.01 \
-lp 0.1 \
-fwhm 6 \
-fdr 0.01 \
-fc 0.25 \
-v