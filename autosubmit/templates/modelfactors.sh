#!/bin/bash
#####################################################################################################################
# modelfactors.sh
# Brief: This script runs the modelfactors script on the cut traces generated from trace_cut.sh
#####################################################################################################################

run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
tests="%TRACING.TEST_NAMES%"
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
member="tracing"

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh
tests=($(bashify_array "%TRACING.TEST_NAMES%" true))
components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

function run_modelfactors() {
    for test in "${tests[@]}"
    do
        test_name="${member}/$(basename $test)"
        test_root=$run_root/$test_name
        mkdir -p ${test_root}/modelfactors

        for component in "${components[@]}"; do
            traces=($test_root/trace_*/$component.best_cut.prv)

            mkdir -p ${test_root}/modelfactors/$component
            cd ${test_root}/modelfactors/$component || exit
            modelfactors.py "${traces[@]}"
        done
    done
}

###################
# Start script
###################
. ${env_sources}

modelfactors_enabled=%TRACING.MODELFACTORS.ENABLED%
modelfactors_enabled=${modelfactors_enabled,,}

${modelfactors_enabled} && run_modelfactors
