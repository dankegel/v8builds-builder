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
   -S   Generate shared libv8 library (avoids crashes when multiple units link against it)
EOF
}

while getopts :d:r:S OPTION
do
   case $OPTION in
       d)
           BUILD_DIR=$OPTARG
           ;;
       S)
           SHARED_PLEASE=1
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
rm -rf $BUILDLABEL
mkdir -p $BUILDLABEL/bin $BUILDLABEL/include $BUILDLABEL/lib

# find and copy everything that is not a library or object file into bin
find `ls -d v8/out/x64.* | tail -n 1` -maxdepth 1 -type f \
  -not -name *.so -not -name *.a -not -name *.jar -not -name *.lib \
  -not -name '*.o' \
  -not -name '*.obj' \
  -not -name '*.lock' \
  -not -name '*.d' \
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
# https://groups.google.com/forum/#!topic/v8-users/KhniGgixxGM
# says embedders like us should, beyond the shared libv8, also
# link to v8_libplatform (which needs v8_libbase)
LIBS="v8_libplatform v8_libbase v8"
if [ -z "$SHARED_PLEASE" ]; then
   LIBS="$LIBS libv8_base libv8_external_snapshot"
fi
for INDIR in v8/out/x64.*
do
  OUTDIR=$BUILDLABEL/lib/`basename $INDIR`
  mkdir -p ${OUTDIR}
  for lib in $LIBS
  do
     find $INDIR -name "*${lib}.*" \
        -not -name '*.obj' \
        -not -name '*.o' \
        -not -name '*.d' \
        -exec $CP '{}' $OUTDIR ';'
  done
done

# zip up the package
rm -rf $BUILDLABEL.zip
if [ $UNAME = 'Windows' ]; then
  $DEPOT_TOOLS/win_toolchain/7z/7z.exe a -tzip $BUILDLABEL.zip $BUILDLABEL
else
  zip -r $BUILDLABEL.zip $BUILDLABEL
fi

# archive version_number
echo $REVISION > version_number

popd
