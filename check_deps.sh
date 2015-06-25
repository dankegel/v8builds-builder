#!/bin/bash
set -eo pipefail
set -x

# This installs all dependencies for building.

# osx deps: homebrew
# lin deps: apt-get
# win deps: curl

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/environment.sh

if [ $UNAME = 'Darwin' ]; then
  # for GNU version of cp: gcp and jq
  if ! gcp --version
  then
     brew install coreutils
  fi

  if ! gsed --version
  then
     brew install gnu-sed
  fi

  if ! jq --version
  then
     brew install jq
  fi
elif [ $UNAME = 'Linux' ]; then
  sudo apt-get update && \
  sudo apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    jq \
    python \
    python-pip \
    openjdk-7-jdk \
    g++ \
    zip \
    make
else
  # put jq in python_bin in depot_tools because it is ignored by git
  curl -o $DEPOT_TOOLS/python276_bin/jq.exe 'http://stedolan.github.io/jq/download/win32/jq.exe'
fi

# for extensibility
if [ -f $DIR/check_deps.local ]; then
  $DIR/check_deps.local
fi
