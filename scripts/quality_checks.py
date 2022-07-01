#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu May 26 09:45:52 2022

@author: jpmcgeown
"""
import pandas as pd
import os
import sys
import numpy as np

# os.chdir('../')

sessions = pd.read_csv('./scan_list.csv')
df = pd.read_csv('./workflow_record1.csv')
df['session'] = df['scan_id'].str.strip().str[-3:] # TEMPORARY WORKAROUND FOR LEADING ZEROS GETTING DROPPED FROM SESSION labels
pd.set_option('mode.chained_assignment', None)

new_cols = ['confound_extract', 'mean_frame_disp', 'accept_frame_disp']
#%%
displacement_threshold = float(sys.argv[1])

for col in new_cols:
    if col in df.columns:
        pass
    else:
        df[col] = np.nan

confound_list = []
args = 3 + int(sys.argv[2])
for i in range(3,args):
    confound_list.append(sys.argv[i])
    
# confound_list = sys.argv[3:sys.argv[2]] # convert to sys arg
# confound_list = ['csf', 'white_matter', 'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z', 'framewise_displacement']

print('\n Timeseries for the following short list of confound regressors will be compiled:\n', confound_list)

for i in range(len(df)):
    subject = str(df['subject'][i])
    session = str(df['session'][i])
    cohort = df['cohort'][i]
    
    func_path = "./bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/".format(cohort = cohort, subject = subject, session = session)
    confound_path = func_path + 'sub-{cohort}{subject}_ses-{session}_task-rest_run-1_desc-confounds_timeseries.tsv'.format(cohort = cohort, subject = subject, session = session)
    
    full_confounds_df = pd.read_csv(confound_path, delimiter = '\t')
    confounds = full_confounds_df[confound_list]
    confounds.update(confounds.iloc[[0]].fillna(0)) # replace any nans in first row with zero
    confounds.to_csv(func_path + 'regressors.txt', header=None, index=None, sep="\t")
    df['confound_extract'][i] = True
    
    mean_fd = np.mean(confounds['framewise_displacement'])
    df['mean_frame_disp'][i] = mean_fd
    print('\n\nMean framewise displacement for {cohort}{subject} ses-{session}:'.format(cohort=cohort, subject=subject, session=session), mean_fd)
    
df['accept_frame_disp'] = np.where(df['mean_frame_disp'] > displacement_threshold, False, True)
#%%
check = df.loc[df['accept_frame_disp'] != True]

if len(check) > 0:
    print('\nMEAN FRAMEWISE DISPLACEMENT EXCEEDS', displacement_threshold, 'MILLIMETRES! THE FILES BELOW REQUIRE THE USERS ATTENTION AND WILL NOT PROCEED TO FIRST LEVEL ANALYSIS!')
    for i in range(len(check)):
        print(df['cohort'][i], df['subject'][i], 'ses-', df['session'][i])

first_level = df.loc[(df['bids_valid'] == True) & (df['accept_fmriprep_qc'] == True) & (df['confound_extract'] == True) & (df['accept_frame_disp'] == True)]

if len(first_level) > 0:
    print('\nThe following scans are ready for first level analysis:\n')
    print(list(first_level['cohort'] + first_level['subject'].astype(str) + ' ses-' + first_level['session'].astype(str)))
    print('\n\n')
    
    first_level.to_csv('first_level_dataset_clean.csv', index = False)
    print('*** first_level_dataset_clean.csv contains all scans ready for first level analysis\n')
    print(first_level)
else:
    print('\n\n****')
    raise Exception('\nCANNOT PROCEED TO FIRST LEVEL ANALYSIS: first_level_dataset_clean.csv is empty\n\n***')

df.to_csv('workflow_record1.csv', index = False)

