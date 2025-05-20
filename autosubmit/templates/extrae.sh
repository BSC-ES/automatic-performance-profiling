#!/bin/bash
#####################################################################################################################
# extrae.sh
# Brief: This script runs the model with Extrae in order to trace the PAPI counters, user functions and MPI events
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
numproc=%NUMPROC%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH%
cfg=%COMMON_PATH_LOCATIONS.CFG%
test="%CURRENT_TEST_NAME%"
trace_steps="%TRACING.TRACE_STEPS%"
output="%TRACING.OUTPUT%"
papi_counters="%TRACING.PAPI_COUNTERS%"
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
platform=%DEFAULT.HPCARCH%

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
    local is_py=${2:-false}
    local trace=${run_directory}/trace.sh
    local extrae_lib="%EXTRAE.TRACING_LIB%"
    local extrae_home="%EXTRAE.HOME%"
    if ${is_py}; then
        cat << EOF > $trace
#!/bin/bash

export PYTHONPATH=${extrae_home}/libexec/:\$PYTHONPATH
export EXTRAE_CONFIG_FILE=${run_directory}/extrae.xml
export EXTRAE_SKIP_AUTO_LIBRARY_INITIALIZE=1
source ${extrae_home}/etc/extrae.sh

export EXTRAE_SKIP_AUTO_LIBRARY_INITIALIZE=1
export LD_PRELOAD=${extrae_home}/lib/${extrae_lib}
export LD_LIBRARY_PATH=${extrae_home}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
    else
        cat << EOF > $trace
#!/bin/bash

export EXTRAE_CONFIG_FILE=${run_directory}/extrae.xml
source ${extrae_home}/etc/extrae.sh

export EXTRAE_SKIP_AUTO_LIBRARY_INITIALIZE=1
export LD_PRELOAD=${extrae_home}/lib/${extrae_lib}
export LD_LIBRARY_PATH=${extrae_home}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
    fi
    chmod +x ${trace}
}

#####################################################################################################################
# Brief: Cut the whole model trace by its components
# Param: 
#   $1 - Components names array name
#   $2 - Components processors array name
#   $3 - Trace file *.prv
#####################################################################################################################
function cut_trace()
{
    local -n components_names="$1"
    local -n components_processors="$2"
    local trace_file=$3

    local first_proc=1
    local i=0
    while [ $i -lt ${#components_names[@]} ]; do
        local component_procs=${components_processors[i]}
        local last_proc=$((first_proc+component_procs-1))

        cat << EOF > cutter.xml
<?xml version="1.0" encoding="UTF-8"?>
<config>
  <!-- CUTTER OPTIONS -->
  <cutter>
    <tasks>${first_proc}-${last_proc}</tasks>
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
        paramedir -c cutter.xml ${trace_file}

        mv ${model}.chop*.prv ${components_names[i]}.prv
        mv ${model}.chop*.pcf ${components_names[i]}.pcf
        mv ${model}.chop*.row ${components_names[i]}.row

        first_proc=$((last_proc+1))
        i=$((i+1))
    done
}

#####################################################################################################################
# Brief: Traces NEMO using Extrae
# Global:
#   - Paths: run_root, inidata, compilation
#   - Other: model, numproc, test_name, branch, arch_name, test_name
#####################################################################################################################
function trace_nemo()
{
    local run_id="%CURRENT_NAME%"
    local run_dir=${run_root}/${test_name}/trace_${run_id}
    mkdir -p ${run_dir}

    configure_extrae ${run_dir}

    cp ${cfg}/trace/generate_function_list.sh ${run_dir}

    cd ${run_dir} || exit

    local model_sources=${model}_${branch}
    local configuration_folder=tests

    # Link data
    cp $inidata/$test_name/* ${run_dir}
    #Doble check this #TODO not sure if it should be original after the member changes
    ln -rsf $inidata/original ${run_dir}
    rsync -rv --exclude=.nc $inidata ${run_dir}

    # Copy everything from reference folder
    cp --remove-destination ${compilation}/${model_sources}/${configuration_folder}/${arch_name}/EXP00/* ${run_dir}
    cp ${run_dir}/namelist_cfg_${model_resolution}_like ${run_dir}/namelist_cfg

    # Fix namelist parameters
    ${cfg}/replace_namelist_parameter ${run_dir}/namelist_cfg nn_itend    ${trace_steps}
    ${cfg}/replace_namelist_parameter ${run_dir}/namelist_cfg ln_icebergs .false.
    ${cfg}/replace_namelist_parameter ${run_dir}/namelist_ref ln_meshmask .false.
    ${cfg}/replace_namelist_parameter ${run_dir}/namelist_ref nn_fsbc     1

    # Disable output
    if [ "${output}" = FALSE ] ; then \
        sed -i "s/^.*file_definition.*$$//g" ${run_dir}/context_nemo.xml ; \
    fi

    ### trace.target
    # Run extrae
    create_trace_sh $run_dir

    # Copy function.txt
    fd_enabled=%TRACING.USER_FUNCTIONS.SAMPLING.ENABLED%
    fd_enabled=${fd_enabled,,}
    if ${fd_enabled}; then
        cp $run_root/$test_name/functions_dir/extrae_functions.txt ${run_dir}/
    else
        cp $cfg/trace/model/nemo/extrae_functions.txt ${run_dir}/
    fi

    # Generate function list for xml
    ./generate_function_list.sh ./nemo extrae_functions.txt

    if [ "${papi_counters}" != "" ]; then
        papi_counters_str=""
        for papi_counter in ${papi_counters}; do
            if command -v papi_avail &> /dev/null && [ "$(papi_avail | grep ${papi_counter} |  awk -F ' ' '{print $3}')" != "Yes" ]; then
                echo "Warning! ${papi_counter} is not available"
            fi
            if [ "${papi_counters_str}" = "" ]; then
                papi_counters_str=${papi_counter}
            else 
                papi_counters_str=${papi_counters_str}","${papi_counter}
            fi
        done
        sed -i "s/PAPI_TOT_INS,PAPI_TOT_CYC,PAPI_L3_TCM/${papi_counters_str}/" extrae.xml
    fi

    # Spinup run
    time srun -n $numproc ${run_dir}/trace.sh ./nemo

    # Clean a little bit
    rm -rf set-* ./*.nc
}

function get_vars_ecearth4()
{
    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
    oifs_procs="%CURRENT_OIFS_PROCS%"
    oifs_resolution="%EXPERIMENT.OIFS_RESOLUTION%"
    nemo_procs="%CURRENT_NEMO_PROCS%"
    nemo_resolution="%EXPERIMENT.NEMO_RESOLUTION%"
    use_omp_threads="%USE_OMP_THREADS%"
    oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi
    
    xios_procs="%CURRENT_XIOS_PROCS%"

    rnfm_procs=1
}

#####################################################################################################################
# Brief: Traces ECE4 execution using Extrae
# Global:
#   - Paths: cfg, run_root, compilation, project
#   - Other: test_name, test, model, arch_name, branch
#####################################################################################################################
function trace_ecearth4()
{
    . ${cfg}/utils/${model}/se.sh

    # Get AS variables
    get_vars_ecearth4

    local start_date="%TRACING.START_DATE%"
    local end_date="%TRACING.END_DATE%"
    local freq="%TRACING.FREQ%"
    local interval="%TRACING.INTERVAL%"

    # Remove and create the run directory
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local run_dir=${test_dir}/trace_${run_id}
    local src_dir=${compilation}/${arch_name}/sources/

    mkdir -p ${run_dir}
    rm -rf ${run_dir:?}/*

    cd ${compilation}/${arch_name}/scripts/runtime || exit

    # Create and copy Extrae necessary files
    create_trace_sh ${run_dir}

    configure_extrae ${run_dir}

    cp ${cfg}/trace/generate_function_list.sh ${run_dir}
    chmod +x ${run_dir}/generate_function_list.sh

    local config_file=trace-${test}-${run_id}.yml
    cp ${project}/configurations/model/${model}/experiment_config.yml.tmpl ${config_file}


    # Update all configuration according to AS variables
    local actual_run_dir=${run_dir}/run
    local sed_run_dir=${actual_run_dir//\//\\\/}
    local sed_src_dir=${src_dir//\//\\\/}
    local ecearth_root=${compilation}/${arch_name}
    local sed_ecearth_root=${ecearth_root//\//\\\/}

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
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

    # Activate the SE enviroment and run
    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}.yml scriptlib/main.yml

    # Post process trace
    module purge
    source ${env_sources}

    cd ${run_dir} || exit

    mv run/*prv run/*pcf run/*row .

    actual_nemo_procs=$(grep "exceeds the maximum number of ocean subdomains" log/001/ocean.output | grep -oE "[0-9]+" || echo ${nemo_procs})

    trace_components=("xios" "nemo" "rnf" "oifs")
    processors=($xios_procs $nemo_procs 1 $oifs_procs)

    cut_trace trace_components processors "${model}.prv"

    report_test_cfg

    rm -rf set-* ./*.nc
}

function trace_toy-model()
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

    # Create the member run_dir directory if it is the first Chunk
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local run_dir=${test_dir}/trace_${run_id}
    # Remove old run_dir if exists and create a new one
    if [ -d ${run_dir} ]; then
        rm -rf ${run_dir}
    fi
    mkdir -p ${run_dir}

    configure_extrae ${run_dir}
    create_trace_sh ${run_dir} true

    cp ${cfg}/trace/model/${model}/extrae_functions.txt ${run_dir}/extrae_functions_for_xml.txt

    # Copy the initial data files from inidata to run_dir
    cp -r ${inidata}/* ${run_dir}

    # Go to the rundir
    cd ${run_dir}
    
    toy_model_src=$(cat ${run_dir}/toy_model.py)
    echo "import pyextrae.sequential as pyextrae" > ${run_dir}/toy_model.py
    echo "$toy_model_src" >> ${run_dir}/toy_model.py

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

    # Modify the run_dir length
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
        echo "${curr_proc}-${curr_proc} ./trace.sh python3 toy_model.py --yaml_file_path ${yaml_config_file}" >> multiprog.conf
        curr_proc=$((curr_proc+1))
    done

    module purge
    module load oneapi/2023.2.0 hdf5 python pnetcdf netcdf

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

    processors=()
    for ((i=1; i<=number_of_components; i++)); do
        processors+=(1)
    done

    module load hdf5 python paraver

    cut_trace components processors "${model}.prv"

    python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average 1 1 $((lucia_ts-2))

    report_test_cfg
}


###################
# Start script
###################

source ${env_sources}

member="tracing"
test_name=${member}/${test}
arch_name=%TRACING.ARCH_NAME%
model_resolution=%EXPERIMENT.RESOLUTION%      
current_member="tracing"

trace_${model}
