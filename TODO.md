# TODO

- remove project specific information
  - remove paths, ethics, etc. in [config/config.yml](config/config.yml)
  - remove freesurfer license [config/license.txt](config/license.txt) and document how to get it
  - remove project specific heudiconv script [config/heuristic.py](config/heuristic.py)
- add a workflow (and instructions) to get vanilla heuristic file for `heudiconv`
- (minor) use `--workflow-profile` instead of `--profile`
  - rename `profiles/local` to `profiles/default` to make it default
  - use `--workflow-profile` in [profiles/nesi/snakemake.sl](profiles/nesi/snakemake.sl),
    but currently [2023/08/03] this crashes with snakemake 7.30.1 on NeSI
- (minor) add minimal version requirements in Snakefile (for recent functionalities)
  ```
  from snakemake.utils import min_version
  min_version("7.30")
  ```
- **heudiconv rule**
  - avoid race condition using `--bids notop` (see [heudiconv doc](https://heudiconv.readthedocs.io/en/latest/usage.html#batch-jobs))
  - generate template files after using `--command populate-templates` (see [heudiconv doc](https://heudiconv.readthedocs.io/en/latest/usage.html#batch-jobs))
  - help generate participants.tsv
- **fmriqc rule**
  - list all outputs, e.g. all file `bids/derivatives/mriqc/sub-{subject}_ses-{session}_{...}.html` (use checkpoint for heudiconv rule)
- **fmriprep rule**
  - list all files generated, e.g. `/bids/derivatives/fmriprep/sub-{subject}/figures`
  - avoid generating common files to parallelise this step (and generate them after)
    - `/bids/derivatives/fmriprep/sub-{subject}.html`
    - `/bids/derivatives/fmriprep/dataset_description.json`
    - `/bids/derivatives/fmriprep/desc-....tsv`
    - maybe others?
- **freesurfer rules**
  - avoid potential race conditions wrt. `fsaverage` file (maybe use a `shadow` rule)
