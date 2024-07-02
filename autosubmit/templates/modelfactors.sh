#!/bin/bash
#####################################################################################################################
# modelfactors.sh
# Brief: This script runs the modelfactors script on the cut traces generated from trace_cut.sh
#####################################################################################################################

###################
# AS variables
###################
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
tests="%TRACING.TEST_NAMES%"
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%

source ${env_sources}

member="tracing"
tests=${tests//[\[,\]]/}
tests=$(for v in ${tests}; do echo "$v";done | sort | uniq | xargs)

for test in $tests
do
    test_name="${member}/$(basename $test)"
    test_root=$run_root/$test_name
    traces=($test_root/trace_*/*best_cut.prv)

    mkdir -p ${test_root}/modelfactors
    cd ${test_root}/modelfactors || exit
    modelfactors.py "${traces[@]}"
done

