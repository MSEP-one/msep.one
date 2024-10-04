#!/usr/bin/env bash
echo "Starting to build capnproto libs in $2"
current_directory=$(pwd)
OSXCROSS_SDK=""
platform=""
out_dir=""
arch=""
toolchain_path=""
FORCE_REBUILD=""
CAPNPROTO_DIR="/tmp/capnproto"

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -p | --platform)
        platform="$2"
        shift
        ;;
    -a | --arch)
        arch="$2"
        shift
        ;;
    -o | --out_dir)
        out_dir="$2"
        shift
        ;;
    -t | --toolchain_path)
        toolchain_path="$2"
        shift
        ;;
    -x | --osxcross_sdk)
        OSXCROSS_SDK="$2"
        shift
        ;;
    esac
    shift
done

if [[ -z $platform ]] ; then
echo "Platform was not provided"
exit 101
fi

if [[ -z $arch ]] ; then
echo "arch was not provided"
exit 102
fi

if [[ -z $out_dir ]] ; then
echo "Output dir was not provided"
exit 103
fi

if [[ -z $OSXCROSS_SDK && $platform == "macos" ]] ; then
echo "OSXCross SDK Version was not provided"
exit 105
fi

ARGS=" --enable-static --disable-shared --prefix=${out_dir} "

cd $current_directory
if [[ -d "${current_directory}/build/${platform}/${arch}" ]] ; then
  rm -rf "${current_directory}/build/${platform}/${arch}"
fi

TO_CONFIGURE="$current_directory/build/$platform/$arch"

mkdir -p "${current_directory}/build/${platform}/${arch}" || echo "Can't create directory"

# Going to capnproto main dir to build the executables
cd capnproto || exit 1
cd c++ || exit 1
make distclean
autoreconf -ivf || exit 2
# Configuring building the executables to generate the schemas:
./configure --enable-static --disable-shared --prefix="${CAPNPROTO_DIR}" || exit 3
make -j$(nproc) && make install  || exit 4

export PATH="${CAPNPROTO_DIR}/bin:$PATH"

ARGS+="--with-external-capnp"

CC_PATH=""
CXX_PATH=""

PREVIOUS_PATH=$PWD
cd "$current_directory/.." || exit 5 # Go to the lmdb module root folder
TO_CONVERT="atomic_db.capnp"
capnp compile -o${CAPNPROTO_DIR}/bin/capnpc-c++ "${TO_CONVERT}" || exit 10 

cd $PREVIOUS_PATH || exit 6
if [[ ! -z "${ON_CONTAINER}" ]] ; then
  if [[ "$platform" == "windows" ]] ; then
      ARGS="$ARGS --host=x86_64-w64-mingw32"
    fi

  if [[ "$platform" == "macos" ]] ; then
    if [[ -z $toolchain_path ]] ; then 
      toolchain_path="/root/osxcross"
    fi
      if [ -z "$arch" ] ; then
        arch=$(uname -m)
        echo "No architeture is provided, not safe for crosscompiling. Stopping"
        exit 20
      fi

      TRIPLET="${arch}-apple-${OSXCROSS_SDK}"
      BASE_CMD="${toolchain_path}/target/bin/${TRIPLET}"
      CC_PATH="${TRIPLET}-clang"
      CXX_PATH="${TRIPLET}-clang++"
      export PATH="${toolchain_path}/target/bin:$PATH"
      ARGS="$ARGS --host=${TRIPLET} CC="$CC_PATH" CXX=$CXX_PATH"
  fi

  if [[ "$platform" == "linuxbsd" ]] ; then
    toolchain_path=${GODOT_SDK_LINUX_X86_64}
    export PATH="${toolchain_path}/bin:$PATH"

  fi
else
  # Not on a container and in mac, setting some specs for properly linking against libs built against the same osx sdk
  if [[ "$platform" == "macos" ]] ; then
    # IMPROVEMENT: get a cleaner way to pass those flags to the script from scons
    if [[ "$arch" == "arm64" ]] ; then
      HOST_STRING="${arch}-apple-darwin20" # minimum for macos version 11
      export CFLAGS="$CLFAGS -mmacosx-version-min=11.0 --target=$HOST_STRING"
      export LFLAGS="$LFLAGS -mmacosx-version-min=11.0"
    else
      HOST_STRING="${arch}-apple-darwin16"
      export CFLAGS="$CLFAGS -mmacosx-version-min=10.13 --target=$HOST_STRING"
      export LFLAGS="$LFLAGS -mmacosx-version-min=10.13"
    fi
    ARGS="$ARGS --host=$HOST_STRING"
    export CXXFLAGS=$CFLAGS
  fi

fi


cd c++ || echo "Can´t CD into CWD from $PWD"
make distclean # Cleaning the configure step
cd $TO_CONFIGURE || exit 7
${current_directory}/capnproto/c++/configure $ARGS || exit  8
make -j$(nproc) || exit 9
make install || exit 10
