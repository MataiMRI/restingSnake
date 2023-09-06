# restingSnake fMRI preprocessing workflow

This repository provides a Snakemake workflow to organise, preprocess and perform first level analysis on resting-state (taskless) functional MRI datasets.

- `HeuDIConv`
- `BIDS`
- `MRIQC`
- `freesurfer`
- `fMRIPrep`
- `nilearn`

## Table of contents
- [Installation](#install)
- [Available workflow](#available)
- [Useful Snakemake options](#snake_options)
- [Setting up restingSnake for the first time](#setup)
- [Configuring HeuDIConv](#heudiconv)
- [Image Quality Control](#image_qc)
- [Atlas and network options](#atlas)
- [Longitudinal preprocessing](#long_link)
- [Referencing](#reference)
- [Maintenance](#maintain)




## Installation
<a id="install"></a>

*If you are using the [NeSI](https://www.nesi.org.nz) platform, please follow the [NeSI related documentation](NESI.md).*

To run this workflow on your workstation, you need to install the following softwares:

- `mamba`, a fast cross-platform package manager (see [installation instructions](https://mamba.readthedocs.io/en/latest/installation.htm))
- `apptainer`, a container system (see [installation instructions](https://apptainer.org/docs/admin/main/installation.html))
- `snakemake`, the workflow management system (see [installation instructions](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html))
- `git`, the distributed version control system (see [download page](https://git-scm.com/downloads))

**Note: TO-DO RECOMMEND CREATING A VIRTUAL MAMBA ENVIRONMENT FOR SNAKEMAKE**

Also make sure to get a [Freesurfer license](https://surfer.nmr.mgh.harvard.edu/fswiki/License).

Clone this repository using:

```
git clone https://github.com/jpmcgeown/fmri_workflow.git
```

Then edit the configuration file `config/config.yml`, setting the following entries:

- the prefix `prefix` for your input files,
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
<a id="available"></a>

The provided workflow is split in 2 steps:

- a *quality control* part, transforming the input into BIDS format and running [MRIQC](https://mriqc.readthedocs.io) to provide QC overview of the data,
- a *preprocessing* part, running [fMRIPrep](https://fmriprep.org) and the [first level analysis script](workflow/scripts/first_level.py) for datasets that passed the quality control.


### Quality control

The first time you run snakemake, only the *quality control* step will be run.

MRIQC reports are available under `bids/derivatives/mriqc` in the results folder.

At the end, a `qc_status.csv` file is generated in the results folder. Learn more about the `qc_status.csv` [here](#qc_link).

If you already have a `qc_status.csv` file but do not want to run the *preprocessing* step, you can force snakemake to only consider the quality control step using:

```
snakemake --until quality_control_all
```


### Preprocessing

Once at least one subject session has passed quality control, re-running `snakemake` will trigger the additional *preprocessing* step.

This step generates in the results folder:

- fMRIPrep reports under `bids/derivatives/fmriprep`,
- first level analysis results under `first_level_results`.

`restingSnake` is built to allow the user to select cross-sectional or longitudinal preprocessing of anatomical and functional images. Learn more about longitudinal preprocessing [here](#long_link).


## Useful Snakemake options
<a id="snake_options"></a>
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


# Setting up restingSnake to run on your data for the first time
<a id="setup"></a>
## Formats

The workflow assumes that input scan data are:

- folders or .zip files (you can mix both),
- stored in the `datadir` folder configured [`config/config.yml`](config/config.yml),
- they are named using the convention `<prefix>_<cohort>_<subject>_<session>`, where

  - `<prefix>` is set in [`config/config.yml`](config/config.yml),
  - `<session>` can be omitted, but will then be considered as `a`.

Within a input folder (or .zip file), only the parent folder of DICOM files will be kept when tidying the data.
Any other level of nesting will be ignored.

## Configure local profile
An advantage of `snakemake` is usability on both local machines and HPC platforms. Profiles allow easy implementation across different platforms/machines. You can configure the RAM and CPUs available on your local machine in `profiles/local/config.yml` so `snakemake` can schedule jobs based on available resources.
```
resources:
    - mem_mb=<LOCAL_RAM>
    - cpus=<LOCAL_CORES>
```
You also need to provide a `--bind` path in the `singularity-args` entry within `profiles/local/config.yml`. It is easiest to bind to the parent folder of `datadir` configured in `config/config.yml`. If `datadir` were `/PATH/TO/MY/DATA/DICOM` then you would configure as below:

```
singularity-args: " --cleanenv --bind </PATH/TO/MY/DATA>"
```
You can learn more about `snakemake` profiles and command line options [`here`](https://snakemake.readthedocs.io/en/stable/executing/cli.html).

## Pull containers and tidy DICOMS
Once you have set up [`config/config.yml`](config/config.yml) and [`profiles/local/config.yml`](profiles/local/config.yml) you can try a dry-run of the workflow.

Before running restingSnake on your machine **always** remember to open a terminal from the directory where this `README.md` is located and activate your `snakemake` environment using the following command:
```
mamba activate snakemake
```
Then enter the command below to tidy up your DICOM files and pull the required containers using [`apptainer`](https://apptainer.org/):
```
snakemake -c 2 --profile profiles/local/ --until quality_control_tidy_dicoms
```
This may take a while to complete while `restingSnake` installs `HeuDIConv` and `MRIQC` containers. Once this step is finished you are ready to configure `HeuDIConv. `

## Configuring HeuDIConv
<a id="heudiconv"></a>
This workflow uses [HeuDIConv](https://heudiconv.readthedocs.io/en/latest/)  (Heuristic DICOM Converter) to convert folders of dicom images to nifti images with [BIDS](https://bids-specification.readthedocs.io/en/stable/index.html) compliant data structure. For `HeuDIConv` to perform this function the user must manually provide sequence information before processing.
To do this you will have to use `HeuDIConv` to generate a `dicominfo.tsv` file containing the sequence information needed to configure [`config/heuristic.py`](config/heuristic.py).


We can generate `dicominfo.tsv` with the following command:
```
apptainer run --bind <RESULTSDIR>:/mnt \
<SNAKEMAKEDIR>/.snakemake/singularity/<CONTAINER>.simg \
-d /mnt/tidy/sub_{subject}/ses_{session}/*/* \
-o /mnt/bids \
-f convertall \
-s <SUBJECT> \
-ss <SESSION> \
-c none \
--overwrite
```
 Where:

 - `<RESULTSDIR>` is the same filepath as the `resultsdir` folder configured in `config/config.yml`,
 - `<SNAKEMAKEDIR>` is where this README.md is located,
 - `<CONTAINER>`is the name of your `HeuDIConv` image built by `snakemake`,
 - `<SUBJECT>` and `<SESSION>` is an example folder of scans located in `<RESULTSDIR>/tidy` that will be summarized in `dicominfo.tsv`.


 You can find `<CONTAINER>` by listing all the containers `snakemake` has installed so far:
 ```
 ls .snakemake/singularity
 ```
You should see two .simg containers, but they may have names that are not human readable. To find out which one is `HeuDIConv` run this command and inspect the print out:
```
apptainer run .snakemake/singularity/<CONTAINER>.simg
```

Now run the full `apptainer` `HeuDIConv` command to generate `dicominfo.tsv`. If this runs without error you can now configure [`config/heuristic.py`](config/heuristic.py). This process is clearly explained in steps 2+3 in this [HeuDIConv Walkthrough](https://reproducibility.stanford.edu/bids-tutorial-series-part-2a/). Another useful reference is this [video](https://youtu.be/O1kZAuR7E00).

**Note:** You should only have to populate [`config/heuristic.py`](config/heuristic.py) **once** if your sequence list/info does not change over the course of your project. Once [`config/heuristic.py`](config/heuristic.py) is properly configured`restingSnake` will handle all `dcm2niix` and `BIDS` conversions automatically. **Make sure to delete `dicominfo.tsv` once `config/heuristic.py` is complete or you may encounter issues.**

Now run the *quality control* part of `restingSnake` for the first time:
```
snakemake -c all --profile profiles/local --until quality_control_all
```

# Image quality control
<a id="image_qc"></a>
The ensure data quality the user is expected to perform manual image quality control after `restingSnake` completes the `MRIQC` and `fMRIPrep` rules, respectively.

## MRIQC
<a id="qc_link"></a>
MRIQC reports are available under `bids/derivatives/mriqc` in the results folder.

At the end, a `qc_status.csv` file is generated in the results folder:

- each line is a different subject session
- by default no session passes the QC, columns `func_qc` and `anat_qc` are set to `False`,
- you need to perform manual quality control and then edit these fields and set **both** to `True` to allow the preprocessing step on a session,
- In some cases with multi-session data an anatomical image may fail QC and it may be appropriate to use the anatomical image from another session for preprocessing. You *can* specify another session as the anatomical template, setting it in the `anat_template` field.

**Important note:** Never edit the `qc_status.csv` file *while* a workflow is running, as the workflow edits it too.

The next time `restingSnake` is run any sessions where `func_qc` and `anat_qc` are set to `True`  in `qc_status.csv` will be preprocessed.

## fMRIPrep
The only `restingSnake` rule relying on the output of `preprocessing_fmriprep` is `preprocessing_first_level`. The first level analysis is not computationally intensive so this rule runs regardless of `fMRIPrep` QC status. The user is expected to perform and record QC for the `fMRIPrep` reports under `bids/derivatives/fmriprep` before using first level results in further group analysis. Integration of this functionality within the `restingSnake` workflow may be implemented in the future.

# Atlases and networks
<a id="atlas"></a>

# Longitudinal processing
<a id="long_link"></a>
If you set `use_longitudinal: True` in your configuration file to run a longitudinal analysis, creating a longitudinal template using freesurfer.

# Referencing
<a id="reference"></a>

# Maintenance
<a id="maintain"></a>

The conda environment file [workflow/envs/mri.yaml](workflow/envs/mri.yaml) with pinned versions is generated from a version without versions [workflow/envs/mri_base.yaml](workflow/envs/mri_base.yaml).

You can update it using:

```
conda env create -f workflow/envs/mri_base.yaml -p ./mri_env
conda env export -p ./mri_env --no-builds | grep -v '^prefix:' > workflow/envs/mri.yaml
conda env remove -p ./mri_env
```
