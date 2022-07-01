#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu May 26 12:38:50 2022

@author: jpmcgeown
"""

import pandas as pd
import os
import sys
import numpy as np

# os.chdir('../')

df = pd.read_csv('./workflow_record.csv')

if 'accept_fmriprep_qc' in df.columns:
    print('accept_fmriprep_qc column already exists')
    pass
else:
    print('creating new column')
    df['accept_fmriprep_qc'] = np.nan

unchecked = []
accept = []
reject = []

for i in range(len(df)):
    if pd.isnull(df['accept_fmriprep_qc'][i]):
        unchecked.append(df['cohort'][i] + str(df['subject'][i]))
    elif df['accept_fmriprep_qc'][i] == True:
        accept.append(df['cohort'][i] + str(df['subject'][i]))
    elif df['accept_fmriprep_qc'][i] == False:
        reject.append(df['cohort'][i] + str(df['subject'][i]))

if len(unchecked) > 0:
    print('\n\nPlease perform manual quality check of FMRIPREP reports for:\n', unchecked, '\n')
if len(accept) > 0:
    print('\n\nfMRIPREP quality check acceptable for:\n', accept, '\n')
if len(reject) > 0:
    print('\n\nFMRIPREP finished but quality check identified issues that need troubleshooting for:\n', reject, '\n')

df.to_csv('./workflow_record.csv', index = False)