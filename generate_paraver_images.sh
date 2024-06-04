#!/bin/bash
#####################################################################################################################
# images.sh
# Brief: Generate all the traces paraver images from the configuartions in 
#           ${cfg}/trace_analysis/paraver_configurations manually since X11 does not work in sbatch jobs in HPC2020
#           and MN5 atm
# Usage: ./images.sh experiment_root "components"
#####################################################################################################################


#####################################################################################################################
# Brief: Add paraver pictures and legends together
# Param: None
# Global variables:
#   components_names - Array with the components names
#   components_procs - Array with the components procs in the same order as in components_names
#   component: Current component not to ignore
#####################################################################################################################
function create_threads_to_ignore() 
{
    threads_to_ignore=""
    i=0
    first_proc=0
    while [ $i -lt ${#components_names[@]} ]; do
        component_procs=${components_procs[i]}
        last_proc=$((first_proc + component_procs - 1))
        if [ "${components_names[i]}" != "${component}" ]; then
            for j in $(seq $first_proc $last_proc); do
                if [ "${threads_to_ignore}" != "" ]; then
                    threads_to_ignore="${threads_to_ignore}\n"
                fi
                threads_to_ignore="${threads_to_ignore}window_object thread { 0, $j, 1, { 0 } }"
            done
        fi
        first_proc=$((last_proc + 1))
        i=$((i + 1))
    done
}

#####################################################################################################################
# Brief: Add paraver images and legends together
# Param:
#   $1 - Paraver configuration file *.cfg
#   $2 - Trace *.prv
#####################################################################################################################
function create_paraver_legend()
{
    cfg=$1
    cfg_name=${cfg##*/}
    cfg_name=${cfg%%.*}

    trace=$2
    trace_name=$(basename $trace)
    trace_name=${trace_name%.*}

    current_picture_name=${cfg_name}@${trace_name}

    if ! ls ${current_picture_name}* 1>/dev/null 2>&1; then
        echo $current_picture_name"* not found"
        return
    fi

    # Is a picture with gradient
    if ls ${current_picture_name}.w_legend.png 1>/dev/null 2>&1; then
        mv ${current_picture_name}.w_legend.png ${current_picture_name}.png
    # Is a graph with discrete legend
    elif ls ${current_picture_name}.code_legend.png 1>/dev/null 2>&1; then
        image_to_append=${current_picture_name}.code_legend.png
        convert ${current_picture_name}.png ${image_to_append} -append ${current_picture_name}.png
    fi
    # Remove the rest
    rm -f *_legend.png
}

if [ $# -lt 2 ]; then
    echo "Usage:"
    echo "./images.sh root_dir \"components\""
    echo "Example:"
    echo "./images.sh .. \"nemo oifs\""
    exit 1
fi

if ! which wxparaver &> /dev/null; then
    echo wxparaver command not found, load its corresponding module!
    exit 1
fi

root=$1
components=$2

cd ${root}
root=$(pwd)
cfg=$root/automatic_performance_profile/cfg
export analysis_tools=${cfg}/trace_analysis
paraver_configurations=$(find ${analysis_tools}/paraver_configurations/*)

for test in ${root}/run/tracing/*; do
    for trace_folder in ${test}/trace_*; do
        trace_folder_basename=$(basename ${trace_folder})
        trace_id=$(echo ${trace_folder_basename} | sed 's/trace_//')
        components_names=($(echo ${trace_folder_basename} | sed -E 's/(trace|[0-9])//g' | sed -E 's/_/ /g'))
        components_procs=($(echo ${trace_folder_basename} | sed -E 's/(trace|[a-z])//g' | sed -E 's/_/ /g'))

        img_folder=${test}/paraver_images/${trace_id}
        mkdir -p ${img_folder}

        for component in ${components}; do
            create_threads_to_ignore

            cp ${paraver_configurations} ${img_folder}

            for paraver_cfg in ${img_folder}/*.cfg; do
                sed -i "s/window_object appl { 1, { All } }/${threads_to_ignore}/" ${paraver_cfg}
            done

            trace=${trace_folder}/${component}.best_cut.prv
            mod_paraver_configurations=$(find ${img_folder} | grep cfg)
            cd ${img_folder}
            for paraver_cfg in ${mod_paraver_configurations}; do
                if wxparaver -i ${trace} ${paraver_cfg} &> /dev/null; then
                    create_paraver_legend ${paraver_cfg} ${trace}
                fi
            done
        done
    done
done
