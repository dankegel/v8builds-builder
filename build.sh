#!/bin/bash
set -x
set -e
set -o pipefail

# This goes through the entire build sequence

# win deps: git, tee
# lin deps: git, tee
# osx deps: git, tee

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/environment.sh

usage ()
{
cat << EOF

usage:
   $0 options

Build script.

OPTIONS:
   -h    Show this message
   -r    Revision represented as a git tag version i.e. 4.5.73 (optional, builds latest version if omitted)
   -S    Generate shared libv8 library (avoids crashes when multiple units link against it)
   -c C  build configurations C1[,C2,...]
         linux configs: (release|debug)
         mac configs: (release|debug).(libc++|libstdc++)
   -p TB pickle clean source tree to given tarball after downloading, don't actually build
   -P TB unpickle clean source tree from given tarball instead of using fetch
EOF
}

while getopts :Sc:r:p:P: OPTION
do
   case $OPTION in
       S)  SHARED_PLEASE=-S
           ;;
       c)  configs=$OPTARG
           ;;
       r)
           REVISION=$OPTARG
           ;;
       p)  opt_pickle=-p
           PICKLEFILE="$OPTARG"
           ;;
       P)  opt_unpickle="-P"
           UNPICKLEFILE="$OPTARG"
           ;;
       ?)
           usage
           exit 1
           ;;
   esac
done

# clean first
$DIR/clean.sh 2>&1

# generate directory to build in
BUILD_DIR=$OUT_DIR

if [ -z $REVISION ]; then
  # If no revision given, then get the latest tag i.e. 4.2.62
  REVISION=`git ls-remote --tags $REPO_URL | cut -f 2 | sed 's#refs/tags/##' | grep '^[0-9]' | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | tail -1`
  if [ -z $REVISION ]; then
    echo "Could not get latest revision"
    exit 2
  fi
fi

$DIR/check_depot_tools.sh 2>&1 | tee $BUILD_DIR/check_depot_tools.log
if [ -z "$DEB_BUILD_ARCH" ]; then
   $DIR/check_deps.sh 2>&1 | tee $BUILD_DIR/check_deps.log
else
   echo "Inside debian package builder, let it enforce dependencies"
fi
$DIR/checkout.sh -r $REVISION $opt_pickle $PICKLEFILE $opt_unpickle $UNPICKLEFILE -d $BUILD_DIR 2>&1 | tee $BUILD_DIR/checkout.log
if ! [ -z "$opt_pickle" ]; then
   echo "Specified pickling, so not building"
   exit 0
fi
$DIR/patch.sh $SHARED_PLEASE -d $BUILD_DIR 2>&1 | tee $BUILD_DIR/patch.log
$DIR/compile.sh $SHARED_PLEASE -c $configs -d $BUILD_DIR 2>&1 | tee $BUILD_DIR/compile.log
$DIR/package.sh $SHARED_PLEASE -d $BUILD_DIR -r $REVISION 2>&1 | tee $BUILD_DIR/package.log

# for extensibility
if [ -f $DIR/build.local ]; then
  $DIR/build.local -r $REVISION -d $BUILD_DIR 2>&1 | tee $BUILD_DIR/build.local.log
fi
