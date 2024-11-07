#!/bin/bash
#####################################################################################################################
# hardware_benchmarks_images.sh
# Brief: This script generates the hw benchmarks images from OSU and STREAM 
#####################################################################################################################

###################
# AS variables
###################
model=%MODEL.NAME%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
osu_enabled=${osu_enabled,,}
stream_enabled=%HW_BENCHMARKS.OSU.ENABLED%
stream_enabled=${stream_enabled,,}

source $env_sources
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

cd $run_root/hardware_benchmarks || exit

if ${osu_enabled}; then
    osu_tests=(%HW_BENCHMARKS.OSU.TESTS%)
    mkdir -p OSU_RUN/IMAGE

    for test in "${osu_tests[@]}"
    do
        test_name=${test##*/}
        python3 ${cfg}/benchmarks/OSU/OSU_test_plots.py -i OSU_RUN/DATA/${test_name}* -o OSU_RUN/IMAGE/
    done
fi
  
${stream_enabled} && python3 ${cfg}/benchmarks/STREAM/STREAM_data_parser.py -i STREAM_RUN --png --png-output-name STREAM_RUN/${model}.png
