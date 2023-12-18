#!/bin/bash



apptainer run --bind /home/jpmcgeown/data/snakemake/processed:/mnt \
/home/jpmcgeown/github/restingSnake/.snakemake/singularity/10b2306ed15c5efc917232958423bfe6.simg \
-d /mnt/tidy/sub_{subject}/ses_{session}/*/* \
-o /mnt/bids \
-f convertall \
-s rugby1 \
-ss a \
-c none \
--overwrite
