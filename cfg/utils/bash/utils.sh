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
# Biref: Creates a csv file run_id-test_info.csv that contains the configuration of the test
# Global:
#   - Paths: run_dir
#   - Other: run_id, components, (component)_procs, (component)_resolution, (component)_curr_tile_size
#####################################################################################################################
function report_test_cfg()
{
    test_info_fn=${run_dir}/${run_id}-test_info.csv
    header="component,nproc,resolution"
    if [ "$current_member" = "WeakScaling" ]; then header+=",grid_points"; fi
    echo ${header} > ${test_info_fn}
    local model_resolution=""
    local model_gridpoints=""
    local model_nproc=0
    for component in "${report_components[@]}"; do
        component_procs="${component}_procs"
        component_resolution="${component}_resolution"
        row="${component},${!component_procs},${!component_resolution}"
        if [ "$current_member" = "WeakScaling" ]; then 
            component_grid_points="${component}_curr_tile_size"
            row+=",${!component_grid_points}"
        fi
        echo ${row} >> ${test_info_fn}
        actual_component_procs=${!component_procs}
        model_nproc=$((model_nproc+actual_component_procs))
    done

    echo "model,${model_nproc},-" >> ${test_info_fn}
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
        if [ "${job_geometry[${curr_component}]}" = "" ]; then
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