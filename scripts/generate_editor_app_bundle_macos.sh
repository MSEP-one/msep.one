#!/bin/bash
source build_editor_release.macos.sh || exit 1
lipo -create ../godot/bin/godot.macos.editor.arm64 ../godot/bin/godot.macos.editor.x86_64 -output ../godot/bin/godot.macos.editor.universal
# going to the root of msep project
cd ..
echo "Creating app bundle at root of the project"
cp -r godot/misc/dist/macos_tools.app .
mkdir -p macos_tools.app/Contents/MacOS
echo "Copying the editor universal binnary to Contents/MacOS"
cp godot/bin/godot.macos.editor.universal macos_tools.app/Contents/MacOS/Godot
echo "Giving it executable permission"
chmod +x macos_tools.app/Contents/MacOS/Godot

echo "Done!"
