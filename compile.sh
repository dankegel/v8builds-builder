#!/bin/bash
set -eo pipefail
set -x

# This compiles a single build

# win deps: gclient, ninja
# lin deps: gclient, ninja

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/environment.sh

usage ()
{
cat << EOF

usage:
   $0 options

Compile script.

OPTIONS:
   -h   Show this message
   -d   Top level build dir
   -S   Generate shared libv8 library (avoids crashes when multiple units link against it)
EOF
}

while getopts :Sd: OPTION
do
    case $OPTION in
       # can't build icu static and v8 shared, so just turn icu off for now to avoid conflicting with system icu
       # Right fix would be to either build icu static or, better, use system icu.
       S)
           SHARED_PLEASE="library=shared i18nsupport=off"
           #SHARED_PLEASE="library=shared use_system_icu=1"
           ;;
       d)
           BUILD_DIR=$OPTARG
           ;;
       ?)
           usage
           exit 1
           ;;
   esac
done

if [ -z "$BUILD_DIR" ]; then
   usage
   exit 1
fi

configs="debug release"

# gclient only works from the build directory
pushd $BUILD_DIR

if [ $UNAME = 'Windows' ]; then
  echo "TBD"
else
  # linux and osx

  pushd v8

  # Need to export a few flags only on linux
  if [ $UNAME = 'Linux' ]; then
    export CXXFLAGS="-fPIC -Wno-format-pedantic"
    export CFLAGS="-fPIC -Wno-format-pedantic"
  fi

  make clean || true

  # do the build
  for c in $configs; do
    if ! [ -z "$SHARED_PLEASE" ]; then
      case $UNAME in
      Darwin) echo "don't forget to use install_name_tool to set the install_name of each dylib when installing";;
      esac
    fi

    make -j2 x64.$c V=1 $SHARED_PLEASE
    make -j2 x64.$c V=1 $SHARED_PLEASE
  done

  if [ $UNAME = 'Darwin' ]; then
    # move default libstdc++ builds aside
    for c in $configs; do
      mv out/x64.$c out/x64.$c.libstdc++
    done

    unset CXXFLAGS
    unset CFLAGS
    export CXX="clang++ -std=c++11 -stdlib=libc++"
    export LINK="clang++ -std=c++11 -stdlib=libc++"
    export GYP_DEFINES="clang=1 mac_deployment_target=10.9"
    make clean || true

    # do the build
    for c in $configs; do
      make -j2 x64.$c V=1 $SHARED_PLEASE
      make -j2 x64.$c V=1 $SHARED_PLEASE
    done

    # move builds aside
    for c in $configs; do
      mv out/x64.$c out/x64.$c.libc++
    done
  fi
  popd # v8
fi

popd
