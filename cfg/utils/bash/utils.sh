#!/bin/bash

#####################################################################################################################
# Brief: Transaltes an array in Python format to a Bash array
# Param: 
#   - $1: array in Python format 
#   - $2 (optional, default=false): true if resulting array has unique values, false otherwise
# Return:
#   - ${array[@]} variable contains the translated Bash array
#####################################################################################################################
function bashify_array() {
    array=$1
    local unique=${2:-false}

    array=(${array//[\[,\]\']/})
    ${unique} && array=($(for v in "${array[@]}"; do echo "$v"; done | sort | uniq | xargs))

    echo "${array[@]}"

    return 0
}

#####################################################################################################################
# Brief: Sets the run directory tree shared by the scalability and the post-processing jobs
#        <run_root>/<current_member>/<test_type>/run_<run_name>[/<split>]
# Parameters:
#   - $1: test type, e.g. TCE127L91 (the TEST_NAMES entry)
#   - $2 (optional): run name, e.g. 4n (the NAMES entry); omit it to get only test_dir
# Global:
#   - run_root, current_member
# Sets:
#   - test_dir: test root, shared by every run of the test type
#   - run_dir: stable per-run root; everything the post-processing reads lives here
#####################################################################################################################
function set_run_paths()
{
    local test_type=$1
    local run_name=${2:-}

    test_dir=${run_root}/${current_member}/${test_type}
    [ -n "${run_name}" ] || return 0

    run_dir=${test_dir}/run_${run_name}
}

#####################################################################################################################
# Biref: Creates a csv file run_id-test_info.csv that contains the configuration of the test
# Arguments:
#   - List of the names of variables to report
# Global:
#   - Paths: run_dir
#   - Other: run_id, components, (component)_procs, (component)_resolution, (component)_curr_tile_size
#####################################################################################################################
function report_test_cfg()
{
    local -a variables_to_report=( "$@" )
    local -a components=( "${report_components[@]}")
    components+=( "model" )

    var_to_report_str="${variables_to_report[@]// /,}"
    header="component,${var_to_report_str// /,}"
    echo ${header}

    for component in "${components[@]}"; do
        row="${component}"
        for variable_to_report in "${variables_to_report[@]}"; do
            variable_to_report=${component}_${variable_to_report}
            variable_value=${!variable_to_report}
            [ "${variable_value}" = "" ] && variable_value="-"
            row+=",${variable_value}"
        done

        echo ${row}
    done
}

#####################################################################################################################
# Brief: Saves the test configuration in YAML format
# Arguments:
#   - $1: Space-separated list of model variable suffixes (resolved as model_<var>)
#   - $2: Space-separated list of component variable suffixes (resolved as <component>_<var>)
#   - $3: Space-separated list of split variable suffixes (resolved as model_split_<var>[i] and <component>_split_<var>[i])
# Global:
#   - test: Test name used as top-level YAML key
#   - splits: Number of splits to report
#   - report_components: Array with component names to include
#####################################################################################################################
function save_test_yaml()
{
    local model_variables="$1"
    local component_variables="${2:-}"
    local split_variables="${3:-}"
    local escaped_test_key=${test//\"/\\\"}
    local print_splits=false
    [ ${splits} -gt 1 ] && [ "${split_variables}" != "" ] && print_splits=true
    local print_components_vars=false
    [ ${#report_components[@]} -gt 0 ]  && (${print_splits} || [ "${component_variables}" != "" ]) && print_components_vars=true

    echo "\"${escaped_test_key}\":"
    spaces="  "

    for variable in ${model_variables}; do
        model_variable=model_${variable}
        echo "${spaces}${variable}: ${!model_variable}"
    done

    if ${print_splits}; then
        echo "${spaces}splits:"
        spaces+="  "
        for split in $(seq 1 ${splits}); do
            first=true
            for split_variable in ${split_variables}; do
                split_model_variable="model_split_${split_variable}[$((split-1))]"
                if ${first}; then
                    echo -n "${spaces}- "
                    first=false
                else
                    echo -n "${spaces}  "
                fi
                echo "${split_variable}: ${!split_model_variable}"
            done
        done
        spaces=${spaces%  }
    fi

    if ${print_components_vars}; then
        echo "${spaces}components:"

        spaces+="  "

        for component in "${report_components[@]}"; do
            echo "${spaces}${component}:"
            spaces+="  "

            for variable in ${component_variables}; do
                component_variable=${component}_${variable}
                echo "${spaces}${variable}: ${!component_variable}"
            done

            if ${print_splits}; then
                echo "${spaces}splits:"
                spaces+="  "
                for split in $(seq 1 ${splits}); do
                    first=true
                    for split_variable in ${split_variables}; do
                        split_model_variable="${component}_split_${split_variable}[$((split-1))]"
                        if ${first}; then
                            echo -n "${spaces}- "
                            first=false
                        else
                            echo -n "${spaces}  "
                        fi
                        echo "${split_variable}: ${!split_model_variable}"
                    done
                done
                spaces=${spaces%  }
            fi
            spaces=${spaces%  }
        done
    fi
}



function parse_multiprog()
{
    local multiprog_fn=$1
    unset job_geometry
    declare -Ag job_geometry

    while IFS= read -r line; do
        local procs_range=$(echo ${line} | awk -F ' ' '{print $1}')
        for exe_regex in "${!supported_exes[@]}"; do
            if echo ${line} | grep ${exe_regex} &> /dev/null; then
                curr_component=${supported_exes[${exe_regex}]}
                break
            fi
        done
        if [ -z ${job_geometry[${curr_component}]+word} ]; then
            job_geometry[${curr_component}]="${procs_range}"
        else
            job_geometry[${curr_component}]+=",${procs_range}"
        fi
    done < ${multiprog_fn}
}

function save_job_geometry()
{
    local f_ty=$1
    local fn=$2

    declare -A supported_exes
    supported_exes=(["nemo"]="nemo" ["oifs"]="oifs" ["runoff-mapper"]="rnfm" ["xios_server"]="xios" ["amip-reader"]="amipfr")

    parse_${f_ty} "${fn}"

    echo "unset job_geometry"
    echo "declare -Ag job_geometry"
    echo -n "job_geometry=("
    for component in "${!job_geometry[@]}"; do
        echo -n " [\"${component}\"]=\"${job_geometry[$component]}\"" 
    done
    echo -n ")"
}

#####################################################################################################################
# Brief: Create configuration string for paraver to ignore the non component processes
# Global:
#   component - Name of the component NOT to ignore
#   components_names - Array with the names of the different components
#   components_procs - Array with the processes of the different components in the same order as components_names
#####################################################################################################################
function create_threads_to_ignore() 
{
    local component=$1
    threads_to_ignore=""
    for curr_component in "${!job_geometry[@]}"; do
        component_ranges=${job_geometry[${curr_component}]}
        component_ranges=${component_ranges//,/ }
        for component_range in ${component_ranges}; do
            first_proc=${component_range//-*}   
            last_proc=${component_range//*-}
            if [ "${curr_component}" != "${component}" ]; then
                for j in $(seq "${first_proc}" "${last_proc}"); do
                    if [ "${threads_to_ignore}" != "" ]; then
                        threads_to_ignore="${threads_to_ignore}\n"
                    fi
                    threads_to_ignore="${threads_to_ignore}window_object thread { 0, $j, 1, { 0 } }"
                done
            fi
        done
    done
}

#####################################################################################################################
# Brief: Cut the whole model trace by its components
# Param: 
#   $1 - Job geometry dict definition file path
#   $2 - Trace file path
#####################################################################################################################
function cut_trace()
{
    local job_geometry_fn=$1
    local trace_file=$2
    local trace_name
    trace_name=$(basename "${trace_file}" .prv)

    # shellcheck source=/dev/null
    . "${job_geometry_fn}"

    for component_name in "${!job_geometry[@]}"; do
        local procs_range=${job_geometry[${component_name}]}

        cat << EOF > cutter.xml
<?xml version="1.0" encoding="UTF-8"?>
<config>
  <!-- CUTTER OPTIONS -->
  <cutter>
    <tasks>${procs_range}</tasks>
    <max_trace_size>0</max_trace_size>
    <by_time>0</by_time>
    <minimum_time>0</minimum_time>
    <maximum_time>0</maximum_time>
    <minimum_time_percentage>0</minimum_time_percentage>
    <maximum_time_percentage>100</maximum_time_percentage>
    <original_time>0</original_time>
    <break_states>1</break_states>
    <remove_first_states>0</remove_first_states>
    <remove_last_states>0</remove_last_states>
    <keep_events>0</keep_events>
  </cutter>
</config>
EOF
        paramedir -c cutter.xml "${trace_file}"

        mv "${trace_name}".chop*.prv "${component_name}".prv
        mv "${trace_name}".chop*.pcf "${component_name}".pcf
        mv "${trace_name}".chop*.row "${component_name}".row
    done
}