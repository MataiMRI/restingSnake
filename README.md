# FMRI workflow


## Installation (NeSI)

First, make sure to be logged on Mahuika.

Then, in your project folder, clone this repository:

```
git clone https://github.com/jpmcgeown/fmri_workflow.git
```


## Usage (NeSI)

Make sure to be in the folder of the repository:

```
cd PROJECT_FOLDER/fmri_workflow
```

where `PROJECT_FOLDER` is your project folder.

There, edit the `config.yml` file to set your input dataset and result folder paths.

Load the necessary environment modules:

```
module purge
module load snakemake/7.6.2-gimkl-2020a-Python-3.9.9 Miniconda3/4.12.0 Singularity/3.10.0
export PYTHONNOUSERSITE=1
```

Then run the workflow using the `nesi` profile, first in dry-mode:

```
snakemake --profile nesi -n
```

Finally, run the workflow:

```
snakemake --profile nesi
```


## TODO

- add a note about singularity cache and build directories (for maintainer only?)

```
export SINGULARITY_CACHEDIR=/nesi/nobackup/<project_code>/singularity_cachedir
export SINGULARITY_TMPDIR=/nesi/nobackup/<project_code>/singularity_tmpdir
setfacl -b "$SINGULARITY_TMPDIR"  # avoid Singularity issues due to ACLs set on this folder
```

- add a note about conda package cache (for maintainer only?)

```
conda config --add pkgs_dirs /nesi/nobackup/<project_code>/$USER/conda_pkgs
```

- integrate snakemake singularity cache in the configuration? same for conda environment?
