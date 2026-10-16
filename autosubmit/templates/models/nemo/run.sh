#!/bin/bash
#####################################################################################################################
# models/nemo/run.sh
# Brief: NEMO run implementation for the scalability tests.
#        Declared in the FILE list of the nemo scalability jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as run_<jobname>. scalability.sh sources it and calls run_nemo.
# Global (set by scalability.sh):
#   - Paths: compilation, cfg, platform, run_root, inidata, project
#   - Other: model, branch, test, test_name, arch_name, test_config, current_member
#####################################################################################################################

#####################################################################################################################
# Biref: Updates the namelists with the AS member configuration and runs NEMO
# Global:
#   - Paths: inidata, binaries, compilation, run_dir
#   - Other: test_name, nemo_nproc
#####################################################################################################################
function run_nemo()
{
    env_file=${cfg}/arch/${platform}/${model}/${arch_name}.env
    . ${env_file}

    local nemo_resolution="%EXPERIMENT.RESOLUTION%"
    local test_steps="%EXPERIMENT.TEST_STEPS%"
    local run_id="%CURRENT_NAME%"
    local nemo_nproc="%NUMPROC%"
    local output="%EXPERIMENT.OUTPUT%"
    local run_dir=${run_root}/${test_name}/run_${run_id}
    local model_sources=${compilation}/${model}_${branch}
    local configuration_folder=tests
    [ ${current_member} = "weakscaling" ] && nemo_resolution="%CURRENT_RESOLUTION%"
    [ ${current_member} = "tracing" ] && test_steps="%TRACING.TRACE_STEPS%"

    mkdir -p ${run_dir}
    chmod +w -R ${run_dir}
    rm -rf ${run_dir:?}/*
    cd ${run_dir} || exit

    cp ${inidata}/$test_name/* ${run_dir}
    ln -rsf ${inidata}/original ${run_dir}
    rsync -rv --exclude=.nc ${inidata} ${run_dir}

    cp --remove-destination ${model_sources}/${configuration_folder}/${arch_name}/EXP00/* ${run_dir}
    cp ${run_dir}/namelist_cfg_${nemo_resolution}_like ${run_dir}/namelist_cfg

    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg nn_itend    ${test_steps}
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_icebergs .false.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref ln_meshmask .false.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_timing   .true.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref nn_fsbc     1

    if [ ${output^^} = "FALSE" ] ; then \
        sed -i "s/^.*file_definition.*$$//g" ${run_dir}/context_nemo.xml ; \
    fi

    case "$current_member" in
        "weakscaling")
            . ${project}/configurations/model/${model}/resolutions.sh 
            local base_nproc="%WEAKSCALING.BASE_PROCS%"
            local base_resolution="%WEAKSCALING.BASE_RESOLUTION%"
            local base_grid_points=${nemo_resolutions[${base_resolution^^}]}
            local nemo_grid_points=${nemo_resolutions[${nemo_resolution^^}]}
            nemo_nproc=$((base_nproc*nemo_grid_points/base_grid_points))
            local queue="%HPCQUEUE%"
            local proj="%CURRENT_PROJ%"

            time srun -A ${proj} -q ${queue} -n $nemo_nproc ./nemo
        ;;
        "tracing")
            configure_extrae ${run_dir}
            create_trace_sh  ${run_dir}
            fd_enabled=%TRACING.EXTRAE.USER_FUNCTIONS.SAMPLING.ENABLED%
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
            generate_function_list.sh ./nemo extrae_functions.txt

            time srun -n ${nemo_nproc} ./trace.sh ./nemo || true
            ! [ -f nemo.pcf ] && exit
            rm -rf set-* ./*.nc
        ;;
        *)
            time srun -n ${nemo_nproc} ./nemo
        ;;
    esac
}
