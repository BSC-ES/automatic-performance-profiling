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