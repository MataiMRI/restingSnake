#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jan 21 14:29:23 2022

@author: jpmcgeown
"""
from nilearn import datasets
from nilearn import input_data
from nilearn import plotting
from nilearn import image
from nilearn.input_data import NiftiMapsMasker
from mne.stats import fdr_correction
from scipy import stats
import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np
import os
import glob
import json
import pandas as pd
import sys

#%%
# Inputs
workingdir = sys.argv[1]
cohort = sys.argv[2]
subject = sys.argv[3]
session = sys.argv[4]
ntwk = sys.argv[5].encode()
# mask_file = sys.argv[5]
# func_file = sys.argv[6]
# confound_file = sys.argv[7]
# task = 
rep_time = float(sys.argv[6])
hp = float(sys.argv[7])
lp = float(sys.argv[8])
fwhm = float(sys.argv[9])
fdr_alpha = float(sys.argv[10])
thresh = float(sys.argv[11])
num_networks = int(sys.argv[12])
# network_idx = len(sys.argv) - num_networks



mask_file = glob.glob(workingdir + '/bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz'.format(cohort = cohort, subject = subject, session = session))[0]
func_file = glob.glob(workingdir + '/bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/sub-{cohort}{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz'.format(cohort = cohort, subject = subject, session = session))[0]
confound_file = glob.glob(workingdir + '/bids/derivatives/sub-{cohort}{subject}/ses-{session}/func/regressors.txt'.format(cohort = cohort, subject = subject, session = session))[0]

# print(len(sys.argv) - num_networks)
print(mask_file, func_file, confound_file, rep_time, hp, lp, fwhm, thresh, num_networks)

# network_list = []
# for i in range(network_idx, len(sys.argv)):
#     network_list.append(sys.argv[i].encode())
    
# ntwk = network_list[0]
    
# print(network_list)

mask = nib.load(mask_file)
confounds = pd.read_csv(confound_file, sep = '\t')
confounds = confounds.iloc[:, :-1]
print('\n\n', confounds, '\n\n')
confounds_matrix = confounds.values

print('{mask} \n {func} \n {confounds} \n {num_net} \n \n'.format(mask = mask_file, func = func_file, confounds = confound_file, num_net = num_networks) )

with open('temp.txt', 'w') as fp:
    pass

#%%
#Load MSDL atlas to provide functional network options below
atlas = datasets.fetch_atlas_msdl()
atlas_filename = atlas['maps']

#%%
#Load and plot raw fmri image
epi_img = nib.load(func_file)
# mean_epi = image.mean_img(epi_img)
# plotting.plot_epi(mean_epi)

# print basic information on the dataset
print('First subject functional nifti image (4D) is at: %s' %
      func_file)  # 4D data
#%%
#Generate blank dictionary of 16 unique msdl_networks
keys = list(set(atlas['networks']))
msdl_networks = dict.fromkeys(keys)
for key in msdl_networks.keys():
    msdl_networks[key] = []

#Populate dictionary with indexes of anatomical seeds that correspond to functional networks
for i in range(0, len(atlas['networks'])):
    temp = atlas['networks'][i]
    if temp in msdl_networks.keys():
        msdl_networks[temp].append(i)
    else:
        msdl_networks[temp] = None
#%%
# Define single network and plot probabilistic map from atlas
fig, ax = plt.subplots(nrows=2) #Create fig object to plot atlas and subject bold signal together

network_nodes = image.index_img(atlas_filename, msdl_networks[ntwk]) #define nodes
print(network_nodes.shape)
   
atlas_plot = plotting.plot_prob_atlas(network_nodes, cut_coords = 6,
                                      display_mode='z', title='{ntwk} nodes in MSDL atlas'.format(ntwk=ntwk),
                                      axes = ax[0])
#%%
# View probabilistic map for all networks within atlas individually
# for i in keys:
#     print(i)
#     network_nodes = image.index_img(atlas_filename, msdl_networks[i])
#     atlas_plot = plotting.plot_prob_atlas(network_nodes, cut_coords = 8, display_mode='z', title='{ntwk} nodes in MSDL atlas'.format(ntwk=i))
#%%
#Create mask using user-specified network nodes from MSDL atlas
atlas_masker = NiftiMapsMasker(
    maps_img= network_nodes,
    smoothing_fwhm = fwhm,
    standardize=True, detrend = True,
    low_pass= lp, high_pass= hp, t_r=rep_time, memory='nilearn_cache', verbose = 0, mask_img = mask)

network_time_series = atlas_masker.fit_transform(func_file, confounds= confounds_matrix) # time series for network of interest

#Create brain-wide mask
brain_masker = input_data.NiftiMasker(
    smoothing_fwhm= fwhm,
    detrend=True, standardize=True,
    low_pass= lp, high_pass= hp, t_r=rep_time,
    memory='nilearn_cache', memory_level=1, verbose=0, mask_img=mask)
brain_time_series = brain_masker.fit_transform(func_file, confounds = confounds_matrix)

print("Seed time series shape: (%s, %s)" % network_time_series.shape)
print("Brain time series shape: (%s, %s)" % brain_time_series.shape)
#%%
#Correlate network nodes of interest against brain mask time series
network_to_voxel_correlations = (np.dot(brain_time_series.T, network_time_series) /
                              network_time_series.shape[0])

print("Network-to-voxel correlation shape: (%s, %s)" %
      network_to_voxel_correlations.shape)
print("Network-to-voxel correlation: min = %.3f; max = %.3f" % (
    network_to_voxel_correlations.min(), network_to_voxel_correlations.max()))

#%%
#calculate t statistics from network_to_voxel_correlations
t_vals = (network_to_voxel_correlations * np.sqrt((epi_img.shape[3]-2))) / np.sqrt((1 - network_to_voxel_correlations**2))
#convert t statistics to p values
p_vals = stats.t.sf(np.abs(t_vals), df = (epi_img.shape[3]-2)) * 2
#implement mne library fdr_correction 
reject_fdr, pval_fdr = fdr_correction(p_vals, alpha=fdr_alpha, method='indep')
reject_fdr = reject_fdr * 1 # convert boolean series to binary

network_to_voxel_correlations_corrected = network_to_voxel_correlations * reject_fdr
# network_to_voxel_correlations_corrected = p_vals * reject_fdr

network_to_voxel_correlations_corrected_img = brain_masker.inverse_transform(
    network_to_voxel_correlations_corrected.T)

nib.save(network_to_voxel_correlations_corrected_img, './results/{cohort}{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz'.format(cohort = cohort, subject = subject, session = session, network = ntwk.decode()))

#apply threshold and save

#%%
#Generate correlation nifti
# network_to_voxel_correlations_img = brain_masker.inverse_transform(
#     network_to_voxel_correlations.T)
#%%
#Plot first node of network
display = plotting.plot_stat_map(image.index_img(network_to_voxel_correlations_corrected_img, 0),
                                      threshold= thresh,
                                      cut_coords=[-16,0,16,30,44,58],                                     
                                      display_mode='z',
                                      vmax = 1,
                                      title="Network-to-voxel correlation - {ntwk} Matai test {subject}".format(subject=subject, ntwk=ntwk),
                                      cmap = 'cold_hot',
                                      axes = ax[1], output_file = './results/{cohort}{subject}_ses-{session}_{network}.png'.format(cohort = cohort, subject = subject, session = session, network = ntwk.decode()))

#Add overlays for additional nodes if network has >1 node
# for i in range (1, network_time_series.shape[1]):
#     display.add_overlay(image.index_img(network_to_voxel_correlations_corrected_img, i),
#                     threshold=thresh, cmap = 'cold_hot' )
# fig.show()
