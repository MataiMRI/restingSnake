#  NeSI

This documentation details how to run the workflow on [NeSI](https://www.nesi.org.nz/) (New Zealand eScience Infrastructure) HPC platform.


## Getting started

First, make sure to be logged on Mahuika, either via SSH or using [Jupyter on NeSI](https//jupyter.nesi.org.nz).

In a terminal, clone this repository within your project folder:

```
cd PROJECT_FOLDER
git clone https://github.com/jpmcgeown/fmri_workflow.git
```

where `PROJECT_FOLDER` is your project folder (.e.g `/nesi/project/uoa03264/$USER`).

*Note: you only need to do the cloning step once.*

Then change directory to be in the folder of the repository:

```
cd fmri_workflow
```

and edit the `config.yml` file to set your input dataset and result folder paths, for example using `nano` editor:

```
nano config.yml
```

or the JupyterLab editor if you logged in via Jupyter.

Then, instead of using `snakemake` command directly, we will use the `nesi/snakemake.sl` script, which takes care of setting up the environment to run Snakemake on NeSI.

First, always do a dry-run and see which files will be (re-)created using:

```
srun nesi/snakemake.sl -n
```

If everything looks good, it is then time to submit the workflow as a Slurm batch job using the `sbatch` command:

```
sbatch nesi/snakemake.sl
```

This puts the workflow in the Slurm queue, where is should be scheduled to start as soon as resources are available.
This command print a number, the **job ID**, that will be useful to keep track of the execution of the workflow.
Note that you don't need to stay logged in once the job as been submitted.

TODO note on singleton

TODO note on timelimit

TODO note on project number


## Job management

To check the status of your Slurm job, use:

- either the **Job ID** directly

  ```
  squeue -j JOBID
  ```

- or filtering your job list to find the job by its name

  ```
  squeue --me -n fmri_workflow
  ```

If the job does not appear in the list, it means that it has completed.

Use the `sacct` command to check if this has been successful or if it ran into issues:

```
sacct -j JOBID
```

If you need to cancel the workflow, use the `scancel` command as follows:

```
scancel -j JOBID
```


## Workflow monitoring

To have a look at the output printed by snakemake, TODO


## Accessing JupyterLab via SSH

JupyterLab is a convenient way to explore the results of the workflow (e.g. fmriprep html reports).

We recommend to use it via an SSH tunnel to the Mahuika login node.
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


## TODO

- document `nesi/snakemake.sl` changing `~/.condarc` (in particular channel priority)

- how to unset `conda init` or avoid it to be an issue?

- how to generate a minimal reproducible conda environment (maintainer doc?)

```
module purge
module load Miniconda3/4.12.0
export PYTHONNOUSERSITE=1
conda env create -f envs/mri_base.yaml -p ./mri_env
conda env export -p ./mri_env --no-builds | grep -v '^prefix:' > envs/mri.yaml
conda env remove -p ./mri_env
```
