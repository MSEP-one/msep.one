#!/bin/bash
SCRIPT_PATH="$(dirname $0)"
cd ../godot

ARGS="p=windows custom_modules=../modules use_mingw=yes arch=x86_64 disable_exceptions=false module_upnp_enabled=no"

if ! scons $ARGS $@; then
    echo "Error building windows editor in release mode"
fi

cd $SCRIPT_PATH
