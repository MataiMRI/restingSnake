#!/bin/bash



apptainer run --bind RESULTSDIR:/mnt \
PATH_TO_CONTAINER \
-d /mnt/tidy/sub_{subject}/ses_{session}/*/* \
-o /mnt/bids \
-f convertall \
-s SUBJECT \
-ss SESSION \
-c none \
--overwrite
