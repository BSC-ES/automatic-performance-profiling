#!/bin/bash
#####################################################################################################################
# trace_cut.sh
# Brief: This script cuts the component traces by the component fastest timestep 
#####################################################################################################################

###################
# AS variables
###################
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
magiccut=%CURRENT_ROOTDIR%/magiccut/magicCut
timestep_zero=%TRACING.TIMESTEP_ZERO%
trace_steps=%TRACING.TRACE_STEPS%
components="%MODEL.COMPONENTS%"
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
tests="%TRACING.TEST_NAMES%"

member="tracing"
tests=${tests//[\[,\]]/}
tests=$(for v in $tests; do echo "$v";done| sort| uniq| xargs)
components=${components//[\[,\]]/}
components=$(for v in $components; do echo "$v";done| sort| uniq| xargs)

source ${env_sources}

for test in $tests
do
    test_name=$member/$test
    if [ "${timestep_zero}" = "TRUE" ]; then
        magiccut_steps=$(echo ${trace_steps}+1 | bc)
    else
        magiccut_steps=${trace_steps}
    fi
    
    # Iterate over all trace_* folders
    for trace_folder in ${run_root}/${test_name}/trace_*
    do
        cd ${trace_folder} || exit
        for component in $components; do
            if [ "${timestep_zero^^}" != "TRUE" ] && [ "${component}" = "oifs" ]; then
                ${magiccut} $component.prv $((magiccut_steps+1))
            else
                ${magiccut} $component.prv ${magiccut_steps}
            fi
        done
    done
done