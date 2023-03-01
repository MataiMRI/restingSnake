#!/usr/bin/env bash
#SBATCH --account=uoa03264
#SBATCH --time=00-09:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=4GB
#SBATCH --output logs/%j-%x.out
#SBATCH --error logs/%j-%x.out

# exit on errors, undefined variables and errors in pipes
set -euo pipefail

# load environment modules (same as when running snakemake, in case this affects job)
module purge
module load Miniconda3/4.12.0 Singularity/3.10.0 snakemake/7.6.2-gimkl-2020a-Python-3.9.9
module unload XALT
export PYTHONNOUSERSITE=1

# run container to execute longitudinal study template step
singularity exec \
    --bind $HOME,/nesi/project,/nesi/nobackup,/scale_wlg_persistent,/scale_wlg_nobackup \
    docker://bids/freesurfer:v6.0.1-6.1 \
    bash -c 'export FS_LICENSE=$(realpath ./license.txt) && recon-all -base sub-rugby1.template -tp sub-rugby1_ses-a -tp sub-rugby1_ses-b -sd /nesi/nobackup/uoa03264/fMRIpipeline_data/processed_test_max3/bids/derivatives/freesurfer -all -qcache -3T -openmp 8'
