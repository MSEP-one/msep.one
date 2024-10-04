#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR" || exit
MSEP_ONE_PROJECT_PATH="$SCRIPT_DIR/../godot_project"
MSEP_ONE_EXECUTABLE_NAME="one.msep.editor"
# Helper script to export the project to the targets available

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -g | --godot_editor)
        GODOT_EXECUTABLE="$2"
        shift
        ;;
    -t | --target)
        TARGET="$2"
        shift
        ;;
    -o | --out_dir)
        OUTDIR="$2"
        shift
        ;;
    esac
    shift
done

if [ -z "$OUTDIR" ]; then
    OUTDIR="../exported"
    mkdir -p "$OUTDIR"
    echo "WARNING: No output dir given, defaulting to msep/exported"
    echo "Specify output dir with with -o or --out_dir"
fi
if [ ! -d "$OUTDIR" ]; then
    echo "Directory not valid"
    exit 1
fi

if [ -z "$GODOT_EXECUTABLE" ]; then
    echo "ERROR: No godot editor provided, please specify the path with -g PATH/TO/GODOT_EXECUTABLE/EXECUTABLE"
    exit 1
fi

if [[ ! -x "$GODOT_EXECUTABLE" ]]; then
    echo "Godot Executable provided at $GODOT_EXECUTABLE is not valid"
    exit 1
fi
if [ -z "$TARGET" ]; then
    TARGET="Linux Windows macOS"
fi

for T in $TARGET; do
    echo "Building for platform: $T"

    FINAL_PATH="$OUTDIR/$MSEP_ONE_EXECUTABLE_NAME"
    mkdir -p "$OUTDIR"
    T_LOWER_CASE="$(echo $T | tr '[:upper:]' '[:lower:]')"
    "$GODOT_EXECUTABLE" --path "$MSEP_ONE_PROJECT_PATH" --export-release "$T" "${FINAL_PATH}_${T_LOWER_CASE}.zip"
    if [ $? -ne 0 ]; then
        echo "[ERROR] exporting for $T failed with error code $?"
        exit 1
    fi
done
