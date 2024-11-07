#!/bin/bash
#####################################################################################################################
# modelfactors.sh
# Brief: This script runs the modelfactors script on the cut traces generated from trace_cut.sh
#####################################################################################################################

function run_modelfactors() {
    run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
    tests="%TRACING.TEST_NAMES%"
    env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
    components="%MODEL.COMPONENTS%"

    source ${env_sources}

    member="tracing"
    tests=${tests//[\[,\]]/}
    tests=$(for v in ${tests}; do echo "$v";done | sort | uniq | xargs)
    components=${components//[\[,\]]/}
    components=$(for v in $components; do echo "$v";done| sort| uniq| xargs)

    for test in $tests
    do
        test_name="${member}/$(basename $test)"
        test_root=$run_root/$test_name
        mkdir -p ${test_root}/modelfactors

        for component in $components; do
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

modelfactors_enabled=%TRACING.MODELFACTORS.ENABLED%
modelfactors_enabled=${modelfactors_enabled,,}

${modelfactors_enabled} && run_modelfactors
