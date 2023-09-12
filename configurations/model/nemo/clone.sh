#!/bin/bash
#
# Copies the basic NEMO structure to compile and run NEMO, from the BSC-ES mirror
# Usage: ./clone-nemo.sh TARGET_DIR NEMO_BRANCH
# Example: ./clone-nemo.sh NEMO-4.0.2 svn/NEMO/releases/release-4.0.2
# Created by Miguel Castrillo <miguel.castrillo@bsc.es>
#

if [ $# -lt "2" ]
then
    echo "You must introduce 2 arguments [DIRECTORY] [TAG]"
else
    
    # Create target directory
    mkdir -p $1
    cd $1
    
    # Clone NEMO repository
    if [ ! -d nemo_${2} ]; then
        git config --global http.sslVerify "false"
        git clone https://forge.nemo-ocean.eu/nemo/nemo.git nemo_${2}
        git config --global http.sslVerify "true"
    fi
    
    cd nemo_${2}
    git checkout tags/${2}
fi
