#!/bin/bash
#####################################################################################################################
# remote_setup.sh
# Brief: This script clones the hardware benchmarks repositories
#####################################################################################################################

###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%

function clone_hw_benchmarks() 
{
    cd ${compilation} || exit

    osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
    osu_enabled=${osu_enabled,,}
    stream_enabled=%HW_BENCHMARKS.STREAM.ENABLED%
    stream_enabled=${stream_enabled,,}

    if ${osu_enabled} && [ ! -d osu-micro-benchmarks ]; then
        osu_source=%HW_BENCHMARKS.OSU.SOURCE%
        wget -O osu-micro-benchmarks.tar.gz ${osu_source}
        tar -xvf osu-micro-benchmarks.tar.gz --one-top-level --strip-components=1
        rm osu-micro-benchmarks.tar.gz
    fi

    if ${stream_enabled} && [ ! -d STREAM ]; then
        git clone https://github.com/jeffhammond/STREAM.git STREAM
    fi
}

###################
# Start script
###################

set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

mkdir -p ${compilation}
mkdir -p ${run_folder}

clone_hw_benchmarks
