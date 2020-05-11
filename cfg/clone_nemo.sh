#!/bin/bash
# 
# Copies the basic NEMO structure to compile and run NEMO, from the BSC-ES mirror
# Usage: ./clone-nemo.sh TARGET_DIR NEMO_BRANCH
# Example: ./clone-nemo.sh NEMO-4.0.2 svn/NEMO/releases/release-4.0.2
# Created by Miguel Castrillo <miguel.castrillo@bsc.es>
#

if [ $# -lt "2" ]
then
    echo "You must introduce 2 arguments [DIRECTORY] [BRANCH]"
else

  # Create target directory
  mkdir -p $1
  cd $1

  # Clone NEMO repository
  git clone https://earth.bsc.es/gitlab/svn/nemo-mirror.git .

  # Checkout and copy tools/
  mkdir _tools
  git checkout svn/utils/tools
  mv [a-Z]* _tools

  # Checkout and copy ext/
  mkdir -p _ext/AGRIF
  git checkout svn/vendors/AGRIF
  mv [a-Z]* _ext/AGRIF/
  mkdir -p _ext/FCM
  git checkout svn/vendors/FCM
  mv [a-Z]* _ext/FCM/
  git checkout svn/vendors/IOIPSL
  mkdir -p _ext/IOIPSL
  mv [a-Z]* _ext/IOIPSL/
  git checkout svn/vendors/IOIPSL

  # Checkout and copy arch/ and makenemo
  mkdir _build
  git checkout svn/utils/build
  mv [a-Z]* _build

  # Checkout NEMO revision
  git checkout $2

  mv _build/* .
  rm -rf _build

  mv _ext ext
  mv _tools tools

fi
