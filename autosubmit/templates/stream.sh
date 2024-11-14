#!/bin/bash
#####################################################################################################################
# stream.sh
# Brief: This script runs the stream benchmark 
#####################################################################################################################

function run_stream() {
    set -xv
    cfg=%COMMON_PATH_LOCATIONS.CFG%
    platform=%DEFAULT.HPCARCH%
    platform=${platform,,}
    env_sources=${cfg}/env/${platform}/environment.env
    run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
    compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
    nproc=%NUMPROC%

    source ${env_sources}
    cd $run_root/hardware_benchmarks/STREAM_RUN || exit
    $compilation/STREAM/stream > stream_${nproc}.txt
}

stream_enabled=%HW_BENCHMARKS.STREAM.ENABLED%
stream_enabled=${stream_enabled,,}

${stream_enabled} && run_stream