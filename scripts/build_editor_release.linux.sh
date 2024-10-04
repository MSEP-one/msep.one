#!/bin/bash
SCRIPT_PATH="$(dirname "$0")"
cd ../godot

TOOLCHAIN_BIN_PATH=""

if [ ! -z "${ON_CONTAINER}" ]; then
  TOOLCHAIN_BIN_PATH="/root/x86_64-godot-linux-gnu_sdk-buildroot/bin"
fi

ARGS="disable_exceptions=false custom_modules=../modules target=editor"
if ! PATH=$TOOLCHAIN_BIN_PATH:$PATH scons $ARGS $@; then
    echo "Error building linux editor in release mode"
fi

cd $SCRIPT_PATH
