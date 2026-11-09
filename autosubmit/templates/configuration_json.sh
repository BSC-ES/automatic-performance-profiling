#!/bin/bash
#####################################################################################################################
# configuration_json.sh
# Brief: This script declares the raw files of every test, writes their input mapping and runs the collector and the
#           reporter, generating the curated output the report generator uses
#####################################################################################################################

###################
# AS variables
###################
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
components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))
component=$(echo "${components[0]}" | tr '[:upper:]' '[:lower:]')

# Declare which raw file feeds which case, component and format. Patterns are relative to a
# single run directory; the mapping is written per test by write_input_mapping
reporter_params=""
cases_variables="nproc"
component_specs=("")
case_level_specs=("")
test_info_patterns="*test_info.csv"
case "${model}" in
    "monarch")
        cases_variables+=" jnpes inpes write_groups write_tasks"
        test_info_patterns="*test_info.csv *test_info.yaml"
    ;;
    "nemo")
        test_info_patterns="*test_info.csv *test_info.yaml"
        component_specs+=("nemo|nemo-timing|timing.output")
    ;;
    "hpcw")
        test_info_patterns="*test_info.csv *test_info.yaml"
        if [ "${component}" == "icon" ]; then
            component_specs+=("icon|icon-timer-report|icon_timer.log")
        else
            component_specs+=("nemo|nemo-timing|timing.output")
        fi
    ;;
    "ecearth4")
        coupling_enabled="%STRONGSCALING.COUPLING_REPORT.ENABLED%"
        coupling_enabled=${coupling_enabled,,}
        if ${coupling_enabled}; then
            case_level_specs+=("lucia|lucia_lite_results/table.csv")
            reporter_params="--coupling-folder coupling"
        fi

        echo "${components[@]}" | grep -w "oifs" && component_specs+=("oifs|ifs-stat|*-ifs.stat")
        echo "${components[@]}" | grep -w "nemo" && component_specs+=("nemo|nemo-timing|*-timing.output")
    ;;
esac

# Set the member variables and the extra reporter params for Tracing
current_member=$(echo "%TASKTYPE%" | grep -oE "COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS")
current_member=${current_member,,}

# Tracing always runs a single repetition; the other members declare theirs
splits=1
case "$current_member" in
    "strongscaling")
        tests="%STRONGSCALING.TEST_NAMES%"
        names="%STRONGSCALING.NAMES%"
        splits="%STRONGSCALING.SPLITS%"

        if [ "${model}" == "monarch" ]; then
            reporter_params+=" --scalability-variable sdpd"
        fi

        if [ "${model}" == "hpcw" ] && [ "${component}" == "icon" ]; then
            reporter_params+=" --scalability-variable time"
        fi
    ;;
    "tracing")
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
            reporter_params+=" --function-time-share-plot function_time_share.png"
            reporter_params+=" --tracking-folder tracking"
            ${pc_enabled} && reporter_params+=" --scatter-plots ${pc_plots// /:}"
        fi
        reporter_params+=" --mpi-profile-share-plot mpi_profile_share.png"

        tests="%TRACING.TEST_NAMES%"
        names="%TRACING.NAMES%"
        for traced_component in "${components[@]}"; do
            for paramedir_cfg in "${cfg}"/trace_analysis/paramedir_configurations/*.pm.cfg; do
                [ -f "${paramedir_cfg}" ] || continue
                counter=$(basename "${paramedir_cfg}")
                counter=${counter%.pm.cfg}
                component_specs+=("${traced_component}|paramedir|../paramedir/${traced_component}-@CASE@-${counter}.pm|${counter}")
            done
        done
    ;;
    "compilation_efficiency")
        tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
        names="%COMPILATION_EFFICIENCY.NAMES%"
        splits="%COMPILATION_EFFICIENCY.SPLITS%"

        if [ "${model}" == "monarch" ]; then
            reporter_params+=" --scalability-variable sdpd"
        fi

        if [ "${model}" == "hpcw" ] && [ "${component}" == "icon" ]; then
            reporter_params+=" --scalability-variable time"
        fi
    ;;
    "weakscaling")
        tests="%WEAKSCALING.TEST_NAMES%"
        names="%WEAKSCALING.NAMES%"
        splits="%WEAKSCALING.SPLITS%"
    ;;
esac

[[ "${splits}" =~ ^[0-9]+$ ]] || splits=1

tests=($(bashify_array "${tests}" true))
names=($(bashify_array "${names}"))

#####################################################################################################################
# Brief: Writes the mapping that declares which file belongs to which case, component and format
# Global: names, component_specs, case_level_specs, test_info_patterns
# Param:
#   - $1: test name
#####################################################################################################################
function write_input_mapping()
{
    local test_name=$1
    local name spec component_name format pattern counter test_info_files

    echo "test: ${test_name}"
    echo "parameters: param.cfg"
    echo "cases:"
    for name in "${names[@]}"; do
        test_info_files=""
        for pattern in ${test_info_patterns}; do
            test_info_files+="\"run_${name}/${pattern}\", "
        done
        echo "  ${name}:"
        echo "    test_info: [${test_info_files%, }]"
        echo "    inputs:"
        for spec in "${case_level_specs[@]}"; do
            if [ -z "${spec}" ]; then
                continue
            fi
            format=${spec%%|*}
            pattern=${spec#*|}
            echo "      - format: ${format}"
            echo "        files: run_${name}/${pattern}"
        done
        for spec in "${component_specs[@]}"; do
            if [ -z "${spec}" ]; then
                continue
            fi
            IFS='|' read -r component_name format pattern counter <<< "${spec}"
            pattern=${pattern//@CASE@/${name}}
            echo "      - component: ${component_name}"
            echo "        format: ${format}"
            if [[ "${pattern}" == ../* ]]; then
                echo "        files: run_${name}/${pattern}"
            else
                echo "        files: [\"run_${name}/${pattern}\", \"run_${name}/*/${pattern}\"]"
            fi
            if [ -n "${counter}" ]; then
                echo "        counter: ${counter}"
            fi
        done
    done
}

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

for test in "${tests[@]}"
do
    test_folder=${run_root}/${current_member}/${test}
    cd ${test_folder} || exit
    
    tmp_reporter_params="${reporter_params} -j ${test}.json --cases-component-data ${cases_variables}"
    if [ "${current_member}" != "tracing" ]; then
        tmp_reporter_params="${tmp_reporter_params} \
        --scalability-file ${test}_scaling.csv \
        --scalability-plot ${test}_scaling.png"
    fi
    
    {
        echo processes_per_node=${ppn}
        echo configuration_name=${test}
    } > param.cfg

    write_input_mapping "${test}" > inputs.yml

    python3 ${cfg}/parser/collector.py \
        --mapping inputs.yml \
        --output-file ${test} \
        --splits ${splits} \
        --components "${components[@]}"
    python3 ${cfg}/parser/reporter.py ${tmp_reporter_params}
done
