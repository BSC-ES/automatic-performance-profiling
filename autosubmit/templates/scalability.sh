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
env_sources=${cfg}/env/${platform}/environment.env
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH%
test="%CURRENT_TEST_NAME%"
platform="%DEFAULT.HPCARCH%"

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

report_components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

#####################################################################################################################
# Brief: Creates the extrae configuration file using the AS variables
# Parameters:
#   $1 - Directory where to store the extrae.xml
# Global:
#   - Paths: cfg
#####################################################################################################################
function configure_extrae()
{
    local run_directory=$1
    local extrae_xml=${run_directory}/extrae.xml
    cp ${cfg}/trace/extrae.xml.tmpl ${extrae_xml}

    local sed_extrae_home=%EXTRAE.HOME%
    if ! [ -d ${sed_extrae_home} ]; then
        sed_extrae_home=$EXTRAE_HOME
    fi
    sed_extrae_home=${sed_extrae_home//\//\\\/}
    local sed_user_functions_list=%EXTRAE.USER_FUNCTIONS.LIST%
    sed_user_functions_list=${sed_user_functions_list//\//\\\/}

    sed -i "s/HOME/${sed_extrae_home}/"                                     ${extrae_xml}
    sed -i "s/TRACE_NAME/%EXTRAE.TRACE_NAME%/"                              ${extrae_xml}

    sed -i "s/CALLERS_ENABLED/%EXTRAE.CALLERS.ENABLED%/"                    ${extrae_xml}
    sed -i "s/CALLERS_MPI_ENABLED/%EXTRAE.CALLERS.MPI.ENABLED%/"            ${extrae_xml}
    sed -i "s/CALLERS_MPI_LEVELS/%EXTRAE.CALLERS.MPI.LEVELS%/"              ${extrae_xml}
    sed -i "s/CALLERS_SAMPLING_ENABLED/%EXTRAE.CALLERS.SAMPLING.ENABLED%/"  ${extrae_xml}
    sed -i "s/CALLERS_SAMPLING_LEVELS/%EXTRAE.CALLERS.SAMPLING.LEVELS%/"    ${extrae_xml}

    sed -i "s/MPI_ENABLED/%EXTRAE.MPI.ENABLED%/"                            ${extrae_xml}
    sed -i "s/MPI_COUNTERS_ENABLED/%EXTRAE.MPI.COUNTERS.ENABLED%/"          ${extrae_xml}

    sed -i "s/OPENMP_ENABLED/%EXTRAE.OPENMP.ENABLED%/"                      ${extrae_xml}

    sed -i "s/USER_FUNCTIONS_ENABLED/%EXTRAE.USER_FUNCTIONS.ENABLED%/"      ${extrae_xml}
    sed -i "s/USER_FUNCTIONS_LIST/${sed_user_functions_list}/"              ${extrae_xml}

    sed -i "s/PAPI_COUNTERS_ENABLED/%EXTRAE.PAPI_COUNTERS.ENABLED%/"        ${extrae_xml}
    sed -i "s/PAPI_COUNTERS_LIST/%EXTRAE.PAPI_COUNTERS.LIST%/"              ${extrae_xml}
}

#####################################################################################################################
# Brief: Creates the extrae launch script trace.sh in the provided directory
# Parameters:
#   $1 - Directory where to store the trace.sh
#####################################################################################################################
function create_trace_sh()
{
    local run_directory=$1
    local trace=${run_directory}/trace.sh
    local extrae_lib="%EXTRAE.TRACING_LIB%"
    local extrae_home="%EXTRAE.HOME%"
    cat << EOF > $trace
#!/bin/bash

export EXTRAE_CONFIG_FILE=${run_directory}/extrae.xml
export EXTRAE_SKIP_AUTO_LIBRARY_INITIALIZE=1
source ${extrae_home}/etc/extrae.sh

export LD_PRELOAD=${extrae_home}/lib/${extrae_lib}
export LD_LIBRARY_PATH=${extrae_home}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
    chmod +x ${trace}
}

#####################################################################################################################
# Biref: Updates the namelists with the AS member configuration and runs NEMO
# Global:
#   - Paths: inidata, binaries, compilation, run_dir
#   - Other: test_name, nemo_nproc
#####################################################################################################################
function run_nemo()
{
    . ${env_sources}

    local nemo_resolution="%EXPERIMENT.RESOLUTION%"
    local test_steps="%EXPERIMENT.TEST_STEPS%"
    local run_id="%CURRENT_NAME%"
    local nemo_nproc="%NUMPROC%"
    local output="%EXPERIMENT.OUTPUT%"
    local run_dir=${run_root}/${test_name}/run_${run_id}
    local model_sources=${compilation}/${model}_${branch}
    local configuration_folder=tests
    [ ${current_member} = "WeakScaling" ] && nemo_resolution="%CURRENT_RESOLUTION%"
    [ ${current_member} = "Tracing" ] && test_steps="%TRACING.TEST_STEPS%"

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
        "WeakScaling")
            . ${project}/configurations/model/${model}/resolutions.sh 
            local base_procs="%WEAKSCALING.BASE_PROCS%"
            local base_resolution="%WEAKSCALING.BASE_RESOLUTION%"
            local base_grid_points=${nemo_resolutions[${base_resolution^^}]}
            local nemo_grid_points${nemo_resolutions[${nemo_resolution^^}]}
            nemo_nproc=$((base_nproc*nemo_grid_points/base_grid_points))
            local queue="%HPCQUEUE%"
            local proj="%CURRENT_PROJ%"

            time srun -A ${proj} -q ${queue} -n $nemo_nproc ./nemo
        ;;
        "Tracing")
            configure_extrae ${run_dir}
            create_trace_sh  ${run_dir}
            cp ${cfg}/trace/generate_function_list.sh ${run_dir}
            # Copy function.txt
            fd_enabled=%TRACING.USER_FUNCTIONS.SAMPLING.ENABLED%
            fd_enabled=${fd_enabled,,}
            if ${fd_enabled}; then
                cp $run_root/$test_name/functions_dir/extrae_functions.txt ${run_dir}/
            else
                cp $cfg/trace/model/nemo/extrae_functions.txt ${run_dir}/
            fi
            ./generate_function_list.sh ./nemo extrae_functions.txt

            time srun -n ${nemo_nproc} ./trace.sh ./nemo || true
            ! [ -f nemo.pcf ] && exit
            rm -rf set-* ./*.nc

            ( 
                echo "unset job_geometry"
                echo "declare -Ag job_geometry"
                echo "job_geometry=([\"nemo\"]=\"0-$((nemo_nproc-1))\")" 
            ) > job_geometry.sh
        ;;
        *)
            time srun -n ${nemo_nproc} ./nemo
        ;;
    esac

    # Rename timing output
    cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output

    model_nproc=%NUMPROC%
    variables_to_report="nproc resolution"
    [ ${current_member} = "WeakScaling" ] && variables_to_report+=" grid_points"

    report_test_cfg ${variables_to_report}
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

    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
    if [ ${current_member} = "Tracing" ]; then
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

    if [ ${current_member} = "WeakScaling" ]; then
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

    local config_file=experiment_config-${test}-${run_id}.yml
    cp ${project}/configurations/model/${model}/experiment_config.yml.tmpl ${config_file}

    if [ ${current_member} = "Tracing" ]; then
        local sed_run_dir=${run_dir}/run
    else
        local sed_run_dir=${run_dir}
    fi
    sed_run_dir=${sed_run_dir//\//\\\/}
    local sed_src_dir=${src_dir//\//\\\/}
    local ecearth_root=${compilation}/${arch_name}
    local sed_ecearth_root=${ecearth_root//\//\\\/}

    sed -i "s/COMPONENTS/${yml_components}/"         ${config_file}
    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
    sed -i "s/BASE_FOLDER/${sed_run_dir}/"           ${config_file}
    sed -i "s/SRC_FOLDER/${sed_src_dir}/"            ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/"     ${config_file}
    sed -i "s/OIFS_OMP_THREADS/${oifs_omp_threads}/" ${config_file}
    for component in "${components[@]}"; do
        [ "${component}" = "oasis" ] && continue
        component_nproc=${component}_nproc
        sed -i "s/${component^^}_PPN/${!component_nproc}/"   ${config_file}
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
        "Tracing")
            # Change launch script to the trace script
            sed -i "s/run-srun-multiprog.sh/trace-run.sh/" ${config_file}

            # Copy user functions list
            fd_enabled=%TRACING.USER_FUNCTIONS.SAMPLING.ENABLED%
            fd_enabled=${fd_enabled,,}
            if ${fd_enabled}; then
                cp $run_root/$test_name/functions_dir/extrae_functions.txt ${run_dir}/
            else
                cp $cfg/trace/model/ecearth4/extrae_functions.txt ${run_dir}/
            fi

            # Create and copy Extrae necessary files
            create_trace_sh ${run_dir}

            configure_extrae ${run_dir}

            cp ${cfg}/trace/generate_function_list.sh ${run_dir}
            chmod +x ${run_dir}/generate_function_list.sh
        ;;
        "WeakScaling")
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


    # Run postprocessing
    module purge
    . ${env_sources}

    case ${current_member} in
        "Tracing")
            # Moce and cut the trace by the model's components
            cd ${run_dir} || exit

            save_job_geometry multiprog run/multiprog.conf > job_geometry.sh

            mv run/*prv run/*pcf run/*row .

            cut_trace job_geometry.sh "${model}.prv"

            rm -rf set-* ./*.nc
        ;;
        *)
            local coupling_enabled="%STRONGSCALING.COUPLING_REPORT.ENABLED%"
            coupling_enabled=${coupling_enabled,,}
            if ${coupling_enabled}; then
                cd ${run_dir} || exit

                if echo "${components[@]}" | grep -w "nemo"; then
                    lucia_ts=$(cat time.step)
                else 
                    lucia_ts=$(cat log/001/NODE.001_01 | grep NSTOP | awk -F ' ' '{print $3}')
                fi

                local ignore_ini_ts="%STRONGSCALING.COUPLING_REPORT.LUCIA.IGNORE_INI_TS%"
                local ignore_end_ts="%STRONGSCALING.COUPLING_REPORT.LUCIA.IGNORE_END_TS%"
                local ignored_ts=$((ignore_ini_ts+ignore_end_ts))
                while ! python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average ${ignore_ini_ts} ${ignore_end_ts} ${lucia_ts} --generate_plots true > lucia.log && [ ${lucia_ts} -gt ${ignored_ts} ]; do
                    lucia_ts=$((lucia_ts-1))
                done

                if [ ${lucia_ts} -le ${ignored_ts} ]; then
                    echo "[ERROR] Could not generate coupling report using lucia, check the logs or disable the coupling report in the AS settings." >&2 
                    return 1
                else
                    coupling_dir=${test_dir}/coupling/${run_id}
                    mkdir -p ${coupling_dir}
                    cp ${run_dir}/lucia_lite_plots/*    ${coupling_dir}
                    cp ${run_dir}/lucia_lite_results/*  ${coupling_dir}
                fi
            fi

            echo "${components[@]}" | grep -w "oifs" && cp ${run_dir}/log/001/ifs.stat ${run_dir}/oifs-${run_id}-ifs.stat
            echo "${components[@]}" | grep -w "nemo" && cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output
        ;;
    esac

    model_nproc=%NUMPROC%
    variables_to_report="nproc resolution"
    [ ${current_member} = "WeakScaling" ] && variables_to_report+=" grid_points"
    ! ${coupling_enabled} && variables_to_report+=" sypd"

    report_test_cfg ${variables_to_report}

    return 0
}

###################
# Start script
###################

case "$current_member" in
    "CompilationEfficiency")
        member="compilation_efficiency"
        test_name=${member}/${test}
        arch_name=${test}
        ;;
    "StrongScaling")
        member="strong_scaling"
        test_name=${member}/${test}
        arch_name=%STRONGSCALING.ARCH_NAME%
        ;;
    "WeakScaling")
        member="weakscaling"
        test_name=${member}/${test}
        arch_name=%WEAKSCALING.ARCH_NAME%
        ;;
    "Tracing")
        member="tracing"
        test_name=${member}/${test}
        arch_name=%TRACING.ARCH_NAME%
        ;;
esac

run_${model}

