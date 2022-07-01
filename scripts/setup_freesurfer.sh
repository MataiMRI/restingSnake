#!/bin/bash

workingdir=$1

export FREESURFER_HOME=/usr/local/freesurfer
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export FS_LICENSE=$1/license.txt
