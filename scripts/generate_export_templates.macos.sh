#!/bin/bash

cd ../godot
set -e
ARGS="platform=macos disable_exceptions=false custom_modules=../modules"

# If building inside our containers we provide the vulkan_sdk_path and osxcross_sdk version
if [[ ! -z "${ON_CONTAINER}" ]] ; then
    ARGS="${ARGS} vulkan_sdk_path=/root osxcross_sdk=darwin23.6"
fi


for target in template_release template_debug
do
    for arch in x86_64 arm64 
    do
        if ! scons target=$target arch=$arch $ARGS ; then
            echo "Not able to build for $target and arch: $arch" with parameters "$ARGS"
            exit 1
        fi
        done
    done

for target in release debug
do
        lipo -create bin/godot.macos.template_${target}.arm64 bin/godot.macos.template_${target}.x86_64 -output bin/godot_macos_${target}.universal
        if [ $? -eq 0 ]; then
        echo "Successfully created universal export binary for $target"

        else
            echo "Not able to build for $target and arch: $arch"
            exit 1
        fi
done


# going to the root of msep project
cd ../templates
#echo "Creating app bundle at root of the project"
CONTENTS_DIR="macos_template.app/Contents"
BUNDLE_MACOS_DIR="$CONTENTS_DIR/MacOS"
cp -r ../godot/misc/dist/macos_template.app .
mkdir -p $BUNDLE_MACOS_DIR
for target in release debug 
do
echo "Copying the template for ${target} universal binnary to Contents/MacOS"
cp ../godot/bin/godot_macos_${target}.universal $BUNDLE_MACOS_DIR/
done

echo "Giving it executable permission"
chmod +x $BUNDLE_MACOS_DIR/godot_macos_*
if [ -f msep_macos_template.zip ]; then
rm msep_macos_template.zip
fi

zip -r msep_macos_template macos_template.app
rm -rf macos_template.app
