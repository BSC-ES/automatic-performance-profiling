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
# Brief: Compute the ecearth4 run variables Autosubmit cannot resolve at render time
#        (weak-scaling component procs, OIFS OMP threads)
# Global:
#   - Paths: project
#####################################################################################################################
function get_vars_ecearth4()
{
    if [ ${current_member} = "weakscaling" ]; then
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
        nemo_nproc="%CURRENT_NEMO_PROCS%"
    fi

    use_omp_threads="%USE_OMP_THREADS%"
    oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi
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

    mkdir -p ${run_dir}
    rm -rf ${run_dir:?}/*

    cd ${compilation}/${arch_name}/scripts/runtime || exit

    local output="%EXPERIMENT.OUTPUT%"
    output=${output,,}
    local xios_templates=${compilation}/${arch_name}/scripts/runtime/templates/xios
    if [ -d "${xios_templates}" ]; then
        if ${output}; then
            find "${xios_templates}" -name 'file_def_*' -exec sed -i 's/enabled="false"/enabled="true"/g' {} +
            find "${xios_templates}" -name 'field_def_*' -exec sed -i 's/enabled="\.FALSE\."/enabled=".TRUE."/g' {} +
        else
            find "${xios_templates}" -name 'file_def_*' -exec sed -i 's/enabled="true"/enabled="false"/g' {} +
            find "${xios_templates}" -name 'field_def_*' -exec sed -i 's/enabled="\.TRUE\."/enabled=".FALSE."/g' {} +
        fi
    fi

    local config_file=experiment_config-${test}-${run_id}.yml
    cp %HPCLOGDIR%/experiment_config.yml_${jobname} ${config_file}

    if [ ${current_member} = "tracing" ]; then
        local sed_run_dir=${run_dir}/run
    else
        local sed_run_dir=${run_dir}
    fi
    sed_run_dir=${sed_run_dir//\//\\\/}

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
    sed -i "s/BASE_FOLDER/${sed_run_dir}/"           ${config_file}
    sed -i "s/OIFS_OMP_THREADS/${oifs_omp_threads}/" ${config_file}
    sed -i "s/OIFS_PROCS/${oifs_nproc}/"             ${config_file}
    sed -i "s/NEMO_PROCS/${nemo_nproc}/"             ${config_file}

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
        "weakscaling")
            # Set the queue and project only for weakscaling since it is run intercatively 
            # and it is not taking the AS platform configuration
            local queue="%HPCQUEUE%"
            local proj="%CURRENT_PROJ%"
            sed -i "s/QUEUE/${queue}/"                   ${config_file}
            sed -i "s/ACCOUNT/${proj}/"                  ${config_file}
        ;;
    esac


    set +u
    local se_env_path
    se_env_path=$(se_conda_env "${arch_name}" "%MODEL.ARCH_NAMES%" "%MODEL.SE_CONDA_ENVS%") || exit 1
    se_env_${platform,,} "${se_env_path}"
    # The release's own component list wins when se deep-merges lists by appending, so it
    # is dropped for the experiment config to decide which components run.
    local base_config=experiment-config-base-${run_id}.yml
    grep -v '^ *components:' experiment-config-example.yml > ${base_config}

    # How a component grid is expressed depends on the release: up to 4.1.x
    # model_config.<component>.grid is an entry of its all_grids dictionary, from
    # 4.1.3 on it is the resolution name. Only this file knows which form applies.
    local component resolution
    if grep -q 'all_grids' ${compilation}/${arch_name}/scripts/runtime/scriptlib/config-oifs.yml 2>/dev/null; then
        for component in oifs nemo; do
            case ${component} in
                oifs) resolution="%CURRENT_OIFS_RESOLUTION%" ;;
                nemo) resolution="%CURRENT_NEMO_RESOLUTION%" ;;
            esac
            printf -- '- base.context:\n    model_config:\n      %s:\n        grid: !noparse "{{ model_config.%s.all_grids.%s }}"\n' \
                ${component} ${component} ${resolution} >> ${base_config}
        done
    else
        for component in oifs nemo; do
            case ${component} in
                oifs) resolution="%CURRENT_OIFS_RESOLUTION%" ;;
                nemo) resolution="%CURRENT_NEMO_RESOLUTION%" ;;
            esac
            printf -- '- base.context:\n    model_config:\n      %s:\n        grid: "%s"\n' \
                ${component} ${resolution} >> ${base_config}
        done
    fi

    se --nocolor --loglevel debug ${base_config} ${config_file} ../platforms/${arch_name}.yml scriptlib/main.yml
}
