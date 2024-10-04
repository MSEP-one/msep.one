#!/bin/bash
# TO DO refactor this to work like the export_project.sh script, asking the user to provide the toolchain path 
# or maybe even doing the download and preparing it on the spot
# Bruno 2023-11-14
############################################################################
# set TOOLCHAIN_BIN_PATH to point to the godot-linux-sdk bin folder before calling this script, like so:
# TOOLCHAIN_BIN_PATH='~/godot/toolchains/x86_64-godot-linux-gnu_sdk-buildroot/bin' ./generate_linuxbsd_export_templates.sh

if [ ! -z "${ON_CONTAINER}" ]; then
  TOOLCHAIN_BIN_PATH="/root/x86_64-godot-linux-gnu_sdk-buildroot/bin"
fi

if [ -z "$TOOLCHAIN_BIN_PATH" ]; then
  echo "Error: Set TOOLCHAIN_BIN_PATH and run the script again."
  echo "TOOLCHAIN_BIN_PATH=~/godot/toolchains/x86_64-godot-linux-gnu_sdk-buildroot/bin ./generate_linuxbsd_export_templates.sh"
  exit 1;
fi

ARGS="disable_exceptions=false custom_modules=../modules /"CC=$TOOLCHAIN_BIN_PATH/x86_64-godot-linux-gnu-gcc/" /"CXX=$TOOLCHAIN_BIN_PATH/x86_64-godot-linux-gnu-g++/""
cd ../godot || exit

if ! PATH=$TOOLCHAIN_BIN_PATH:$PATH scons target=template_release $ARGS; then
    echo "Error building for release"
    exit
fi

if ! PATH=$TOOLCHAIN_BIN_PATH:$PATH scons target=template_debug $ARGS; then
    echo "Error building for debug"
    exit
fi

cp bin/godot.linuxbsd.template_release.x86_64 ../templates/godot.linuxbsd.template_release.x86_64 && \
cp bin/godot.linuxbsd.template_debug.x86_64 ../templates/godot.linuxbsd.template_debug.x86_64

#PATH=/root/x86_64-godot-linux-gnu_sdk-buildroot/bin:$PATH scons disable_exceptions=false custom_modules=../modules platform=linuxbsd target=template_release