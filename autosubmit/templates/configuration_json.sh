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
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
papi_counters_plots="%TRACING.PAPI_COUNTERS_PLOTS%"
components="%MODEL.COMPONENTS%"
ppn=%PROCESSORS_PER_NODE%

# Set the input files depending on the model
reporter_params=""
case  "${model}" in
    "nemo")
        input_files="scalability_*/*.timing.pkl"
    ;;
    "ecearth4")
        input_files="scalability_*/lucia_lite_results/table.csv"
        reporter_params="--coupling-folder coupling"
    ;;
esac

# Set the member variables and the extra reporter params for Tracing
case "$current_member" in
    "StrongScaling")
        test_name="strong_scaling"
        tests="%STRONGSCALING.TEST_NAMES%"
        tile_size="-"
    ;;
    "Tracing")
        test_name="tracing"
        tests="%TRACING.TEST_NAMES%"
        tile_size="-"
        reporter_params="-f function_csv \
        --functions-file functions_summary.txt \
        --most_expensive_function_summary most_expensive_function_summary.csv \
        --tracking-folder tracking \
        --scatter-plots $(echo $papi_counters_plots | sed 's/ /:/g')"
        input_files="paramedir/*pm"
    ;;
    "CompilationEfficiency")
        test_name="compilation_efficiency"
        tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
        tile_size="-"
    ;;
    "WeakScaling")
        test_name="weakscaling"
        tests="%WEAKSCALING.TEST_NAMES%"
        tile_size="%WEAKSCALING.TILE_SIZE%"
        tile_size=${tile_size//[\[,\]]/}
        tile_size=($(for v in $tile_size; do echo "$v";done| uniq| xargs))
    ;;
esac

tests=${tests//[\[,\]]/}
tests=$(for v in $tests; do echo "$v";done| uniq| xargs)

components=${components//[\[,\]]/}
components=$(for v in $components; do echo "$v";done| sort| uniq| xargs)

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

i=0
for test in $tests
do
    test_name_=$test_name/$test
    cd $run_root/$test_name_ || exit
    
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
        if [ "${current_member}" = "WeakScaling" ]; then
            echo tile_size=\'${tile_size[$i]}\'
        fi
        echo number_of_processes=\'$(ls | grep -E trace_ | sed 's/.*trace_//')\'
    } > param.cfg
    
    python3 ${cfg}/parser/collector.py \
        --input-files ${input_files} \
        --output-file ${test} \
        --param-file param.cfg \
        --components "${components}"
    python3 ${cfg}/parser/reporter.py ${tmp_reporter_params}
    i=$((i+1))
done
