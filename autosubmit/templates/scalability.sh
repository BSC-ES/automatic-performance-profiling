#!/bin/bash
#####################################################################################################################
# scalability.sh
# Brief: This script runs the model to get the SYPD of the current procs config
#####################################################################################################################

###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH%
test="%CURRENT_TEST_NAME%"

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

report_components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

# Source the tracing utils script copied by Autosubmit to the LOG_expid dir.
# It provides configure_extrae, create_trace_sh and generate_extrae_user_functions.
jobname=%JOBNAME%
jobname=${jobname/%DEFAULT.EXPID%_}
. %HPCLOGDIR%/utils_${jobname}

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

    chmod +w -R ${run_dir}
    rm -rf ${run_dir:?}/*
    mkdir -p ${run_dir}
    cd ${run_dir} || exit

    # Link inidata
    cp ${inidata}/$test_name/* ${run_dir}
    ln -rsf ${inidata}/original ${run_dir}
    rsync -rv --exclude=.nc ${inidata} ${run_dir}

    # Copy everything from reference run_root
    cp --remove-destination ${model_sources}/${configuration_folder}/${arch_name}/EXP00/* ${run_dir}
    cp ${run_dir}/namelist_cfg_${nemo_resolution}_like ${run_dir}/namelist_cfg

    # Change namelist parameters
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg nn_itend    ${test_steps}
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_icebergs .false.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref ln_meshmask .false.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_timing   .true.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref nn_fsbc     1

    # Disable output
    if [ ${output^^} = "FALSE" ] ; then \
        sed -i "s/^.*file_definition.*$$//g" ${run_dir}/context_nemo.xml ; \
    fi

    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
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
            # Copy function.txt
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

    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
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
        # Overwrite resolution var with the current test resolution
        nemo_resolution=%CURRENT_NEMO_RESOLUTION%
        nemo_base_nproc=%WEAKSCALING.NEMO_BASE_PROCS%
        nemo_base_resolution=%WEAKSCALING.NEMO_BASE_RESOLUTION%
        base_grid_points=${nemo_resolutions[${nemo_base_resolution^^}]}
        nemo_grid_points=${nemo_resolutions[${nemo_resolution^^}]}
        nemo_nproc=$((nemo_base_nproc*nemo_grid_points/base_grid_points))

        #shellcheck source=proj/auto-performance-profiling/configurations/model/oifs/resolutions.sh
        . ${project}/configurations/model/oifs/resolutions.sh 
        # Overwrite resolution var with the current test resolution
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

    # Get AS variables
    get_vars_ecearth4

    # Remove and create the run directory
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local run_dir=${test_dir}/run_${run_id}
    local src_dir=${compilation}/${arch_name}/sources/

    mkdir -p ${run_dir}
    rm -rf ${run_dir:?}/*

    # Update all configuration according to AS variables
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


    # Specific members config
    case ${current_member} in
        "tracing")
            # Change launch script to the trace script
            sed -i "s/run-srun-multiprog.sh/trace-run.sh/" ${config_file}

            # Copy user functions list
            fd_enabled=%TRACING.USER_FUNCTIONS.SAMPLING.ENABLED%
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

            # Create and copy Extrae necessary files
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


    # Activate the SE enviroment and run
    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}.yml scriptlib/main.yml
}

function run_hpcw()
{
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local run_dir=${test_dir}/run_${run_id}
    local src_dir=${compilation}/${arch_name}
    local nemo_nproc="%NUMPROC%"
    local test_config="%EXPERIMENT.TEST_CONFIG%"

    rm -rf ${run_dir}
    mkdir -p ${run_dir}
    cd ${run_dir} || exit

    local log_dir="${test_dir}/hpcw_logs"
    local log_file="${log_dir}/nemo-${run_id}.log"
    mkdir -p "${log_dir}"
    rm -f "${log_file}"
    exec > >(tee -a "${log_file}") 2>&1

    export SETTE_DIR="${src_dir}/build/nemo/nemo_orca25/sette"
    export EXE_DIR="$PWD"

    . "${SETTE_DIR}/all_functions.sh"

    case ${test_config} in
        "orca025-medium")
            "${src_dir}/toolchains/job-stagein.sh" --strip-components=-1 \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/context_nemo.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/domain_def_nemo.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/field_def_nemo-ice.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/field_def_nemo-oce.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/file_def_nemo-ice.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/file_def_nemo-oce.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_precip_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_q_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_rain_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_rlds_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_rsds_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_slp_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_snow_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_t_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_u_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_v_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/ORCA025_ESACCI_CHLA_bicubic_new.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/ORCA025_JRA55_weights_bicubic.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/ORCA025_JRA55_weights_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/domain_cfg.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/domain_cfg_updated.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/domain_cfg_updated_new.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_CHLA_bicubic.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_CHLA_bicubic_new.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_CHLA_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_weights_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_JRA55_weights_bicubic.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_JRA55_weights_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/runoff_child.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/runoff_clim.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/runoff.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/WOA13_ORCA025_S_nomask.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/WOA13_ORCA025_T_nomask.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/grid_def_nemo.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/iodef.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_cfg" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_ice_cfg" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_ice_ref" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_ref"

            ln -sf "${src_dir}/build/nemo/nemo_orca25/cfgs/MY_ORCA25/BLD/bin/nemo.exe" nemo
            set_namelist namelist_ref sn_cfctl%l_runstat .true.
            set_namelist namelist_ref ln_timing   .true.
        ;;
        "orca1-like-small")
            rsync -rLv ${src_dir}/build/nemo/nemo_bench1/tests/BENCH/EXP00/ ${run_dir}/
            set_namelist namelist_cfg ln_timing   .true.
        ;;
    esac

    HPCW_SOURCE_DIR=${src_dir} HPCW_INSTALL="${src_dir}/build/nemo/install" . ${cfg}/arch/${platform}/${model}/${arch_name}.env

    TIME_FORMAT="@hpcw-time: %C: %Uuser %Ssystem %eelapsed %PCPU (%Xtext+%Ddata %Mmax)k"

    case "${current_member}" in
        "tracing")
            trace_steps="%TRACING.TRACE_STEPS%"
            set_namelist namelist_cfg nn_itend ${trace_steps}

            # Copy user functions list
            fd_enabled=%TRACING.USER_FUNCTIONS.SAMPLING.ENABLED%
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
            # Generate the function list file only when TRACING.EXTRAE.USER_FUNCTIONS.LIST is not set
            chmod +x ${cfg}/trace/generate_function_list.sh
            ${cfg}/trace/generate_function_list.sh ./nemo extrae_functions.txt


            # Create and copy Extrae necessary files
            create_trace_sh ${run_dir}

            configure_extrae ${run_dir}

            \time -f "$TIME_FORMAT" srun -n ${nemo_nproc} ./trace.sh ./nemo
            ;;
        *)
            steps="%EXPERIMENT.TEST_STEPS%"
            set_namelist namelist_cfg nn_itend ${steps}

            \time -f "$TIME_FORMAT" srun -n ${nemo_nproc} ./nemo
            ;;
    esac

    scontrol show JobId="${SLURM_JOB_ID}"
}

###################
# Start script
###################

current_member=$(echo "%TASKTYPE%" | grep -oE "COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS")
current_member=${current_member,,}

case "$current_member" in
    "compilation_efficiency")
        test_name=${current_member}/${test}
        arch_name=${test}
        ;;
    "strongscaling")
        test_name=${current_member}/${test}
        arch_name=%STRONGSCALING.ARCH_NAME%
        ;;
    "weakscaling")
        test_name=${current_member}/${test}
        arch_name=%WEAKSCALING.ARCH_NAME%
        ;;
    "tracing")
        test_name=${current_member}/${test}
        arch_name=%TRACING.ARCH_NAME%
        ;;
esac

run_${model}

