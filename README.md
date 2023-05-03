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
module load Miniconda3/4.12.0 Singularity/3.10.0 snakemake/7.19.1-gimkl-2022a-Python-3.10.5
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


### Useful Snakemake options

View steps within workflow using rulegraph:
```
snakemake --forceall --rulegraph | dot -Tpdf > rulegraph.pdf
```

Prevent Snakemake from stopping as soon as one job fails, but finish independent jobs:

```
snakemake --keep-going
```

Keep incomplete files (useful for debugging) from fail jobs, instead of wiping them:

```
snakemake --keep-incomplete
```

If you kept some incomplete files, Snakemake will refuse to run unless you tell it what to do with the identified files.
The easiest (and safest) option it to tell it to re-run the jobs, i.e. remove the incomplete files and run the jobs to create them:

```
snakemake --rerun-incomplete
```

Run the pipeline until a certain file or rule, e.g. the `freesurfer` rule:

```
snakemake --until freesurfer
```

All these options can be combined and used with a profile, for example:

```
snakemake --profile nesi --keep-going --keep-incomplete --until freesurfer
```


### Protect input DICOM folder

Make sure to create a dummy file in your input DICOM folder, `datadir` in the configuration file [config.yml](config.yml):

```
mkdir DATADIR
touch DATADIR/keep_this_folder
```

where `DATADIR` is your input DICOM folder.

Without the dummy file `keep_this_folder`, snakemake will remove the folder once every input DICOM in it has been processed.


### Accessing JupyterLab via SSH (NeSI)

JupyterLab is a convenient way to explore the results of the workflow (e.g. fmriprep html reports).

We recommend to use it via an SSH tunnel to thw Mahuika login node.
If you are using a terminal, add the `-L` option to your ssh command, for example:

```
ssh mahuika -L PORT:localhost:PORT
```

where `PORT` is an arbitrary number between 1024 and 49151.

Then, on the login node, load the JupyterLab module and start a JupyterLab session as follows:

```
cd RESULTS_FOLDER
module purge && module load JupyterLab
jupyter-lab --port PORT --no-browser
```

where

- `RESULTS_FOLDER` is the folder (on NeSI) where the results you want to inspect are,
- `PORT` is the same number that you choose for your SSH tunnel.

JupyterLab will print on the command line a url looking like:

```
http://localhost:PORT/lab?token=XXXXXXXXXXXXXXXXX
```

Copy and paste it (including the long token string) in your web-browser of choice to access the JupyterLab interface.

*Note: Closing your SSH session or pressing CTRL-C twice in the terminal of your SSH session will terminate the JupyterLab session.*


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

- how to unset `conda init` or avoid it to be an issue?

- add a note about the user having to run HeudiConv separately to determine populate heuristic.py prior to any run on NeSI

- add a note about interacting with containers for learning/changing settings
# inspect image using singularity exec docker://bids/freesurfer recon-all --help

- how to generate a minimal reproducible conda environment

```
module purge
module load Miniconda3/4.12.0
export PYTHONNOUSERSITE=1
conda env create -f envs/mri_base.yaml -p ./mri_env
conda env export -p ./mri_env --no-builds | grep -v '^prefix:' > envs/mri.yaml
conda env remove -p ./mri_env
```
