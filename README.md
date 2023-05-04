# FMRI workflow


## Getting started

*If you are using the [NeSI](https://www.nesi.org.nz) platform, please follow the [NeSI related documentation](NESI.md).*

TODO explain local machine deployment


## Useful Snakemake options

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

- add a note about the user having to run HeudiConv separately to determine populate heuristic.py prior to any run on NeSI

- add a note about interacting with containers for learning/changing settings

```
singularity exec docker://bids/freesurfer recon-all --help
```
