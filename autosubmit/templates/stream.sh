#!/bin/bash
#####################################################################################################################
# stream.sh
# Brief: This script runs the stream benchmark 
#####################################################################################################################

function run_stream() {
    set -xv
    env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
    run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
    nproc=%NUMPROC%

    source ${env_sources}
    cd $run_root/hardware_benchmarks/STREAM_RUN || exit
    ./stream > stream_${nproc}.txt
}

stream_enabled=%HW_BENCHMARKS.OSU.ENABLED%
stream_enabled=${stream_enabled,,}

${stream_enabled} && run_stream