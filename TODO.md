# TODO

- add/update files for release (CHANGELOG, AUTHORS, use AUTHORS in LICENSE)
- remove project specific information
  - remove paths, ethics, etc. in [config/config.yml](config/config.yml)
  - remove freesurfer license [config/license.txt](config/license.txt) and document how to get it
  - remove project specific heudiconv script [config/heuristic.py](config/heuristic.py)
- add a workflow (and instructions) to get vanilla heuristic file for `heudiconv`
- add explanations about Atlas structure, using local one as an example
- expand explanations about all parameters in [config/config.yaml](config/config.yaml)
- (minor) use `--workflow-profile` instead of `--profile`
  - rename `profiles/local` to `profiles/default` to make it default
  - use `--workflow-profile` in [profiles/nesi/snakemake.sl](profiles/nesi/snakemake.sl),
    but currently [2023/08/03] this crashes with snakemake 7.30.1 on NeSI
- (minor) add minimal version requirements in Snakefile (for recent functionalities)
  ```
  from snakemake.utils import min_version
  min_version("7.30")
  ```
- try `mamba` on NeSI
  - use module `Mamba/23.1.0-1`
  - simplify `profiles/nesi/snakemake.sl` if possible (may no need to modify condarc as much)
- **heudiconv rule**
  - add a rule to generate `bids/participants.tsv`
- **fmriqc rule**
  - list all outputs, e.g. all file `bids/derivatives/mriqc/sub-{subject}_ses-{session}_{...}.html` (use checkpoint for heudiconv rule)
- **fmriprep rule**
  - test with 16 threads instead of 8
  - list all files generated, e.g. `/bids/derivatives/fmriprep/sub-{subject}/figures`
  - avoid generating common files to parallelise this step (and generate them after)
    - `/bids/derivatives/fmriprep/sub-{subject}.html`
    - `/bids/derivatives/fmriprep/dataset_description.json`
    - `/bids/derivatives/fmriprep/desc-....tsv`
    - maybe others?
- **freesurfer rules**
  - avoid potential race conditions wrt. `fsaverage` file (maybe use a `shadow` rule)
