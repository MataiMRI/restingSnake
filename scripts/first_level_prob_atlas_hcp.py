#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jan 21 14:29:23 2022

@author: jpmcgeown
"""

import glob
import argparse
import logging
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats
from mne.stats import fdr_correction
from nilearn import datasets
from nilearn import input_data
from nilearn import plotting
from nilearn import image
from nilearn.input_data import NiftiMapsMasker
import nibabel as nib

## create logger
logger = logging.getLogger()
logging.basicConfig(format="%(asctime)s :: %(name)s :: %(levelname)s :: %(message)s")

## create parser
## *** Should standardize, detrend, fdr method have optional arguments?
parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument(
    'data_dir',
    help='High memory directory where data will be read + written',
    type=str
)


parser.add_argument(
    '-s',
    help='Specify subject wildcard',
    type=int, 
    dest='subject'
)

# Session type could be int or str depending on how researchers have coded?
parser.add_argument(
    '-ss',
    help='Specify session wildcard',
    type=str,
    dest='session'
)

parser.add_argument(
    '-ntwk',
    help='Specify resting-state fMRI network wildcard',
    type=str,
    dest='functional_network'
)

parser.add_argument(
    '-tr',
    help='Specify scan repetition time from config file',
    type=float,
    dest='repetition_time'
)

parser.add_argument(
    '-hp',
    help='Specify high pass boundary of band pass filter from config file',
    dest='highpass',
    type = float,
    default = 0.01
)

parser.add_argument(
    '-lp',
    help='Specify low pass boundary of band pass filter from config file',
    dest='lowpass',
    type = float,
    default = 0.1
)

parser.add_argument(
    '-fwhm',
    help='Specify full width half maximum smoothing kernel from config file',
    type = int,
    default = 6
)

parser.add_argument(
    '-fdr',
    help='Specify False Detection Rate threshold to correct for multiple comparisons from config file',
    dest='fdr_threshold',
    type=float,
    default= 0.05
)

parser.add_argument(
    '-fc',
    help='Specify functional connectivity threshold from config file',
    dest='connectivity_threshold',
    type=float,
    default = 0.25
)

parser.add_argument(
    '-d', '--debug',
    help="Logging level for developers to debug issues with code",
    action="store_const", dest="loglevel", const=logging.DEBUG,
    default=logging.WARNING,
)

parser.add_argument(
    '-v', '--verbose',
    help="Logging level to display all steps running in code",
    action="store_const", dest="loglevel", const=logging.INFO,
    default=logging.WARNING,
)

args = parser.parse_args()

### FIND SOLUTION FOR THIS
logger.setLevel(logging.INFO)
#logging.basicConfig(level=args.loglevel)


mask_file = glob.glob(args.data_dir + 
                      '/bids/derivatives/sub-{subject}/ses-{session}/func/sub-{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-brain_mask.nii.gz'.format(
                          subject = args.subject,
                          session = args.session))[0]

mask = nib.load(mask_file)

confound_file = glob.glob(args.data_dir + 
                          '/bids/derivatives/sub-{subject}/ses-{session}/func/regressors.txt'.format(
                              subject = args.subject, 
                              session = args.session))[0]

confounds = pd.read_csv(confound_file, sep = '\t')
confounds = confounds.iloc[:, :-1]
confounds_matrix = confounds.values

logging.info(f'{confounds}')

func_file = glob.glob(args.data_dir + 
                      '/bids/derivatives/sub-{subject}/ses-{session}/func/sub-{subject}_ses-{session}_task-rest_run-1_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz'.format(
                          subject = args.subject, 
                          session = args.session))[0]

print(mask_file, func_file, confound_file, args.repetition_time, args.highpass, args.lowpass, args.fwhm, args.fc_thresh)
#Load and plot raw fmri image
epi_img = nib.load(func_file)
# mean_epi = image.mean_img(epi_img)
# plotting.plot_epi(mean_epi)

logging.info(f'{mask_file} \n {func_file} \n {confound_file}')

#Load MSDL atlas to provide functional network options below
atlas = datasets.fetch_atlas_msdl()
atlas_filename = atlas['maps']

# print basic information on the dataset
print('First subject functional nifti image (4D) is at: %s' %
      func_file)  # 4D data

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

# Define single network and plot probabilistic map from atlas
fig, ax = plt.subplots(nrows=2) #Create fig object to plot atlas and subject bold signal together

network_nodes = image.index_img(atlas_filename, msdl_networks[args.network]) #define nodes
print(network_nodes.shape)
   
atlas_plot = plotting.plot_prob_atlas(network_nodes, 
                                      cut_coords = 6,
                                      display_mode='z', 
                                      title='{ntwk} nodes in MSDL atlas'.format(ntwk=args.network),
                                      axes = ax[0])

nifti_verbose = 0
if args.loglevel <= logging.DEBUG:
    nifti_verbose = 2
elif args.loglevel <= logging.INFO:
    nifti_verbose = 1

#Create mask using user-specified network nodes from MSDL atlas
atlas_masker = NiftiMapsMasker(
    maps_img= network_nodes,
    smoothing_fwhm = args.fwhm,
    standardize=True, 
    detrend = True,
    low_pass= args.lowpass, 
    high_pass= args.highpass, 
    t_r=args.repetition_time, 
    memory='nilearn_cache', 
    verbose = 0, 
    mask_img = mask)

network_time_series = atlas_masker.fit_transform(func_file, confounds= confounds_matrix) # time series for network of interest

#Create brain-wide mask
brain_masker = input_data.NiftiMasker(
    smoothing_fwhm= args.fwhm,
    detrend=True, 
    standardize=True,
    low_pass= args.lowpass, 
    high_pass= args.highpass, 
    t_r=args.repetition_time,
    memory='nilearn_cache', 
    memory_level=1, 
    verbose= nifti_verbose, 
    mask_img=mask)

brain_time_series = brain_masker.fit_transform(func_file, confounds = confounds_matrix)

print("Seed time series shape: (%s, %s)" % network_time_series.shape)
print("Brain time series shape: (%s, %s)" % brain_time_series.shape)

#Correlate network nodes of interest against brain mask time series
network_to_voxel_correlations = (np.dot(brain_time_series.T, network_time_series) / network_time_series.shape[0])

print("Network-to-voxel correlation shape: (%s, %s)" %
      network_to_voxel_correlations.shape)
print("Network-to-voxel correlation: min = %.3f; max = %.3f" % (
    network_to_voxel_correlations.min(), network_to_voxel_correlations.max()))

#calculate t statistics from network_to_voxel_correlations
t_vals = (network_to_voxel_correlations * np.sqrt((epi_img.shape[3]-2))) / np.sqrt((1 - network_to_voxel_correlations**2))

#convert t statistics to p values
p_vals = stats.t.sf(np.abs(t_vals), df = (epi_img.shape[3]-2)) * 2

#implement mne library fdr_correction 
reject_fdr, pval_fdr = fdr_correction(p_vals, alpha=args.fdr_threshold, method='indep')
reject_fdr = reject_fdr * 1 # convert boolean series to binary

network_to_voxel_correlations_corrected = network_to_voxel_correlations * reject_fdr
# network_to_voxel_correlations_corrected = p_vals * reject_fdr

network_to_voxel_correlations_corrected_img = brain_masker.inverse_transform(network_to_voxel_correlations_corrected.T)

nib.save(
    network_to_voxel_correlations_corrected_img, 
    './results/{subject}_ses-{session}_{network}_unthresholded_fc.nii.gz'.format(
        subject = args.subject, 
        session = args.session, 
        network = args.functional_network))

#apply threshold and save

#Generate correlation nifti
# network_to_voxel_correlations_img = brain_masker.inverse_transform(
#     network_to_voxel_correlations.T)


#Plot first node of network
display = plotting.plot_stat_map(image.index_img(network_to_voxel_correlations_corrected_img, 0),
                                      threshold= args.connectivity_threshold,
                                      cut_coords=[-16,0,16,30,44,58],                                     
                                      display_mode='z',
                                      vmax = 1,
                                      cmap = 'cold_hot',
                                      axes = ax[1],
                                 title="Network-to-voxel correlation for {ntwk} for {subject} session {session}".format(subject=args.subject, session=args.session, ntwk=args.functional_network),
                                 output_file = './results/{subject}_ses-{session}_{network}.png'.format(subject = args.subject, session = args.session, network = args.functional_network))

#Add overlays for additional nodes if network has >1 node
# for i in range (1, network_time_series.shape[1]):
#     display.add_overlay(image.index_img(network_to_voxel_correlations_corrected_img, i),
#                     threshold=args.fc_thresh, cmap = 'cold_hot' )
# fig.show()
