#!/bin/bash
SCRIPT_PATH="$(dirname "$0")"
cd ../godot
ARGS="p=windows custom_modules=../modules use_mingw=yes arch=x86_64 disable_exceptions=false"

scons target=template_debug $ARGS || echo "Error Building the debug export template"
scons target=template_release $ARGS || echo "Error Building the release export template"

cd $SCRIPT_PATH
