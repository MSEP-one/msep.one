#!/bin/bash
SCRIPT_PATH="$(dirname "$0")"
cd ../godot
scons  debug_symbols=true compiledb=true disable_exceptions=false custom_modules=../modules $@
cd $SCRIPT_PATH
