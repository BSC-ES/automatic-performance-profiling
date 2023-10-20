#!/bin/bash

if [ $# -lt "2" ]
then
    echo "You must introduce 2 arguments [DIRECTORY] [BRANCH]"
else
    
    # Create target directory
    mkdir -p $1
    cd $1
    
    # Clone ECEARTH4 repository
    if [ ! -d ecearth4_${2} ]; then
        git clone --recurse-submodules https://git.smhi.se/ec-earth/ecearth4.git ecearth4_${2}
    fi
    
    cd ecearth4_${2}
    git checkout ${2}
fi