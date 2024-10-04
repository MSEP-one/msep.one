# EXPORTING MSEP ONE

For exporting the project, you will need:
- Our custom export templates
- An up-to-date version of our godot editor
- The project files for msep.one

You can get all the sources and the export templates by clonning and grabbing the submodules

`git clone git@git@github.com:MSEP-one/msep.one.git --recursive`

or if you already have the repo but haven't initialized the submodules, go into the root of the repo and do: 

`git submodule init && git submodule update`

If everything went ok, go into the `scripts/` folder and run `./export_project.sh -g /path/to/godot/editor`

After the process finishes, all available targets will be on a folder `exported/` at the root of the repository
