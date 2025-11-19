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
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
member="tracing"

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

names=($(bashify_array "%TRACING.NAMES%"))
tests=($(bashify_array "%TRACING.TEST_NAMES%" true))
components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

source ${env_sources}

for test in "${tests[@]}"
do
    test_name=$member/$test
    if [ "${timestep_zero}" = "TRUE" ]; then
        magiccut_steps=$(echo ${trace_steps}+1 | bc)
    else
        magiccut_steps=${trace_steps}
    fi
    
    # Iterate over all run_* folders
    for name in "${names[@]}"
    do
        trace_folder=${run_root}/${test_name}/run_${name}
        cd ${trace_folder} || exit

        test_info_fn=${name}-ts_test_info.csv
        echo "component,fastest_ts_time" > ${test_info_fn}

        for component in "${components[@]}"; do
            curr_mc_steps=${magiccut_steps}
            if [ "${timestep_zero^^}" != "TRUE" ] && [ "${component}" = "oifs" ]; then
                curr_mc_steps=$((magiccut_steps+1))
            fi
            # Run magiccut and save component's fastest step
            ${magiccut} $component.prv $curr_mc_steps | tee ${component}_magiccut.log
            grep "Worst / best" ${component}_magiccut.log | awk -F ' ' '{print $8}' > ${component}_fastest_ts.txt
            
            echo "${component},$(echo $(cat ${component}_fastest_ts.txt) / 1000000000 | bc -l)" >> ${test_info_fn}
        done
    done
done
