#!/bin/bash
#####################################################################################################################
# generate_paraver_images.sh
# Brief: Generate all the traces paraver images from the configuartions in 
#           ${cfg}/trace_analysis/paraver_configurations manually since X11 does not work in sbatch jobs in HPC2020
#           and MN5 atm
# Usage:
# ./generate_paraver_images.sh -c "components" [ -r root_dir -o -p "compare_cfgs" -d ] 
# "-c|--components 'components'          names of the components"
# "-r|--root-dir /root/dir               root relative/global path of the experiment"
# "-p|--compare-cfgs 'compare cfgs'      paraver cfgs to generate a compare view with"
# "-o|--overwrite                        overwrite images if already created"
# "-d|--debug                            display debug info"
# "-h|--help                             display this message"
#####################################################################################################################


function error()
{
    echo "[ERROR] $1" >&2 
}

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

        convert ${current_picture_name}.png \
            "(" ${image_to_append} -filter point -resize ${legend_scale}% ")" \
            -append ${current_picture_name}.png
    fi
    # Remove the rest
    rm -f *_legend.png
}

#####################################################################################################################
# Brief: Prints script usage 
#####################################################################################################################
function usage()
{
    echo Usage:
    echo ./generate_paraver_images.sh -c \"components\" [ -r root_dir -o -p \"compare_cfgs\" -d -l legend_scale ] 
    echo "-c|--components 'components'          names of the components"
    echo "-r|--root-dir /root/dir               root relative/global path of the experiment"
    echo "-p|--compare-cfgs 'compare cfgs'      paraver cfgs to generate a compare view with"
    echo "-l|--legend-scale 200                 percentage the legend is enlarged by (default 200)"
    echo "-o|--overwrite                        overwrite images if already created"
    echo "-d|--debug                            display debug info"
    echo "-h|--help                             display this message"
}

#####################################################################################################################
# Brief: Parses the script arguments 
# Param:
#   $@ - Command line arguments
#####################################################################################################################
function parse_args()
{
    local args=("$@")
    local defined_components=false

    root_dir=.
    components=""
    compare_cfgs=""
    legend_scale=200
    overwrite=false
    debug=false

    local i=0
    while [ $i -lt $# ]; do
        case ${args[$i]} in 
            "-c"|"--components")
                if [ $((i+1)) -ge $# ] || [[ ${args[$((i+1))]} = -[a-z] ]]; then error "Invalid args for ${args[$i]}"; usage; exit 1; fi
                components="${args[$((i+1))]}"
                defined_components=true   
                i=$((i+1))
            ;;
            "-r"|"--root-dir")
                if [ $((i+1)) -ge $# ] || [[ ${args[$((i+1))]} = -[a-z] ]]; then error "Invalid args for ${args[$i]}"; usage; exit 1; fi
                root_dir=${args[$((i+1))]}
                i=$((i+1))
            ;;
            "-o"|"--overwrite")
                overwrite=true
            ;;
            "-p"|"--compare-cfgs")
                if [ $((i+1)) -ge $# ] || [[ ${args[$((i+1))]} = -[a-z] ]]; then error "Invalid args for ${args[$i]}"; usage; exit 1; fi
                compare_cfgs="${args[$((i+1))]}"
                i=$((i+1))
            ;;
            "-l"|"--legend-scale")
                if [ $((i+1)) -ge $# ] || [[ ${args[$((i+1))]} = -[a-z] ]]; then error "Invalid args for ${args[$i]}"; usage; exit 1; fi
                legend_scale=${args[$((i+1))]}
                i=$((i+1))
            ;;
            "-d"|"--debug")
                debug=true
            ;;
            "-h"|"--help")
                usage
                exit 0
            ;; 
            *)
                echo "[WARNING] Unrecognised option ${args[$i]}"
            ;;
        esac 
        i=$((i+1))
    done

    if ! $defined_components; then error "Mandatory args not defined"; usage; exit 1; fi
}


#####################################################################################################################
# Start script
#####################################################################################################################

if ! which wxparaver &> /dev/null; then error "wxparaver command not found, load its corresponding module or add it to the PATH variable"; exit 1; fi

parse_args "$@"

cd ${root_dir} || exit
root_dir=$(pwd)
cfg=${root_dir}/*/cfg
analysis_tools=${cfg}/trace_analysis
paraver_configurations=$(find ${analysis_tools}/paraver_configurations/*)
log_file=${root_dir}/paraver_$(date +%s).log

. ${cfg}/utils/bash/utils.sh

for test in ${root_dir}/run/tracing/*; do
    # Get the slowest timestep for all components
    declare -A components_slowest_ts
    for component in $components; do components_slowest_ts[$component]=0; done
    for trace_folder in ${test}/run_*; do
        for component in $components; do 
            max_time=${components_slowest_ts[$component]}
            cur_time=$(cat ${trace_folder}/${component}_fastest_ts.txt | sed 's/\..*//')
            components_slowest_ts[$component]=$(( cur_time  > max_time ? cur_time : max_time )); 
        done
    done

    # Iterate traces to generate the Paraver images
    for trace_folder in ${test}/run_*; do
        [ -f ${trace_folder}/job_geometry.sh ] && . ${trace_folder}/job_geometry.sh

        trace_folder_basename=$(basename ${trace_folder})
        trace_id=$(echo ${trace_folder_basename} | sed 's/run_//')
        img_folder=${test}/paraver_images/${trace_id}
        mkdir -p ${img_folder}

        for component in ${components}; do
            threads_to_ignore=""
            ! [ -z ${job_geometry[@]} ] && create_threads_to_ignore ${component}

            cp ${paraver_configurations} ${img_folder}

            slowest_ts=${components_slowest_ts[$component]}
            cur_ts=$(cat ${trace_folder}/${component}_fastest_ts.txt | sed 's/\..*//')
            for paraver_cfg in ${img_folder}/*.cfg; do
                # Change time axis when creating a Paraver image to compare
                paraver_cfg_bn=$(basename ${paraver_cfg})
                paraver_cfg_bn=${paraver_cfg_bn//\.cfg}
                if echo "$compare_cfgs" | grep ${paraver_cfg_bn}; then
                    sed -i "s/window_end_time_relative.*/window_end_time_relative $(echo $slowest_ts / $cur_ts | bc -l)/" ${paraver_cfg}
                fi
                sed -i "s/window_object appl { 1, { All } }/${threads_to_ignore}/" ${paraver_cfg}
            done

            trace=${trace_folder}/${component}.best_cut.prv
            mod_paraver_configurations=(${img_folder}/*.cfg)
            
            # cd to the image folder to generate the images there
            cd ${img_folder} || exit
            for paraver_cfg in "${mod_paraver_configurations[@]}"; do
		        $debug && echo "[DEBUG] Generating $(basename ${paraver_cfg}) for ${trace}"
                image_filename=${img_folder}/$(basename ${paraver_cfg//\.cfg/})@$component.best_cut.png
                if ! $overwrite && [ -f $image_filename ]; then
                    $debug && echo "[DEBUG] Skipping $image_filename generation because already exists"
                    continue
                fi
                echo + wxparaver -i ${trace} ${paraver_cfg} &>> ${log_file}
                if wxparaver -i ${trace} ${paraver_cfg} &>> ${log_file}; then
                    create_paraver_legend ${paraver_cfg} ${trace}
		        else
		            error "Not generated $(basename ${paraver_cfg}) for ${trace}, check ${log_file}"
                fi
            done
        done
    done
done
