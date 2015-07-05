#!/bin/sh
set -e
set -x

# This compiles a single build

# win deps: gclient, ninja
# lin deps: gclient, ninja

DIR=`dirname $0`
DIR=`cd $DIR; pwd`
. $DIR/environment.sh

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
   -c C build configurations C1[,C2,...]
        linux configs: (release|debug)
        mac configs: (release|debug).(libc++|libstdc++)
EOF
}

while getopts :Sc:d: OPTION
do
    case $OPTION in
       c)  configs=$OPTARG
           ;;
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

if [ $UNAME = 'Windows' ]; then
  echo "TBD"
  exit 1
fi

cd $BUILD_DIR/v8

for config in `echo $configs | tr ',' ' '`
do
  make clean || true

  unset CFLAGS
  unset CXXFLAGS
  unset debrel
  unset GYP_DEFINES
  unset libc
  unset LINK

  case $config in
  *debug*)   debrel=debug;;
  *release*) debrel=release;;
  *)  echo "bad configuration $config, expected it to contain debug or release; exit 1;;
  esac

  if [ $UNAME = 'Darwin' ]; then
  case $config in
  *libc++*)    libc=libc++;;
  *libstdc++*) libc=libstdc++;;
  *)  echo "bad configuration $config, expected it to contain libc++ or libstdc++; exit 1;;
  esac

  if [ $UNAME = 'Linux' ]; then
    export CXXFLAGS="-fPIC -Wno-format-pedantic"
    export CFLAGS="-fPIC -Wno-format-pedantic"
  fi
  if [ $UNAME = 'Darwin' ]; then
    case $libc in
    libc++)
       export CXX="clang++  -stdlib=libc++"
       export LINK="clang++ -stdlib=libc++"
       ;;
    libstdc++)
       export CXX="clang++  -stdlib=libstdc++"
       export LINK="clang++ -stdlib=libstdc++"
       ;;
    esac
    export GYP_DEFINES="clang=1 mac_deployment_target=10.9"
  fi

  make -j2 x64.$debrel V=1 $SHARED_PLEASE
  # Used to run make twice here -- was that to fix some parallel build problem?

  if test $debrel != $config; then
    mv out/x64.$debrel out/x64.$config
  fi
done
