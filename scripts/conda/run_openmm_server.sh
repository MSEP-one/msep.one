SCRIPT_DIR=$(dirname $0)
source "./2_activate_environment.sh"

cd ../../godot_project/python/scripts
python openmm_server.py
