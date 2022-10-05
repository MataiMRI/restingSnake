#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct  5 08:24:39 2022

@author: jpmcgeown
"""
import os
import sys
import pandas as pd
import numpy as np

#Define arguments passed from configfile
# dicomdir = sys.argv[1] + '/dicom'
# prefix = sys.argv[2]
# projectdir = sys.argv[3]

dicomdir = '/home/jpmcgeown/data/fmri' + '/dicom'
prefix = 'Conc_20Ntb14_'
projectdir = '/home/jpmcgeown/github/fmri_workflow'

os.chdir(dicomdir) #Change directory to location of dicoms

available_scans = os.listdir() #Save a list of the available scans

#Generate df from list of scans and tidy up
scan_list = pd.DataFrame(available_scans, columns=['original_id'])
scan_list['scan_id'] = scan_list['original_id']
scan_list['scan_id'] = scan_list['scan_id'].str.replace(prefix,'')
scan_list[['cohort', 'subject','session']] = scan_list['scan_id'].str.split('_', 2, expand=True)
scan_list['valid_orig_ses_label'] = np.where(scan_list['session'].isna(), False, True)
scan_list['session'].fillna('A', inplace=True)

#%%
for i in range(len(scan_list)):
    new_dir = 'sub_{cohort}_{subject}/ses_{session}/'.format(cohort = scan_list['cohort'][i],
                                                             subject = scan_list['subject'][i],
                                                             session = scan_list['session'][i])
    print(new_dir)
    os.makedirs(os.path.join(os.getcwd(), new_dir), mode = 0o777)

#%%
#Perform matching to update names for be more heudiconv friendly
print('\n------Renaming folders to be Heudiconv compatible -------\n')
for scan_id in scan_list['scan_id']:
    idx_match = [idx for idx, val in enumerate(available_scans) if scan_id in val]
    # print(scan_id, '            index = ', idx_match)

    cohort = scan_list.loc[scan_list['scan_id'] == scan_id, 'cohort']
    subject = scan_list.loc[scan_list['scan_id'] == scan_id, 'subject']
    session = scan_list.loc[scan_list['scan_id'] == scan_id, 'session']

    new_name = ' {cohort}_{subject}_{session}'.format(cohort = cohort[idx_match[0]],
                                                     subject = subject[idx_match[0]],
                                                     session = session[idx_match[0]]).lower()
    print('Original folder name: ', available_scans[idx_match[0]], '     Renamed folder: ', new_name)
    os.rename(available_scans[idx_match[0]], new_name)

#Convert all string columns to lowercase except the first column containing original name
scan_list.iloc[:, 1:] = scan_list.iloc[:,1:].applymap(lambda s: s.lower() if type(s) == str else s)

#%%
#Save scan list df to csv
scan_list.to_csv(projectdir + '/scan_list.csv', index = False)
