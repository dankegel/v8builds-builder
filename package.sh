#!/bin/bash
set -eo pipefail
set -x

# This packages a completed build resulting in a zip file in the build directory

# win deps: sed, 7z
# lin deps: sed, zip
# osx deps: gsed, zip

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/environment.sh

usage ()
{
cat << EOF

usage:
   $0 options

Package script.

OPTIONS:
   -h   Show this message
   -d   Top level build dir
   -r   Revision represented as a git tag version i.e. 4.5.73
EOF
}

while getopts :d:r: OPTION
do
   case $OPTION in
       d)
           BUILD_DIR=$OPTARG
           ;;
       r)
           REVISION=$OPTARG
           ;;
       ?)
           usage
           exit 1
           ;;
   esac
done

if [ -z "$BUILD_DIR" -o -z "$REVISION" ]; then
   usage
   exit 1
fi

pushd $BUILD_DIR

# quick-check if something has built
if [ ! -d v8/out ]; then
  popd
  echo "nothing to package"
  exit 2
fi

# create a build label
BUILDLABEL=$PROJECT_NAME-$REVISION-$PLATFORM

if [ $UNAME = 'Darwin' ]; then
  CP="gcp"
else
  CP="cp"
fi

# create directory structure
mkdir -p $BUILDLABEL/bin $BUILDLABEL/include $BUILDLABEL/lib

# find and copy everything that is not a library into bin
find v8/out/x64.release* -maxdepth 1 -type f \
  -not -name *.so -not -name *.a -not -name *.jar -not -name *.lib \
  -not -name *.dylib \
  -not -name *.isolated \
  -not -name *.state \
  -not -name *.ninja \
  -not -name *.tmp \
  -not -name *.pdb \
  -not -name *.res \
  -not -name *.rc \
  -not -name *.x64 \
  -not -name *.x86 \
  -not -name *.ilk \
  -not -name *.TOC \
  -not -name gyp-win-tool \
  -not -name *.manifest \
  -not -name \\.* \
  -exec $CP '{}' $BUILDLABEL/bin ';'

# find and copy header files
find v8/include -name *.h \
  -exec $CP --parents '{}' $BUILDLABEL/include ';'
mv $BUILDLABEL/include/v8/include/* $BUILDLABEL/include
rm -rf $BUILDLABEL/include/v8

# find and copy libraries
find v8/out -maxdepth 2 \( -name *.so -o -name '*.dylib' -o -name *v8_full* -o -name *.jar \) \
  -exec $CP --parents '{}' $BUILDLABEL/lib ';'
mv $BUILDLABEL/lib/v8/out/* $BUILDLABEL/lib
rmdir $BUILDLABEL/lib/v8/out $BUILDLABEL/lib/v8

# zip up the package
if [ $UNAME = 'Windows' ]; then
  $DEPOT_TOOLS/win_toolchain/7z/7z.exe a -tzip $BUILDLABEL.zip $BUILDLABEL
else
  zip -r $BUILDLABEL.zip $BUILDLABEL
fi

# archive version_number
echo $REVISION > version_number

popd
