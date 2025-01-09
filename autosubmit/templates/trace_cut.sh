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
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
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

        trace_id=${trace_folder//*trace_}
        test_info_fn=${trace_id}-ts_test_info.csv
        echo "component,ts_length" > ${test_info_fn}

        for component in $components; do
            curr_mc_steps=${magiccut_steps}
            if [ "${timestep_zero^^}" != "TRUE" ] && [ "${component}" = "oifs" ]; then
                curr_mc_steps=$((magiccut_steps+1))
            fi
            # Run magiccut and save component's fastest step
            ${magiccut} $component.prv $curr_mc_steps | tee ${component}_magiccut.log
            grep "Worst / best" ${component}_magiccut.log | awk -F ' ' '{print $8}' > ${component}_fastest_ts.txt
            
            echo "${component},$(cat ${component}_fastest_ts.txt)" >> ${test_info_fn}
        done
    done
done
