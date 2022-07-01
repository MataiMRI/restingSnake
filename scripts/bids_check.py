#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Mar 30 17:07:33 2022

@author: jpmcgeown
"""

import bids_validator
from bids_validator import BIDSValidator
import os
import pandas as pd

validator = BIDSValidator()

df = pd.read_csv('./scan_list.csv')
df['scan_id'] = df['scan_id'].str.replace('conc_ethics_' ,'')
df[['cohort', 'subject','session']] = df['scan_id'].str.split('_', 2, expand=True)
df['bids_valid'] = False

root_dir = "./bids/"
file_list = []

for dir_, _, files in os.walk(root_dir):
    for file_name in files:
        rel_dir = os.path.relpath(dir_, root_dir)
        rel_file = os.path.join(rel_dir, file_name)
        
        if '.heudiconv' in rel_file:
            pass
        elif rel_file[0] == '.':
            rel_file = rel_file[1:]
            file_list.append(rel_file)
        elif rel_file[0] != '/':
            rel_file = '/' + rel_file
            file_list.append(rel_file)
        else:
            file_list.append(rel_file)
 
bids_check = [ [] for i in range(len(df))]
lines = []

for i in range(len(df)):
    # sub = df['ids'][i]
    sub = 'sub-' + df['cohort'][i] + df['subject'][i]
    s = 'ses-' + df['session'][i]
    for f in file_list:
        if sub in f and s in f:
            bids_check[i].append(validator.is_bids(f))
    if False in bids_check[i] or len(bids_check[i]) == 0:
        lines.append('*** {sub} {s} IS NOT BIDS COMPLIANT! ***\n'.format(sub=sub, s = s))
    else:
        df.iloc[i, -1] = True
        lines.append(('{sub} {s} is BIDS compliant\n'.format(sub=sub, s = s)))
        
print(df)

#%%
if df['bids_valid'].all():
    print('\nAll files are BIDS compliant proceed to freesurfer!\
          \nFor a record of converted subjects and sessions see workflow_record.csv\n')
    df.to_csv('./workflow_record.csv', index = False)
else:
    df.to_csv('./workflow_record.csv', index = False)
    raise Exception('BIDS VALIDATION ERROR --- NOT ALL FILES ARE BIDS COMPLIANT... see workflow_record.csv in BASE DIRECTORY for troubleshooting')
    