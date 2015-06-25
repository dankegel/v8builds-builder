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
       S)  SHARED_PLEASE=library=shared
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
  configs=( "debug" "release" )
  for c in "${configs[@]}"; do
    make -j2 x64.$c V=1 $SHARED_PLEASE
    make -j2 x64.$c V=1 $SHARED_PLEASE

    # combine all the static libraries into one called v8_full
    pushd out/x64.$c
    find . -name '*.a' -exec ar -x '{}' ';'
    ar -crs libv8_full.a *.o
    rm *.o
    popd
  done

  if [ $UNAME = 'Darwin' ]; then
    # move default libstdc++ builds aside
    mv out/x64.debug out/x64.debug.libstdc++
    mv out/x64.release out/x64.release.libstdc++

    unset CXXFLAGS
    unset CFLAGS
    export CXX="clang++ -std=c++11 -stdlib=libc++"
    export LINK="clang++ -std=c++11 -stdlib=libc++"
    export GYP_DEFINES="clang=1 mac_deployment_target=10.9"
    make clean || true

    # do the build
    configs=( "debug" "release" )
    for c in "${configs[@]}"; do
      make -j2 x64.$c V=1 $SHARED_PLEASE
      make -j2 x64.$c V=1 $SHARED_PLEASE

      # combine all the static libraries into one called v8_full
      pushd out/x64.$c
      find . -name '*.a' -exec ar -x '{}' ';'
      ar -crs libv8_full.a *.o
      rm *.o
      popd
    done

    # move builds aside
    mv out/x64.debug out/x64.debug.libc++
    mv out/x64.release out/x64.release.libc++
  fi
  popd # v8
fi

popd
