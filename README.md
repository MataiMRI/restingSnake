# FMRI workflow

This repository provides a Snakemake workflow to preprocess fMRI datasets.


## Installation

*If you are using the [NeSI](https://www.nesi.org.nz) platform, please follow the [NeSI related documentation](NESI.md).*

To run this workflow on your workstation, you need to install the following softwares:

- `mamba`, a fast cross-platform package manager (see [installation instructions](https://mamba.readthedocs.io/en/latest/installation.htm))
- `apptainer`, a container system (see [installation instructions](https://apptainer.org/docs/admin/main/installation.html))
- `snakemake`, the workflow management system (see [installation instructions](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html))
- `git`, the distributed version control system (see [download page](https://git-scm.com/downloads))

Also make sure to get a [Freesurfer license](https://surfer.nmr.mgh.harvard.edu/fswiki/License).

Clone this repository using:

```
git clone https://github.com/jpmcgeown/fmri_workflow.git
```

Then edit the configuration file `config/config.yml`, setting the following entries:

- the ethics prefix `ethics_prefix` for your input files,
- the input data folder `datadir`,
- the results folder `resultsdir`,
- the path to your `heudiconv` heuristic script (`heuristic` entry under `heudiconv` section),
- the path to your Freesurfer license (`license_path` entry under `freesurfer` section)

You may want to edit other entries, in particular:

- for each software, compute resources (time, memory and threads) can be adjusted,
- the first level analysis parameters.

Once this configuration is finished, you can run `snakemake` to start the workflow.

Use a dry-run to check that installation and configuration is working:

```
snakemake -n
```


## Available workflow

The provided workflow is split in 2 steps:

- a *quality control* part, transforming the input into BIDS format and running [MRIQC](https://mriqc.readthedocs.io) to provide QC overview of the data,
- a *preprocessing* part, running [fMRIPrep](https://fmriprep.org) and the [first level analysis script](workflow/scripts/first_level.py) for datasets that passed the quality control.


### Quality control

The first time you run snakemake, only the *quality control* step will be run.

MRIQC reports are available under `bids/derivatives/mriqc` in the results folder.

At the end, a `qc_status.csv` file is generated in the results folder:

- each line is different subject session
- by default no session passes the QC, columns `func_qc` and `anat_qc` are set to `False`,
- you need to edit these fields and set **both** to `True` to allow the preprocessing step on a session,
- you *can* specify another session as the anatomical template, setting it in the `anat_template` field. 

**Important note:** Never edit the `qc_status.csv` file *while* a workflow is running, as the workflow edits it too.

If you have already a `qc_status.csv` file but do not want to run the *preprocessing* step, you can force snakemake to only consider the quality control step using:

```
snakemake --until quality_control_all
```


### Preprocessing

Once at least one subject session has passed quality control, re-running `snakemake` will trigger the additional *preprocessing* step.

This step generates in the results folder:

- fMRIPrep reports under `bids/derivatives/mriqc`,
- first level analysis results under `first_level_results`.

If you set `use_longitudinal: True` in your configuration file to run a longitudinal analysis, creating a longitudinal template using freesurfer.


## Useful Snakemake options

View steps within workflow using rulegraph:

```
snakemake --forceall --rulegraph | dot -Tpdf > rulegraph.pdf
```

Use the [*local* profile](profiles/local/config.yaml), presetting many options to run the workflow locally:

```
snakemake --profile profiles/local
```

Inform `snakemake` of the maximum amount of memory available on the workstation:

```
snakemake --resources mem=48GB
```

Keep incomplete files (useful for debugging) from fail jobs, instead of wiping them:

```
snakemake --keep-incomplete
```

Run the pipeline until a certain file or rule, e.g. the `freesurfer` rule:

```
snakemake --until freesurfer
```

All these options can be combined and used with a profile, for example:

```
snakemake --profile profiles/local --keep-incomplete --until freesurfer
```

Unlock the folder, in case `snakemake` had to be interrupted abruptly previously:

```
snakemake --unlock
```

*Note: This last hint will be mentioned to you by `snakemake` itself.
Use it only when recommended to to so ;-).*


## Formats

The workflow assumes that input scan data are:

- folders or .zip files (you can mix both),
- stored in the `datadir` folder configured [`config/config.yml`](config/config.yml),
- they are named using the convention `<ethics_prefix>_<subject>_<session>`, where

  - `<ethics_prefix>` is set in [`config/config.yml`](config/config.yml),
  - `<session>` can be omitted, but will then be considered as `a`.

Within a input folder (or .zip file), only the parent folder of DICOM files will be kept when tidying the data.
Any other level of nesting will be ignored.


## Maintenance

The conda environment file [workflow/envs/mri.yaml](workflow/envs/mri.yaml) with pinned versions is generated from a version without versions [workflow/envs/mri_base.yaml](workflow/envs/mri_base.yaml).

You can update it using:

```
conda env create -f workflow/envs/mri_base.yaml -p ./mri_env
conda env export -p ./mri_env --no-builds | grep -v '^prefix:' > workflow/envs/mri.yaml
conda env remove -p ./mri_env
```
