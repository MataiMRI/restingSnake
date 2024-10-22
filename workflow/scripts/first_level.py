#!/usr/bin/env python3

"""
Created on Fri Jan 21 14:29:23 2022

@author: jpmcgeown
"""

import argparse
import logging
from collections import defaultdict

import numpy as np
import pandas as pd
import nibabel as nib
import matplotlib.pyplot as plt
from scipy import stats
from mne.stats import fdr_correction
from nilearn import plotting
from nilearn import image
from nilearn import datasets
from nilearn.maskers import NiftiMapsMasker, NiftiMasker


def make_parser():
    """create the parser for a command line interface tool"""
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="TODO some description, mention selected resting-state network",
    )

    parser.add_argument("mask", help="subject mask nifti file output from fmriprep")
    parser.add_argument(
        "func", help="subject rsfMRI bold nifti file output from fmriprep"
    )
    parser.add_argument(
        "confounds", help="subject confound timeseries file output from fmriprep"
    )
    parser.add_argument(
        "nifti_output", help="first Level analysis output as a .nii file"
    )
    parser.add_argument("plotting_output", help="output figure as a .png file")
    parser.add_argument(
        "-a_img", help="specify Atlas .nii image file", dest="atlas_image"
    )
    parser.add_argument(
        "-a_lab",
        help="atlas .csv file containing ROI coordinates for resting-state networks",
        dest="atlas_labels",
    )
    parser.add_argument(
        "-ntwk",
        help="resting-state fMRI network wildcard",
        dest="functional_network",
    )
    parser.add_argument(
        "-tr", help="scan repetition time", type=float, dest="repetition_time"
    )
    parser.add_argument(
        "-rg",
        help="list of regressors from confounds.tsv to perform signal cleaning",
        dest="regressors",
        nargs="+",
    )
    parser.add_argument(
        "-hp",
        help="high pass boundary of band pass filter",
        dest="highpass",
        type=float,
        default=0.01,
    )
    parser.add_argument(
        "-lp",
        help="low pass boundary of band pass filter",
        dest="lowpass",
        type=float,
        default=0.1,
    )
    parser.add_argument(
        "-fwhm",
        help="full width half maximum smoothing kernel",
        type=int,
        default=6,
    )
    parser.add_argument(
        "-fish",
        help="Fisher-z transform to achieve normal distribution",
        dest="fisher_transform",
        action="store_true"
    )
    parser.add_argument(
        "-fdr",
        help="False Detection Rate threshold to correct for multiple comparisons",
        dest="fdr_threshold",
        type=float
    )
    parser.add_argument(
        "-fc",
        help="functional connectivity threshold",
        dest="connectivity_threshold",
        type=float,
        default=0.25,
    )
    parser.add_argument(
        "-d",
        "--debug",
        help="logging level for developers to debug issues with code",
        action="store_const",
        dest="loglevel",
        const=logging.DEBUG,
        default=logging.WARNING,
    )
    parser.add_argument(
        "-v",
        "--verbose",
        help="logging level to display all steps running in code",
        action="store_const",
        dest="loglevel",
        const=logging.INFO,
        default=logging.WARNING,
    )
    return parser


def create_mask(
    network_time_series, func, *, fwhm, lowpass, highpass, repetition_time, verbose
):
    logger = logging.getLogger(__name__)

    brain_masker = NiftiMasker(
        smoothing_fwhm=fwhm,
        detrend=True,
        standardize=True,
        low_pass=lowpass,
        high_pass=highpass,
        t_r=repetition_time,
        verbose=verbose,
        mask_img=mask,
    )

    brain_time_series = brain_masker.fit_transform(func, confounds=confounds_matrix)
    logger.info(
        "Converted whole brain data to timeseries with shape: "
        f"{brain_time_series.shape}"
    )

    # Correlate network nodes of interest against brain mask time series
    logger.info("Performing network to voxel correlation analysis")
    network_to_voxel_correlations = (
        np.dot(brain_time_series.T, network_time_series) / network_time_series.shape[0]
    )

    logger.info(
        "Network-to-voxel correlation shape: (%s, %s)"
        % network_to_voxel_correlations.shape
    )
    logger.info(
        "Raw Network-to-voxel correlation: min = %.3f; max = %.3f"
        % (network_to_voxel_correlations.min(), network_to_voxel_correlations.max())
    )

    raw_plotting_img = brain_masker.inverse_transform(
        network_to_voxel_correlations.T
    )

    if args.fisher_transform:
        logger.info("Returning Fisher-z transformed image")

        network_to_voxel_correlations_fisher_z = np.arctanh(network_to_voxel_correlations)
        logger.info(
            "Seed-to-voxel correlation Fisher-z transformed: min = %.3f; max = %.3f"
            % (network_to_voxel_correlations_fisher_z.min(), network_to_voxel_correlations_fisher_z.max())
        )

        network_to_voxel_correlations_img = brain_masker.inverse_transform(
            network_to_voxel_correlations_fisher_z.T
        )

    if args.fdr_threshold is not None and not args.fisher_transform:
        logger.info("Performing False Discovery Rate correction")

        # calculate t statistics from network_to_voxel_correlations
        t_vals = (
            network_to_voxel_correlations * np.sqrt((epi_img.shape[3] - 2))
        ) / np.sqrt((1 - network_to_voxel_correlations**2))

        # convert t statistics to p values
        p_vals = stats.t.sf(np.abs(t_vals), df=(epi_img.shape[3] - 2)) * 2

        # implement mne library fdr_correction
        reject_fdr, pval_fdr = fdr_correction(
            p_vals, alpha=args.fdr_threshold, method="indep"
        )
        reject_fdr = reject_fdr * 1  # convert boolean series to binary

        network_to_voxel_correlations_corrected = network_to_voxel_correlations * reject_fdr
        # network_to_voxel_correlations_corrected = p_vals * reject_fdr
        logger.info(
            "FDR corrected network-to-voxel correlation: min = %.3f; max = %.3f"
            % (network_to_voxel_correlations_corrected.min(), network_to_voxel_correlations_corrected.max())
        )

        network_to_voxel_correlations_img = brain_masker.inverse_transform(
            network_to_voxel_correlations_corrected.T
        )

    if args.fdr_threshold is None and not args.fisher_transform:
        logger.info("Returning uncorrected raw correlation values")
        network_to_voxel_correlations_img = brain_masker.inverse_transform(
            network_to_voxel_correlations.T
        )

    return network_to_voxel_correlations_img, raw_plotting_img


if __name__ == "__main__":
    # Parse command line inputs
    parser = make_parser()
    args = parser.parse_args()

    # Create logger
    logging.basicConfig(
        format="%(asctime)s :: %(name)s :: %(levelname)s :: %(message)s",
        level=args.loglevel,
    )
    logger = logging.getLogger(__name__)

    # Load required files
    logger.info(f"Loading mask image (3D): {args.mask}")
    mask = nib.load(args.mask)

    logger.info(f"Loading resting-state fMRI image (4D): {args.func}")
    logger.info(f"This image was collected with a TR of: {args.repetition_time}")
    epi_img = nib.load(args.func)

    logger.info(f"Loading timeseries for confounding variables from: {args.confounds}")
    confounds = pd.read_csv(args.confounds, sep="\t")
    confounds = confounds[args.regressors]
    confounds_matrix = confounds.values
    logger.info(f"Confound regressors that will be cleaned from signal:\n\n{confounds}")

    # Load atlas to provide resting-state networks available for analysis
    if args.atlas_image is None or args.atlas_labels is None:
        logger.info("Loading regions-of-interest from default MSDL atlas")
        atlas = datasets.fetch_atlas_msdl()
        atlas_filename = atlas["maps"]
        networks = atlas["networks"]

    else:
        logger.info("Loading regions-of-interest from atlas provided")
        atlas_filename = args.atlas_image
        roi_labels = pd.read_csv(args.atlas_labels)
        networks = roi_labels["net name"]

    # Generate blank dictionary of n unique networks provided in atlas
    networks = [n.strip() for n in networks]
    keys = set(networks)
    keys_txt = "\n".join(keys)
    logger.info(f"Functional networks available in atlas:\n{keys_txt}")

    # Populate dictionary with indexes of anatomical seeds that correspond to
    # functional networks
    msdl_networks = defaultdict(list)
    for i, network in enumerate(networks):
        msdl_networks[network].append(i)

    # logger.info("\nDetails about seed(s) within selected network")
    # for coord in msdl_networks[args.functional_network]:
    #    logger.info('\n', roi_labels.iloc[coord])
    functional_network = args.functional_network
    if functional_network != "Cing-Ins":
        functional_network = functional_network.replace("-", " ")
    logger.info(f"Selected network: {functional_network}")
    # Define single network
    network_nodes = image.index_img(
        atlas_filename, msdl_networks[functional_network]
    )
    logger.info(f"Shape of network nodes from atlas image {network_nodes.shape}")

    logger.info(
        "BOLD signal will be standardized, detrended, and cleaned based with a "
        f"Bandpass filter set to {args.lowpass}-{args.highpass} Hz and a {args.fwhm} "
        "mm full-width-half-maximum smoothing kernel"
    )

    # Create mask using user-specified network nodes from atlas
    logger.info(
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
    network_time_series = atlas_masker.fit_transform(
        args.func, confounds=confounds_matrix
    )
    logger.info(
        "Converting functional network data to timeseries with shape: "
        f"{network_time_series.shape}"
    )

    # Create brain-wide mask
    logger.info("Generating mask for whole brain")

    nifti_verbose = 0
    if args.loglevel <= logging.DEBUG:
        nifti_verbose = 2
    elif args.loglevel <= logging.INFO:
        nifti_verbose = 1

    network_to_voxel_correlations_img, raw_plotting_img = create_mask(
        network_time_series,
        args.func,
        fwhm=args.fwhm,
        lowpass=args.lowpass,
        highpass=args.highpass,
        repetition_time=args.repetition_time,
        verbose=nifti_verbose,
    )

    logger.info(f"Saving UNTHRESHOLDED image to {args.nifti_output}")
    nib.save(network_to_voxel_correlations_img, args.nifti_output)

    # Plot probabilistic map from atlas and subject bold signal together
    logger.info(
        f"Saving plot of raw {functional_network} connectivity THRESHOLDED at "
        f"{args.connectivity_threshold} to {args.plotting_output}"
    )

    fig, axes = plt.subplots(2, 1, figsize=(10, 7.2))

    plotting.plot_prob_atlas(
        network_nodes,
        cut_coords=6,
        display_mode="z",
        title=f"{functional_network} nodes according to atlas labels",
        axes=axes[0],
    )

    mean_plotting_img = image.mean_img(raw_plotting_img)
    
    plotting.plot_stat_map(
        mean_plotting_img,
        threshold=args.connectivity_threshold,
        cut_coords=[-16, 0, 16, 30, 44, 58],
        title=(
            f"Raw {functional_network} functional connectivity thresholded at "
            f"r = {args.connectivity_threshold}"
        ),
        display_mode="z",
        vmax=1,
        cmap="cold_hot",
        axes=axes[1],
    )

    fig.savefig(args.plotting_output, bbox_inches="tight")
