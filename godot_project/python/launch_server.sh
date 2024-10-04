#!/usr/bin/env bash
SCRIPT_DIR=$(dirname "$0")

if [ -z == "$2" ]; then
echo "Environment path not provided"
exit 1
fi
MSEP_ENV_PATH="$2"
source "$MSEP_ENV_PATH/bin/activate"
echo $MSEP_ENV_PATH
conda unpack
python "$SCRIPT_DIR/scripts/openmm_server.py" $@
