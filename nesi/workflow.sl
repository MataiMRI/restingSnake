#!/usr/bin/env bash
#SBATCH --account=uoo03699
#SBATCH --time=02-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=1GB
#SBATCH --output nesi/logs/%j-%x.out
#SBATCH --error nesi/logs/%j-%x.out
#SBATCH --dependency=snakemake_workflow

# exit on errors, undefined variables and errors in pipes
set -euo pipefail

# load environment modules
module purge
module load Miniconda3/4.12.0 Singularity/3.10.0 snakemake/7.19.1-gimkl-2022a-Python-3.10.5
export PYTHONNOUSERSITE=1

# parent folder for cache directories
NOBACKUPDIR="/nesi/nobackup/$SLURM_JOB_ACCOUNT/$USER"

# configure conda cache directory
conda config --add pkgs_dirs "$NOBACKUPDIR/conda_pkgs"

# ensure conda channel priority is strict (otherwise environment may no be built)
conda config --set channel_priority strict

# deactivate any conda environment already activate (e.g. base environment)
conda deactivate

# configure singularity build anc cache directories
export SINGULARITY_CACHEDIR="$NOBACKUPDIR/singularity_cachedir"
export SINGULARITY_TMPDIR="$NOBACKUPDIR/singularity_tmpdir"
mkdir -p "$SINGULARITY_CACHEDIR" "$SINGULARITY_TMPDIR"
setfacl -b "$SINGULARITY_TMPDIR"  # avoid Singularity issues due to ACLs set on this folder

# run snakemake using the NeSI profile
snakemake --profile nesi --config account="$SLURM_JOB_ACCOUNT"
