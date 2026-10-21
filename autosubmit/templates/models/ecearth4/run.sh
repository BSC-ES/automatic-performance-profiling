#!/bin/bash
#####################################################################################################################
# models/ecearth4/run.sh
# Brief: EC-Earth 4 run implementation for the scalability tests.
#        Declared in the FILE list of the ecearth4 scalability jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as run_<jobname>. scalability.sh sources it and calls run_ecearth4.
# Global (set by scalability.sh):
#   - Paths: compilation, cfg, platform, run_root, project
#   - Other: model, branch, test, test_name, arch_name, test_config, current_member
#####################################################################################################################

#####################################################################################################################
# Brief: Get all components AS variables to abstract run_ecearth4 function
# Global:
#   - Paths: project
#####################################################################################################################
function get_vars_ecearth4()
{
    yml_components="%MODEL.COMPONENTS%"
    components=($(bashify_array "${yml_components}"))

    inidata=%EXPERIMENT.INIDATA%

    if [ ${current_member} = "tracing" ]; then
        start_date="%TRACING.START_DATE%"
        end_date="%TRACING.END_DATE%"
        freq="%TRACING.FREQ%"
        interval="%TRACING.INTERVAL%"
    else
        start_date="%EXPERIMENT.START_DATE%"
        end_date="%EXPERIMENT.END_DATE%"
        freq="%EXPERIMENT.FREQ%"
        interval="%EXPERIMENT.INTERVAL%"
    fi 

    if [ ${current_member} = "weak_scaling" ]; then
        #shellcheck source=proj/auto-performance-profiling/configurations/model/nemo/resolutions.sh
        . ${project}/configurations/model/nemo/resolutions.sh 
        nemo_resolution=%CURRENT_NEMO_RESOLUTION%
        nemo_base_nproc=%WEAKSCALING.NEMO_BASE_PROCS%
        nemo_base_resolution=%WEAKSCALING.NEMO_BASE_RESOLUTION%
        base_grid_points=${nemo_resolutions[${nemo_base_resolution^^}]}
        nemo_grid_points=${nemo_resolutions[${nemo_resolution^^}]}
        nemo_nproc=$((nemo_base_nproc*nemo_grid_points/base_grid_points))

        #shellcheck source=proj/auto-performance-profiling/configurations/model/oifs/resolutions.sh
        . ${project}/configurations/model/oifs/resolutions.sh 
        oifs_resolution=%CURRENT_OIFS_RESOLUTION%
        oifs_base_nproc=%WEAKSCALING.OIFS_BASE_PROCS%
        oifs_base_resolution=%WEAKSCALING.OIFS_BASE_RESOLUTION%
        base_grid_points=${oifs_resolutions[${oifs_base_resolution^^}]}
        oifs_grid_points=${oifs_resolutions[${oifs_resolution^^}]}
        oifs_nproc=$((oifs_base_nproc*oifs_grid_points/base_grid_points))
    else 
        oifs_nproc="%CURRENT_OIFS_PROCS%"
        oifs_resolution="%EXPERIMENT.OIFS_RESOLUTION%"

        nemo_nproc="%CURRENT_NEMO_PROCS%"
        nemo_resolution="%EXPERIMENT.NEMO_RESOLUTION%"
    fi
    use_omp_threads="%USE_OMP_THREADS%"
    oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi
    
    xios_nproc="%CURRENT_XIOS_PROCS%"

    rnfm_nproc="%CURRENT_RNFM_PROCS%"
    amipfr_nproc="%CURRENT_AMIP_PROCS%"
}

#####################################################################################################################
# Brief: Updates the SE config file with the AS config and runs EC-Earth 4
# Global:
#   - Paths: run_root, compilation, project
#   - Other: test_name, model, number_of_cores, test, branch
#####################################################################################################################
function run_ecearth4()
{
    # shellcheck source=proj/auto-performance-profiling/cfg/utils/ecearth4/se.sh
    . ${cfg}/utils/ecearth4/se.sh

    get_vars_ecearth4

    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local run_dir=${test_dir}/run_${run_id}
    local src_dir=${compilation}/${arch_name}/sources/

    mkdir -p ${run_dir}
    rm -rf ${run_dir:?}/*

    cd ${compilation}/${arch_name}/scripts/runtime || exit

    local output="%EXPERIMENT.OUTPUT%"
    output=${output,,}
    if ${output}; then
        sed -i 's/enabled="false"/enabled="true"/g' templates/xios/file_def_*
        sed -i 's/enabled=".FALSE."/enabled=".TRUE."/g' templates/xios/field_def_*
    else
        sed -i 's/enabled="true"/enabled="false"/g' templates/xios/file_def_*
        sed -i 's/enabled=".TRUE."/enabled=".FALSE."/g' templates/xios/field_def_*
    fi

    local config_file=experiment_config-${test}-${run_id}.yml
    cp ${project}/configurations/model/${model}/experiment_config.yml.tmpl ${config_file}

    if [ ${current_member} = "tracing" ]; then
        local sed_run_dir=${run_dir}/run
    else
        local sed_run_dir=${run_dir}
    fi
    sed_run_dir=${sed_run_dir//\//\\\/}
    local sed_src_dir=${src_dir//\//\\\/}
    local ecearth_root=${compilation}/${arch_name}
    local sed_ecearth_root=${ecearth_root//\//\\\/}
    local sed_inidata=${inidata//\//\\\/}

    sed -i "s/COMPONENTS/${yml_components}/"         ${config_file}
    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
    sed -i "s/BASE_FOLDER/${sed_run_dir}/"           ${config_file}
    sed -i "s/SRC_FOLDER/${sed_src_dir}/"            ${config_file}
    sed -i "s/INIDATA/${sed_inidata}/"               ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/"     ${config_file}
    sed -i "s/OIFS_OMP_THREADS/${oifs_omp_threads}/" ${config_file}
    for component in "${components[@]}"; do
        [ "${component}" = "oasis" ] && continue
        component_nproc=${component}_nproc
        sed -i "s/${component^^}_PROCS/${!component_nproc}/" ${config_file}
    done
    sed -i "s/XIOS_PROCS/${xios_nproc}/"             ${config_file}
    sed -i "s/XIOS_PPN/${xios_nproc}/"               ${config_file}
    sed -i "s/FREQUENCY/${freq}/"                    ${config_file}
    sed -i "s/START_DATE/${start_date}/"             ${config_file}
    sed -i "s/END_DATE/${end_date}/"                 ${config_file}
    sed -i "s/INTERVAL_VAL/${interval}/"             ${config_file}
    sed -i "s/OIFS_RESOLUTION/${oifs_resolution}/"   ${config_file}
    sed -i "s/NEMO_RESOLUTION/${nemo_resolution}/"   ${config_file}


    case ${current_member} in
        "tracing")
            sed -i "s/run-srun-multiprog.sh/trace-run.sh/" ${config_file}

            fd_enabled=%TRACING.AUTOMATIC_USER_FUNCTIONS.ENABLED%
            fd_enabled=${fd_enabled,,}
            if ${fd_enabled}; then
                cp $run_root/$test_name/functions_dir/extrae_functions.txt ${run_dir}/
            else
                uf_list=($(bashify_array "%TRACING.EXTRAE.USER_FUNCTIONS.LIST%" true))
                if [ "${uf_list}" != "None" ]; then
                    echo -n > ${run_dir}/extrae_functions.txt
                    for user_function in "${uf_list[@]}"; do
                        echo "${user_function}" >> ${run_dir}/extrae_functions.txt
                    done
                else
                    cp ${cfg}/trace/model/${model}/extrae_functions.txt ${run_dir}/extrae_functions.txt
                fi
            fi

            create_trace_sh ${run_dir}

            configure_extrae ${run_dir}

            cp ${cfg}/trace/generate_function_list.sh ${run_dir}
            chmod +x ${run_dir}/generate_function_list.sh
        ;;
        "weak_scaling")
            # Set the queue and project only for weakscaling since it is run intercatively 
            # and it is not taking the AS platform configuration
            local queue="%HPCQUEUE%"
            local proj="%CURRENT_PROJ%"
            sed -i "s/QUEUE/${queue}/"                   ${config_file}
            sed -i "s/ACCOUNT/${proj}/"                  ${config_file}
        ;;
    esac


    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}.yml scriptlib/main.yml
}
