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
module load Miniconda3/4.12.0 Singularity/3.10.0 snakemake/7.6.2-gimkl-2020a-Python-3.9.9
module unload XALT
export PYTHONNOUSERSITE=1
```

Then run the workflow using the `nesi` profile, first in dry-mode:

```
snakemake --profile nesi -n
```

View steps within workflow using rulegraph:
```
snakemake --forceall --rulegraph | dot -Tpdf > rulegraph.pdf
```

Finally, run the workflow:

```
snakemake --profile nesi
```


## Formats

The workflow assumes that input scan data are:

- folders or .zip files (you can mix both),
- stored in the `datadir` folder configured in  in [`config.yml`](config.yml)
- they are name using the convention `<ethics_prefix>_<subject>_<session>`, where

  - `<ethics_prefix>` is set in [`config.yml`](config.yml)
  - `<session>` can be omitted, but will then be considered as `a`

Note that the first steps of the workflow will "tidy" the data structure, renaming folders and files.
To save space, it will not copy data but move them.
Therefore, your input folders and zip files **will be removed** as part of this process.
We strongly advise you to **keep a copy of our data** elsewhere.


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

- add a note about the user having to run HeudiConv separately to determine populate heuristic.py prior to any run on NeSI

- add a note about keep_this_folder file in dicom directory
Create dicom folder in high memory storage.
Then create a file to prevent Snakemake from deleting this folder:
```
mkdir NOBACKUP_FOLDER/dicom
touch NOBACKUP_FOLDER/dicom/keep_this_folder
```
