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
#   - Other: test_name, nemo_procs
#####################################################################################################################
function run_nemo()
{
    . ${env_sources}

    local nemo_resolution="%EXPERIMENT.RESOLUTION%"
    local test_steps="%EXPERIMENT.TEST_STEPS%"
    local run_id="%CURRENT_NAME%"
    local nemo_procs="%NUMPROC%"
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
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref ln_timing   .true.
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
            local base_tile_size=${nemo_resolutions[${base_resolution^^}]}
            local nemo_curr_tile_size=${nemo_resolutions[${nemo_resolution^^}]}
            nemo_procs=$((base_procs*nemo_curr_tile_size/base_tile_size))
            local queue="%HPCQUEUE%"
            local proj="%CURRENT_PROJ%"

            time srun -A ${proj} -q ${queue} -n $nemo_procs ./nemo
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

            time srun -n ${nemo_procs} ./trace.sh ./nemo || true
            ! [ -f nemo.pcf ] && exit
            rm -rf set-* ./*.nc
        ;;
        *)
            time srun -n ${nemo_procs} ./nemo
        ;;
    esac

    # Rename timing output
    cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output

    # Create test info csv for the JSON
    report_test_cfg
}

#####################################################################################################################
# Brief: Get all components AS variables to abstract run_ecearth4 function
# Global:
#   - Paths: project
#####################################################################################################################
function get_vars_ecearth4()
{
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
        nemo_base_procs=%WEAKSCALING.NEMO_BASE_PROCS%
        nemo_base_resolution=%WEAKSCALING.NEMO_BASE_RESOLUTION%
        base_tile_size=${nemo_resolutions[${nemo_base_resolution^^}]}
        nemo_curr_tile_size=${nemo_resolutions[${nemo_resolution^^}]}
        nemo_procs=$((nemo_base_procs*nemo_curr_tile_size/base_tile_size))

        . ${project}/configurations/model/oifs/resolutions.sh 
        # Overwrite resolution var with the current test resolution
        oifs_resolution=%CURRENT_OIFS_RESOLUTION%
        oifs_base_procs=%WEAKSCALING.OIFS_BASE_PROCS%
        oifs_base_resolution=%WEAKSCALING.OIFS_BASE_RESOLUTION%
        base_tile_size=${oifs_resolutions[${oifs_base_resolution^^}]}
        oifs_curr_tile_size=${oifs_resolutions[${oifs_resolution^^}]}
        oifs_procs=$((oifs_base_procs*oifs_curr_tile_size/base_tile_size))
    else 
        oifs_procs="%CURRENT_OIFS_PROCS%"
        oifs_resolution="%EXPERIMENT.OIFS_RESOLUTION%"

        nemo_procs="%CURRENT_NEMO_PROCS%"
        nemo_resolution="%EXPERIMENT.NEMO_RESOLUTION%"
    fi
    use_omp_threads="%USE_OMP_THREADS%"
    oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi
    
    xios_procs="%CURRENT_XIOS_PROCS%"

    rnfm_procs=1
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

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
    sed -i "s/BASE_FOLDER/${sed_run_dir}/"           ${config_file}
    sed -i "s/SRC_FOLDER/${sed_src_dir}/"            ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/"     ${config_file}
    sed -i "s/OIFS_OMP_THREADS/${oifs_omp_threads}/" ${config_file}
    for component in "${report_components[@]}"; do
        component_procs=${component}_procs
        sed -i "s/${component^^}_PPN/${!component_procs}/"   ${config_file}
        sed -i "s/${component^^}_PROCS/${!component_procs}/" ${config_file}
    done
    sed -i "s/XIOS_PROCS/${xios_procs}/"             ${config_file}
    sed -i "s/XIOS_PPN/${xios_procs}/"               ${config_file}
    sed -i "s/FREQUENCY/${freq}/"                    ${config_file}
    sed -i "s/START_DATE/${start_date}/"             ${config_file}
    sed -i "s/END_DATE/${end_date}/"                 ${config_file}
    sed -i "s/INTERVAL_VAL/${interval}/"             ${config_file}
    sed -i "s/OIFS_RESOLUTION/${oifs_resolution}/"   ${config_file}
    sed -i "s/NEMO_RESOLUTION/${nemo_resolution}/"   ${config_file}


    # Specific members config
    if [ ${current_member} = "Tracing" ]; then
        #shellcheck source=proj/auto-performance-profiling/cfg/trace/utils.sh
        . ${cfg}/trace/utils.sh

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
    elif [ "$current_member" = "WeakScaling" ]; then
        # Set the queue and project only for weakscaling since it is run intercatively 
        # and it is not taking the AS platform configuration
        local queue="%HPCQUEUE%"
        local proj="%CURRENT_PROJ%"
        sed -i "s/QUEUE/${queue}/"                   ${config_file}
        sed -i "s/ACCOUNT/${proj}/"                  ${config_file}
    fi


    # Activate the SE enviroment and run
    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}.yml scriptlib/main.yml


    # Run postprocessing
    module purge
    . ${env_sources}

    if [ ${current_member} = "Tracing" ]; then
        # Moce and cut the trace by the model's components
        cd ${run_dir} || exit

        mv run/*prv run/*pcf run/*row .

        actual_nemo_procs=$(grep "exceeds the maximum number of ocean subdomains" log/001/ocean.output | grep -oE "[0-9]+" || echo ${nemo_procs})

        trace_components=("xios" "nemo" "rnf" "oifs")
        processors=($xios_procs $nemo_procs 1 $oifs_procs)

        cut_trace trace_components processors "${model}.prv"

        rm -rf set-* ./*.nc
    else
        local coupling_enabled="%STRONGSCALING.COUPLING.ENABLED%"
        coupling_enabled=${coupling_enabled,,}
        if ${coupling_enabled}; then
            cd ${run_dir} || exit
            lucia_ts=$(cat time.step)

            while ! python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average 1 1 ${lucia_ts} --generate_plots true > lucia.log && [ $lucia_ts -gt 0 ]; do
                lucia_ts=$((lucia_ts-1))
            done

            coupling_dir=${test_dir}/coupling/${run_id}
            mkdir -p ${coupling_dir}
            cp ${run_dir}/lucia_lite_plots/*    ${coupling_dir}
            cp ${run_dir}/lucia_lite_results/*  ${coupling_dir}
        fi

        cp ${run_dir}/log/001/ifs.stat ${run_dir}/oifs-${run_id}-ifs.stat
        cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output
    fi

    report_test_cfg
}

function run_toy-model()
{
    local COMP1_procs=%CURRENT_COMP1_PROCS%
    local COMP2_procs=%CURRENT_COMP2_PROCS%     
    local COMP3_procs=%CURRENT_COMP3_PROCS%
    local COMP1_resolution="1"
    local COMP2_resolution="2"  
    local COMP3_resolution="3"

    local CHUNKSIZE=%EXPERIMENT.CHUNKSIZE%
    local CHUNKSIZEUNIT="%EXPERIMENT.CHUNKSIZEUNIT%"

    local components=($(bashify_array "%MODEL.COMPONENTS%"))
    local model_sources=${compilation}/toy-model_${branch}
    source ${model_sources}/sources/ece3-toy-model/mn5.env

    # setup pyOasis environment
    source ${model_sources}/sources/oasis3-mct/generated/python/init.sh
    set -u

    # Check that inidata dir exists and is not empty, rise error and exit otherwise
    if [ ! -d ${inidata} ]; then
        echo "ERROR: ${inidata} does not exist"
        exit 1
    fi
    if [ ! -n "$(ls -A ${inidata})" ]; then
        echo "ERROR: ${inidata} is empty"
        exit 1
    fi

    # Set the number of components based on the count of YAML config files in the directory
    number_of_components=${#components[@]}

    # Create the member runtime directory if it is the first Chunk
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local run_dir=${test_dir}/scalability_${run_id}
    # Remove old runtime if exists and create a new one
    if [ -d ${run_dir} ]; then
        rm -rf ${run_dir}
    fi
    mkdir -p ${run_dir}

    # Copy the initial data files from inidata to runtime
    cp -r ${inidata}/* ${run_dir}

    # Go to the rundir
    cd ${run_dir} || exit

    # Print the values of the environment variables before the loop
    for ((i=1; i<=number_of_components; i++)); do
        nproc_var="COMP${i}_procs"
        echo "$nproc_var: ${!nproc_var}"
    done

    # Declare an array to store YAML filenames for each component
    declare -a component_yaml_files

    # Define the number of processors for each component from the environment variables
    total_nproc=0
    for ((i=1; i<=number_of_components; i++)); do
        yaml_file="${run_dir}/COMP${i}_toy_model.yaml"
        component_yaml_files+=("${yaml_file}")

        # Substitute the number of processors in the yaml file
        nproc_var="COMP${i}_procs"
        nproc="${!nproc_var}"
        sed -i "s/model_nproc: .*/model_nproc: ${nproc}/" "${yaml_file}"
        total_nproc=$((total_nproc+nproc))
    done

    # Modify the runtime length
    # Change CHUNKSIZEUNIT "hour" "day" "week" or "month" to the corresponding number of seconds
    if [ ${CHUNKSIZEUNIT} == "hour" ]; then
        CHUNKSIZEUNIT_seconds=3600
        lucia_ts=1.5
    elif [ ${CHUNKSIZEUNIT} == "day" ]; then
        CHUNKSIZEUNIT_seconds=86400
        lucia_ts=32
    elif [ ${CHUNKSIZEUNIT} == "week" ]; then
        CHUNKSIZEUNIT_seconds=604800
        lucia_ts=223
    elif [ ${CHUNKSIZEUNIT} == "month" ]; then
        CHUNKSIZEUNIT_seconds=2592000
        lucia_ts=960
    fi

    lucia_ts=$(echo "${lucia_ts}*${CHUNKSIZE}" | bc)
    # Run length time is the CHUNKSIZE multiplied by the number of chunks
    sim_length_seconds=$((CHUNKSIZE*CHUNKSIZEUNIT_seconds))

    # Change the run_length_sec in the yaml files for the value in sim_length_seconds
    for yaml_config_file in "${component_yaml_files[@]}"; do
        sed -i "s/run_length_sec: .*/run_length_sec: ${sim_length_seconds}/" "${yaml_config_file}"
    done
    # Change the run_length_sec in the namcouple file
    line_number=$(grep -n "RUNTIME" namcouple | cut -d: -f1)
    next_line_number=$((line_number+1))
    sed -i "${next_line_number}s/.*/   ${sim_length_seconds}/" namcouple

    # Prepare the run command
    run_command="srun --multi-prog multiprog.conf"
    curr_proc=0
    for yaml_config_file in "${component_yaml_files[@]}"; do
        echo "${curr_proc}-${curr_proc} python3 toy_model.py --yaml_file_path ${yaml_config_file}" >> multiprog.conf
        curr_proc=$((curr_proc+1))
    done

    # Run the model (in sequential)
    t0=$(date +%s)
    ${run_command}
    t1=$(date +%s)

    # Calculate the execution time and SYPD
    runtime_seconds=$((t1-t0))
    echo "Runtime: ${runtime_seconds} seconds"
    echo "Total number of processors: ${total_nproc}"
    sypd=$(echo "scale=2; ${sim_length_seconds}/365/${runtime_seconds}" | bc)
    echo "SYPD: ${sypd}"
    # get the CHSY by multiplying the number of processors by 24 and dividing by the SYPD
    chsy=$(echo "scale=2; ${total_nproc}*24/${sypd}" | bc)
    echo "CHSY: ${chsy}"

    module load hdf5 python

    python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average 1 1 $((lucia_ts-2)) --generate_plots true
    coupling_dir=${test_dir}/coupling/${run_id}
    mkdir -p ${coupling_dir}
    cp ${run_dir}/lucia_lite_results/*  ${coupling_dir}
    cp ${run_dir}/lucia_lite_plots/*  ${coupling_dir}

    report_test_cfg
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

