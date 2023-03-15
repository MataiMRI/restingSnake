#!/usr/bin/env python3

"""
Created on Fri Jan 21 14:29:23 2022

@author: jpmcgeown
"""

import argparse
import logging

import numpy as np
import pandas as pd
import nibabel as nib
import matplotlib.pyplot as plt
from scipy import stats
from mne.stats import fdr_correction
from nilearn import plotting
from nilearn import image
from nilearn.maskers import NiftiMapsMasker, NiftiMasker

# from nilearn import datasets

parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument("mask", help="Subject mask nifti file output from fmriprep")
parser.add_argument("func", help="Subject rsfMRI bold nifti file output from fmriprep")
parser.add_argument(
    "confounds", help="Subject confound timeseries file output from fmriprep"
)
parser.add_argument(
    "nifti_output",
    help=(
        "Name and location of .nii output of First Level analysis for selected "
        "resting-state network"
    ),
)
parser.add_argument(
    "plotting_output",
    help="Name and location of .png output for selected resting-state network",
)
parser.add_argument("-a_img", help="Specify Atlas .nii image file", dest="atlas_image")
parser.add_argument(
    "-a_lab",
    help="Specify Atlas .csv file containing ROI coordinates for resting-state networks",
    dest="atlas_labels",
)
parser.add_argument(
    "-ntwk",
    help="Specify resting-state fMRI network wildcard",
    dest="functional_network",
)
parser.add_argument(
    "-tr",
    help="Specify scan repetition time from config file",
    type=float,
    dest="repetition_time",
)
parser.add_argument(
    "-rg",
    help="Specify list of regressors from confounds.tsv to perform signal cleaning",
    dest="regressors",
    nargs="+",
)
parser.add_argument(
    "-hp",
    help="Specify high pass boundary of band pass filter from config file",
    dest="highpass",
    type=float,
    default=0.01,
)
parser.add_argument(
    "-lp",
    help="Specify low pass boundary of band pass filter from config file",
    dest="lowpass",
    type=float,
    default=0.1,
)
parser.add_argument(
    "-fwhm",
    help="Specify full width half maximum smoothing kernel from config file",
    type=int,
    default=6,
)
parser.add_argument(
    "-fdr",
    help=(
        "Specify False Detection Rate threshold to correct for multiple comparisons "
        "from config file"
    ),
    dest="fdr_threshold",
    type=float,
    default=0.05,
)
parser.add_argument(
    "-fc",
    help="Specify functional connectivity threshold from config file",
    dest="connectivity_threshold",
    type=float,
    default=0.25,
)
parser.add_argument(
    "-d",
    "--debug",
    help="Logging level for developers to debug issues with code",
    action="store_const",
    dest="loglevel",
    const=logging.DEBUG,
    default=logging.WARNING,
)
parser.add_argument(
    "-v",
    "--verbose",
    help="Logging level to display all steps running in code",
    action="store_const",
    dest="loglevel",
    const=logging.INFO,
    default=logging.WARNING,
)

args = parser.parse_args()

# Create logger
logging.basicConfig(
    format="%(asctime)s :: %(name)s :: %(levelname)s :: %(message)s",
    level=args.loglevel,
)
logger = logging.getLogger()

# Load required files
logging.info(f"Loading mask image (3D): {args.mask}")
mask = nib.load(args.mask)

logging.info(f"Loading resting-state fMRI image (4D): {args.func}")
logging.info(f"This image was collected with a TR of: {args.repetition_time}")
epi_img = nib.load(args.func)

logging.info(f"Loading timeseries for confounding variables from: {args.confounds}")
confounds = pd.read_csv(args.confounds, sep="\t")
confounds = confounds[args.regressors]
confounds_matrix = confounds.values
logging.info(f"Confound regressors that will be cleaned from signal:\n\n{confounds}")

# Load atlas to provide resting-state networks available for analysis
logging.info("Loading regions-of-interest from atlas provided")
atlas_filename = args.atlas_image
roi_labels = pd.read_csv(args.atlas_labels)

# Generate blank dictionary of n unique networks provided in atlas
logging.info("Functional networks available in atlas:")
keys = list(set(roi_labels["net_name"]))
for net in keys:
    logging.info(net)

msdl_networks = dict.fromkeys(keys)
for key in msdl_networks.keys():
    msdl_networks[key] = []

# Populate dictionary with indexes of anatomical seeds that correspond to functional networks
for i in range(0, len(roi_labels["net_name"])):
    temp = roi_labels["net_name"][i]
    if temp in msdl_networks.keys():
        msdl_networks[temp].append(i)
    else:
        msdl_networks[temp] = None

logging.info("\nDetails about seed(s) within selected network")
# for coord in msdl_networks[args.functional_network]:
#    logging.info('\n', roi_labels.iloc[coord])

# Define single network and plot probabilistic map from atlas

# figure to plot atlas and subject bold signal together
fig, ax = plt.subplots(nrows=2)

# define nodes
network_nodes = image.index_img(atlas_filename, msdl_networks[args.functional_network])
logging.info(f"Shape of network nodes from atlas image {network_nodes.shape}")

atlas_plot = plotting.plot_prob_atlas(
    network_nodes,
    cut_coords=6,
    display_mode="z",
    title=f"{args.functional_network} nodes according to atlas labels",
    axes=ax[0],
)

nifti_verbose = 0
if args.loglevel <= logging.DEBUG:
    nifti_verbose = 2
elif args.loglevel <= logging.INFO:
    nifti_verbose = 1

logging.info(
    "BOLD signal will be standardized, detrended, and cleaned based with a Bandpass "
    f"filter set to {args.lowpass}-{args.highpass} Hz and a {args.fwhm} mm "
    "full-width-half-maximum smoothing kernel \n"
)

# Create mask using user-specified network nodes from atlas
logging.info(
    "Generating mask for network of interest based on seed coordinates in atlas"
)
atlas_masker = NiftiMapsMasker(
    maps_img=network_nodes,
    smoothing_fwhm=args.fwhm,
    standardize=True,
    detrend=True,
    low_pass=args.lowpass,
    high_pass=args.highpass,
    t_r=args.repetition_time,
    verbose=0,
    mask_img=mask,
)

# time series for network of interest
network_time_series = atlas_masker.fit_transform(args.func, confounds=confounds_matrix)
logging.info(
    "Converting functional network data to timeseries with shape: "
    f"{network_time_series.shape}"
)

# Create brain-wide mask
logging.info("Generating mask for whole brain")
brain_masker = NiftiMasker(
    smoothing_fwhm=args.fwhm,
    detrend=True,
    standardize=True,
    low_pass=args.lowpass,
    high_pass=args.highpass,
    t_r=args.repetition_time,
    verbose=nifti_verbose,
    mask_img=mask,
)

brain_time_series = brain_masker.fit_transform(args.func, confounds=confounds_matrix)
logging.info(
    f"Converting whole brain data to timeseries with shape: {brain_time_series.shape}"
)

# Correlate network nodes of interest against brain mask time series
logging.info("Performing network to voxel correlation analysis")
network_to_voxel_correlations = (
    np.dot(brain_time_series.T, network_time_series) / network_time_series.shape[0]
)

logging.info(
    "Network-to-voxel correlation shape: (%s, %s)" % network_to_voxel_correlations.shape
)
logging.info(
    "Network-to-voxel correlation: min = %.3f; max = %.3f"
    % (network_to_voxel_correlations.min(), network_to_voxel_correlations.max())
)

# calculate t statistics from network_to_voxel_correlations
t_vals = (network_to_voxel_correlations * np.sqrt((epi_img.shape[3] - 2))) / np.sqrt(
    (1 - network_to_voxel_correlations**2)
)

# convert t statistics to p values
p_vals = stats.t.sf(np.abs(t_vals), df=(epi_img.shape[3] - 2)) * 2

logging.info("Performing False Discovery Rate correction")
# implement mne library fdr_correction
reject_fdr, pval_fdr = fdr_correction(p_vals, alpha=args.fdr_threshold, method="indep")
reject_fdr = reject_fdr * 1  # convert boolean series to binary

network_to_voxel_correlations_corrected = network_to_voxel_correlations * reject_fdr
# network_to_voxel_correlations_corrected = p_vals * reject_fdr

network_to_voxel_correlations_corrected_img = brain_masker.inverse_transform(
    network_to_voxel_correlations_corrected.T
)

logging.info(f"Saving UNTHRESHOLDED image to {args.nifti_output}")
nib.save(network_to_voxel_correlations_corrected_img, args.nifti_output)


logging.info(
    f"Saving plot of {args.functional_network} connectivity THRESHOLDED at "
    f"{args.connectivity_threshold} to {args.plotting_output}"
)


display = plotting.plot_stat_map(
    image.index_img(network_to_voxel_correlations_corrected_img, 0),
    threshold=args.connectivity_threshold,
    cut_coords=[-16, 0, 16, 30, 44, 58],
    title=(
        f"{args.functional_network} functional connectivity thresholded at "
        f"{args.connectivity_threshold}"
    ),
    display_mode="z",
    vmax=1,
    cmap="cold_hot",
    axes=ax[1],
    output_file=args.plotting_output,
)

# Add overlays for additional nodes if network has >1 node
# for i in range (1, network_time_series.shape[1]):
#     display.add_overlay(image.index_img(network_to_voxel_correlations_corrected_img, i),
#                     threshold=args.fc_thresh, cmap = 'cold_hot' )
