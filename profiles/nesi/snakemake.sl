#!/usr/bin/env bash
#SBATCH --job-name=fmri_workflow
#SBATCH --time=02-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=1GB
#SBATCH --output=logs/nesi/%j-%x.out
#SBATCH --error=logs/nesi/%j-%x.out
#SBATCH --dependency=singleton

# exit on errors, undefined variables and errors in pipes
set -euo pipefail

# load environment modules
module purge
module load Miniconda3/22.11.1-1 Singularity/3.11.3 snakemake/7.30.1-gimkl-2022a-Python-3.11.3

# ensure user's local Python packages are not overriding Python module packages
export PYTHONNOUSERSITE=1

# parent folder for cache directories
NOBACKUPDIR="/nesi/nobackup/$SLURM_JOB_ACCOUNT/$USER"

# configure conda cache directory
conda config --add pkgs_dirs "$NOBACKUPDIR/conda_pkgs"

# ensure conda channel priority is strict (otherwise environment may no be built)
conda config --set channel_priority strict

# deactivate any conda environment already activate (e.g. base environment)
source $(conda info --base)/etc/profile.d/conda.sh
conda deactivate

# configure singularity build and cache directories
export SINGULARITY_CACHEDIR="$NOBACKUPDIR/singularity_cachedir"
export SINGULARITY_TMPDIR="$NOBACKUPDIR/singularity_tmpdir"
mkdir -p "$SINGULARITY_CACHEDIR" "$SINGULARITY_TMPDIR"
setfacl -b "$SINGULARITY_TMPDIR"  # avoid singularity issues due to ACLs set on this folder

# run snakemake using the NeSI profile
snakemake --workflow-profile profiles/nesi --config account="$SLURM_JOB_ACCOUNT" $@
