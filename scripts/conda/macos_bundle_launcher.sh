#!/bin/sh
EXECUTABLE_NAME=MSEP
# Keep the executable name synced with the exported appbundle
scriptdir="$(dirname $0)"
eval "$(conda shell.bash hook)" && \
conda activate msep.one && \
$scriptdir/$EXECUTABLE_NAME
