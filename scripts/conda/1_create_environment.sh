#/bin/sh

# Checking if conda exists
if command -v conda > /dev/null 2>&1; then
    conda update conda -y
    conda create --name msep.one -c conda-forge openmm openff-toolkit-base openff-interchange-base rdkit pyzmq -y

else
    # restarting the terminal is mandatory for conda to initialize itself
    echo "Restart the terminal and launch setup.sh again to proceed."
    exit 1;
fi
