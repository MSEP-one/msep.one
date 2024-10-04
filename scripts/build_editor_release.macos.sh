#!/bin/bash
SCRIPT_PATH="$(dirname $0)"
cd ../godot || exit 1

ARGS="platform=macos disable_exceptions=false custom_modules=../modules target=editor"

# If building inside our containers we provide the vulkan_sdk_path and osxcross_sdk version
if [[ ! -z "${ON_CONTAINER}" ]] ; then
    ARGS="${ARGS} vulkan_sdk_path=/root osxcross_sdk=darwin23.6"

fi

for arch in x86_64 arm64 
    do
        if ! scons $ARGS arch=$arch $@ ; then
            echo "Not able to build for arch: $arch" with parameters "$ARGS"
            cd $SCRIPT_PATH || exit 1
            exit 1
        fi
  done
cd $SCRIPT_PATH || exit 1
