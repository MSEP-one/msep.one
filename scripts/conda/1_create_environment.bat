cd %HOMEPATH%\miniconda3\Scripts
conda update conda -y
conda create --name msep.one -c conda-forge openmm openff-toolkit-base openff-interchange-base rdkit pyzmq -y
