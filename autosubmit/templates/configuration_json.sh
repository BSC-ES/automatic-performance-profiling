#!/bin/bash
#####################################################################################################################
# configuration_json.sh
# Brief: This script gathers all member performance metrics and generates the corresponding curated output for the
#           report generator to use
#####################################################################################################################

###################
# AS variables
###################
current_member=%MEMBER%
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
ppn=%PROCESSORS_PER_NODE%

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

# Load array variables
components=$(bashify_array "%MODEL.REPORT_COMPONENTS%" true)

# Set the input files depending on the model
reporter_params=""
input_files="run_*/*-test_info.csv "
case "${model}" in
    "nemo")
        input_files+="run_*/*-timing.output"
    ;;
    "ecearth4")
        coupling_enabled="%STRONGSCALING.COUPLING_REPORT.ENABLED%"
        coupling_enabled=${coupling_enabled,,}
        if ${coupling_enabled}; then
            input_files+=" run_*/lucia_lite_results/table.csv"
            reporter_params="--coupling-folder coupling"
        fi

        echo "${components[@]}" | grep -w "oifs" && input_files+=" run_*/*-ifs.stat"
        echo "${components[@]}" | grep -w "nemo" && input_files+=" run_*/*-timing.output"
    ;;
esac

# Set the member variables and the extra reporter params for Tracing
case "$current_member" in
    "StrongScaling")
        member="strong_scaling"
        tests="%STRONGSCALING.TEST_NAMES%"
    ;;
    "Tracing")
        uf_enabled="%TRACING.USER_FUNCTIONS.ENABLED%"
        uf_enabled=${uf_enabled,,}
        pc_plots="%TRACING.USER_FUNCTIONS.PAPI_COUNTERS.PLOTS%"
        pc_enabled="%TRACING.USER_FUNCTIONS.PAPI_COUNTERS.ENABLED%"
        pc_enabled=${pc_enabled,,}

        reporter_params=""
        if ${uf_enabled}; then
            reporter_params+=" -f function_csv"
            reporter_params+=" --functions-file functions_summary.txt"
            reporter_params+=" --most_expensive_function_summary most_expensive_function_summary.csv"
            reporter_params+=" --tracking-folder tracking"
            ${pc_enabled} && reporter_params+=" --scatter-plots ${pc_plots// /:}"
        fi

        member="tracing"
        tests="%TRACING.TEST_NAMES%"
        input_files=" paramedir/*pm"
    ;;
    "CompilationEfficiency")
        member="compilation_efficiency"
        tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
    ;;
    "WeakScaling")
        member="weakscaling"
        tests="%WEAKSCALING.TEST_NAMES%"
    ;;
esac

tests=($(bashify_array "${tests}" true))

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

for test in "${tests[@]}"
do
    test_folder=${run_root}/${member}/${test}
    cd ${test_folder} || exit
    
    tmp_reporter_params="${reporter_params} -j ${test}.json"
    # Generate scaling report only if not Tracing
    if [ "${current_member}" != "Tracing" ]; then
        tmp_reporter_params="${tmp_reporter_params} \
        --sypd-file ${test}_scaling.csv \
        --sypd-plot ${test}_scaling.png"
    fi
    
    # Create param file for the python script
    {
        echo processes_per_node=${ppn} 
        echo configuration_name=${test}
    } > param.cfg
    
    python3 ${cfg}/parser/collector.py \
        --input-files ${input_files} \
        --output-file ${test} \
        --param-file param.cfg \
        --components "${components}"
    python3 ${cfg}/parser/reporter.py ${tmp_reporter_params}
done
