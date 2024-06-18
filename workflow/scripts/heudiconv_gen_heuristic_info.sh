#!/bin/bash



apptainer run --bind /nesi/nobackup/uoa03264/jmcg465/gil_cases/processed:/mnt \
/nesi/project/uoa03264/jmcg465/restingSnake/.snakemake/singularity/f945b01a706cad379b15b213af30a94c.simg \
-d /mnt/tidy/sub_{subject}/ses_{session}/*/* \
-o /mnt/bids \
-f convertall \
-s gil1 \
-ss a \
-c none \
--grouping all \
--overwrite
