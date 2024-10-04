#!/bin/bash
echo "Starting to build zeromq libs in $2"
current_directory=$(pwd)
OSXCROSS_SDK="darwin23.6"
OSXCROSS_ROOT="/root/osxcross"
LINUX_BUILDROOT="/root/x86_64-godot-linux-gnu_sdk-buildroot"
WINDOWS_BUILDROOT="/root/llvm-mingw"
platform="$1"
out_dir="$2"
arch="$3"
FORCE_REBUILD=""
if [[ $4 == "--rebuild" ]] ; then
  FORCE_REBUILD="1"
fi


export ARGS="--disable-perf --enable-static --disable-shared --prefix=${2}" # works on mac

cd $current_directory
if [[ -d "${current_directory}/build/${platform}/${arch}" ]] ; then
  rm -rf "${current_directory}/build/${platform}/${arch}"
fi

mkdir -p "${current_directory}/build/${platform}/${arch}" || exit 1
TO_CONFIGURE="$current_directory/build/$platform/$arch"

cd ./zeromq


if [[ ! -z "${ON_CONTAINER}" ]] ; then


  if [[ "$platform" == "windows" ]] ; then
    echo "Setting up build of libzmq.a for windows"
    TRIPLET="x86_64-w64-mingw32"
    BASE_CMD="${WINDOWS_BUILDROOT}/bin/${TRIPLET}"
    ARGS="$ARGS --host=x86_64-w64-mingw32 CPPFLAGS=-DZMQ_STATIC"
  fi

  if [[ "$platform" == "macos" ]] ; then
  # If no arch is passed, defaults to the machine's architeture
    if [ -z "$arch" ] ; then
      arch=$(uname -m)
      echo No architeture is provided, defaulting to $arch
    fi

    TRIPLET="${arch}-apple-${OSXCROSS_SDK}"
    BASE_CMD="${OSXCROSS_ROOT}/target/bin/${TRIPLET}"
    ARGS="$ARGS --host=${TRIPLET} CC=${BASE_CMD}-clang CXX=${BASE_CMD}-clang++"
  fi


  if [[ "$platform" == "linuxbsd" ]] ; then
    TRIPLET="x86_64-godot-linux-gnu"
    BASE_CMD="${LINUX_BUILDROOT}/bin/${TRIPLET}"
    ARGS="$ARGS --host=${TRIPLET} CC=${BASE_CMD}-gcc CXX=${BASE_CMD}-g++"
  fi
fi
echo "$ARGS"
rm -rf config/
./autogen.sh || exit 1
cd $TO_CONFIGURE || exit 1
${current_directory}/zeromq/configure $ARGS || exit 1
make -j$(nproc) || exit 1
make install || exit 1
