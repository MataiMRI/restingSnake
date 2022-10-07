#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct  6 09:05:33 2022

@author: jpmcgeown
"""

import os
import sys
import pandas as pd
import numpy as np
import shutil

#Define user determined variables from configfile

projectdir = sys.argv[1]
dicomdir = sys.argv[2] + '/dicom'
prefix = sys.argv[3]
compression = sys.argv[4]

# projectdir = '/home/jpmcgeown/github/fmri_workflow'
# dicomdir = '/home/jpmcgeown/data/fmri' + '/dicom'
# prefix = 'Conc_20Ntb14_'
# compression = '.zip'

# =============================================================================
# 
# =============================================================================

if os.path.exists(projectdir + '/scan_list.csv'):
    
    print('\nLoading scan_list.csv from ', projectdir, '\n')
    
    hist_df = pd.read_csv(projectdir + '/scan_list.csv')
    available_scans = os.listdir(dicomdir)
    historic_scans = hist_df['subject_dir'].tolist()
    new_scans = list(set(available_scans).difference(historic_scans))
    
    redundant = []
    for i in range(len(new_scans)):
        if hist_df['original_filename'].str.contains(new_scans[i]).any():
            redundant.append(new_scans[i])

    new_scans = list(filter(lambda x: x not in redundant, new_scans))
    print('The following files have already been processed and will be skipped:\n', redundant)
    new_df = pd.DataFrame(new_scans, columns = ['original_filename'])
    
    if len(new_scans) > 0:
        print('New sessions detected: ', new_scans)
        print('\nAppending new sessions to scan_list.csv\n')
        
        for i in range(len(new_scans)):
            
            if new_scans[i][-len(compression) : ] == compression:
                print(new_scans[i], ' is a compressed folder')
                print('Extracting contents from ', new_scans[i])
                shutil.unpack_archive(dicomdir + '/' + new_scans[i], dicomdir)
                
                try:
                    os.remove(os.path.join(dicomdir, new_scans[i]))
                    print("% s removed successfully" % new_scans[i])
                except OSError as error:
                    print(error)
                    print("File path can not be removed")
                
            else:
                print(new_scans[i], ' does not need extracting\n')
                
        new_df['scan_id'] = new_df['original_filename']
        new_df['scan_id'] = new_df['scan_id'].str.replace(prefix,'')
        new_df['scan_id'] = new_df['scan_id'].str.replace(compression,'')
        new_df[['cohort', 'subject','session']] = new_df['scan_id'].str.split('_', 2, expand=True)
        new_df['subject_dir'] = 'sub_' + new_df['cohort'] + '_' + new_df['subject'].astype(str)
        new_df['valid_orig_ses_label'] = np.where(new_df['session'].isna(), False, True)
        new_df['session'].fillna('A', inplace=True)
        new_df.iloc[:, 1:] = new_df.iloc[:,1:].applymap(lambda s: s.lower() if type(s) == str else s)   
        
        for i in range(len(new_df)):
            new_dir = 'sub_{cohort}_{subject}/ses_{session}/'.format(cohort = new_df['cohort'][i],
                                                                     subject = new_df['subject'][i],
                                                                     session = new_df['session'][i])
            print('Creating new directory: ', new_dir, '\n')
            os.makedirs(os.path.join(dicomdir, new_dir), mode = 0o777)
            
            if new_scans[i][-len(compression) : ] == compression:
                new_scans[i] = new_scans[i].replace(compression, "")
            
            subdirs = os.listdir(os.path.join(dicomdir, new_scans[i])) 
            dest = os.path.join(dicomdir, new_dir)
            
            for subdir in subdirs:
                dir_to_move = os.path.join(dicomdir, new_scans[i], subdir)
                print('Moving ', subdir, ' to ' , dest)
                shutil.move(dir_to_move, dest)
                
            os.removedirs(os.path.join(dicomdir, new_scans[i]))
    
        df = pd.concat([hist_df, new_df], axis = 0, ignore_index=True)
        #Convert all string columns to lowercase except the first column containing original name
        df.iloc[:, 1:] = df.iloc[:,1:].applymap(lambda s: s.lower() if type(s) == str else s)
        df.sort_values(by='scan_id', inplace = True)        
        df.to_csv(projectdir + '/scan_list.csv', index = False)
        
    else:
        print('\nNo new sessions to process')

# =============================================================================
# 
# =============================================================================
    
else:
    print('\nCreating scan_list.csv to record sessions available in workflow\n')
    
    available_scans = os.listdir(dicomdir)
    df = pd.DataFrame(available_scans, columns = ['original_filename'])
    
    for i in range(len(available_scans)):
        
        if available_scans[i][-len(compression) : ] == compression:
            print(available_scans[i], ' is a compressed folder')
            print('Extracting contents from ', available_scans[i])
            shutil.unpack_archive(dicomdir + '/' + available_scans[i], dicomdir)
            
            try:
                os.remove(os.path.join(dicomdir, available_scans[i]))
                print("% s removed successfully" % available_scans[i])
            except OSError as error:
                print(error)
                print("File path can not be removed")
            
        else:
            print(available_scans[i], ' does not need extracting\n')
            
    df['scan_id'] = df['original_filename']
    df['scan_id'] = df['scan_id'].str.replace(prefix,'')
    df['scan_id'] = df['scan_id'].str.replace(compression,'')
    df[['cohort', 'subject','session']] = df['scan_id'].str.split('_', 2, expand=True)
    df['subject_dir'] = 'sub_' + df['cohort'] + '_' + df['subject'].astype(str)
    df['valid_orig_ses_label'] = np.where(df['session'].isna(), False, True)
    df['session'].fillna('A', inplace=True)
    df.iloc[:, 1:] = df.iloc[:,1:].applymap(lambda s: s.lower() if type(s) == str else s)   
    
    for i in range(len(df)):
        new_dir = 'sub_{cohort}_{subject}/ses_{session}/'.format(cohort = df['cohort'][i],
                                                                 subject = df['subject'][i],
                                                                 session = df['session'][i])
        print('\nCreating new directory: ', new_dir)
        os.makedirs(os.path.join(dicomdir, new_dir), mode = 0o777)
        
        if available_scans[i][-len(compression) : ] == compression:
            available_scans[i] = available_scans[i].replace(compression, "")
        
        subdirs = os.listdir(os.path.join(dicomdir, available_scans[i])) 
        dest = os.path.join(dicomdir, new_dir)
        
        for subdir in subdirs:
            dir_to_move = os.path.join(dicomdir, available_scans[i], subdir)
            print('Moving ', subdir, ' to ' , dest)
            shutil.move(dir_to_move, dest)
            
        os.removedirs(os.path.join(dicomdir, available_scans[i]))

    #Convert all string columns to lowercase except the first column containing original name
    df.iloc[:, 1:] = df.iloc[:,1:].applymap(lambda s: s.lower() if type(s) == str else s)
    df.sort_values(by='scan_id', inplace = True)        
    df.to_csv(projectdir + '/scan_list.csv', index = False)
            


