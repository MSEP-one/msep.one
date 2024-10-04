#/bin/sh

# Detect  platform
if [[ $OSTYPE == 'darwin'* ]]; then
  OS="MacOSX"
else
  OS="Linux"
fi

#Detect arch
# Assume if not mac, x64 as we don't support 32bits
ARCH=$(uname -m)
if [[ $ARCH != 'x86_64' ]]; then
    if [[ $OS == "Linux" ]]; then
        ARCH="aarch64"
    else
        ARCH="arm64"
    fi
fi

if ! command -v conda > /dev/null 2>&1; then
  if [ ! -f "tmp/miniconda.sh" ]; then
  # If user does not hve conda we download
    FINAL_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-$OS-$ARCH.sh"
    curl $FINAL_URL -o /tmp/miniconda.sh
  fi
  # and install it ourselves
  chmod +x /tmp/miniconda.sh
  /tmp/miniconda.sh -b -p $HOME/miniconda
  if ! command -v conda > /dev/null 2>&1; then
    source $HOME/miniconda/bin/activate 
    $HOME/miniconda/bin/conda init --all
    fi
  fi