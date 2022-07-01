#!/usr/bin/python3

# Script name: extract_framewise_displacement.py
# Author: Josh McGeown adapted from original script by Remika Mito
# Description: This script pulls out the mean framewise displacement values from the confounds_regressors.tsv output from fMRIPrep

### IMPORT LIBRARIES ###
import pandas as pd
import sys, getopt
import os
import scipy
from scipy import stats

subj = 'sub-02'
# subj = (sys.argv[1])
#ses = (sys.argv[2])
#input = (sys.argv[1])
#output = (sys.argv[2])
input_ses01 = '/home/jpmcgeown/fmri_wf/bids/derivatives/' + subj + '/ses-001/func/' + subj + '_ses-001_task-rest_run-1_desc-confounds_timeseries.tsv'
output_ses01 = '/home/jpmcgeown/fmri_wf/bids/derivatives/' + subj + '/ses-001/func/'

df_ses01 = pd.read_csv(input_ses01, sep='\t')

csf_ses01 = df_ses01["csf"]

wm_ses01 = df_ses01["white_matter"]

transx_ses01 = df_ses01["trans_x"]

transy_ses01 = df_ses01["trans_y"]

transz_ses01 = df_ses01["trans_z"]

rotx_ses01 = df_ses01["rot_x"]

roty_ses01 = df_ses01["rot_y"]

rotz_ses01 = df_ses01["rot_z"]

# fd_ses01 = df_ses01["framewise_displacement"]

# confounds_df_ses01 = pd.concat([csf_ses01, wm_ses01, transx_ses01, transy_ses01, transz_ses01, rotx_ses01, roty_ses01, rotz_ses01, fd_ses01], axis=1)
confounds_df_ses01 = pd.concat([csf_ses01, wm_ses01, transx_ses01, transy_ses01, transz_ses01, rotx_ses01, roty_ses01, rotz_ses01], axis=1)
print(confounds_df_ses01)

df_name_ses01 = output_ses01 + "regressors.txt"

print(df_name_ses01)
confounds_df_ses01.to_csv(df_name_ses01, header=None, index=None, sep="\t")

# else:
#
#     confounds_df_ses01 = pd.concat([csf_sess01, wm_ses01, transx_ses01, transy_ses01, transz_ses01, rotx_ses01, roty_ses01, rotz_ses01], axis=1)
#     confounds_df_ses02 = pd.concat([csf_ses02, wm_ses02, transx_ses02, transy_ses02, transz_ses02, rotx_ses02, roty_ses02, rotz_ses02], axis=1)
#     print(confounds_df_ses01)
#print(pval)
