#!/bin/bash
#####################################################################################################################
# extrae.sh
# Brief: This script runs the model with Extrae in order to trace the PAPI counters, user functions and MPI events
#####################################################################################################################

###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
numproc=%NUMPROC%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH_LIST%
cfg=%COMMON_PATH_LOCATIONS.CFG%
test="%CURRENT_TEST_NAME%"
trace_steps="%TRACING.TRACE_STEPS%"
output="%MODEL.OUTPUT%"
papi_counters="%TRACING.PAPI_COUNTERS%"
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
platform=%DEFAULT.HPCARCH%

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
    cat << EOF > $trace
#!/bin/bash

if [ "\$EXTRAE_HOME" = "" ]; then
    EXTRAE_HOME=\$EXTRAE_DIR
fi

export EXTRAE_CONFIG_FILE=${run_directory}/extrae.xml
source \$EXTRAE_HOME/etc/extrae.sh

export LD_PRELOAD=\${EXTRAE_HOME}/lib/${extrae_lib}
export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
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
    local run_dir=${run_root}/${test_name}/trace_nemo_${numproc}
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
    cp --remove-destination ${compilation}/${model_sources}/${configuration_folder}/${arch_name}_trace/EXP00/* ${run_dir}
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
    cp $run_root/$test_name/functions_dir/extrae_functions.txt ${run_dir}/extrae_functions.txt

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

#####################################################################################################################
# Brief: Load the enviroment to run SE in MN5 
# Param: 
#   - $1: SE version 
#####################################################################################################################
function se_env_mn5()
{
    module purge
    module load miniconda/24.1.2
    source /apps/GPP/MINICONDA/24.1.2/etc/profile.d/conda.sh
    conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/ece4env-${1}
}

#####################################################################################################################
# Brief: Load the enviroment to run SE in HPC2020 
# Param: 
#   - $1: SE version 
#####################################################################################################################
function se_env_hpc2020()
{
    . /hpcperm/c3gm/repository/libs/micromamba/etc/profile.d/micromamba.sh
    micromamba activate ece4env-${1}
}

#####################################################################################################################
# Brief: Traces ECE4 execution using Extrae
# Global:
#   - Paths: cfg, run_root, compilation, project
#   - Other: test_name, test, model, arch_name, branch
#####################################################################################################################
function trace_ecearth4()
{
    local model_sources=${compilation}/${model}_${branch}
    local oifs_procs=%CURRENT_OIFS_PROCS%
    local nemo_procs=%CURRENT_NEMO_PROCS%
    local xios_procs=%CURRENT_XIOS_PROCS%
    local use_omp_threads="%USE_OMP_THREDS%"
    local oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi

    local run_id=xios_${xios_procs}_nemo_${nemo_procs}_rnfm_1_oifs_${oifs_procs}
    local run_dir=${run_root}/${test_name}/trace_${run_id}
    local src_dir=${compilation}/${arch_name}-prod/sources/
    mkdir -p ${run_dir}
    # Remove all run folder content just in case it was already created
    rm -rf ${run_dir:?}/*

    configure_extrae ${run_dir}

    cp ${cfg}/trace/generate_function_list.sh ${run_dir}

    cd ${compilation}/${arch_name}-trace/scripts/runtime || exit

    create_trace_sh ${run_dir}

    # Update all variable according to AS config
    local config_file=trace-${test}-${run_id}.yml
    cp ${project}/configurations/model/${model}/config.yml ${config_file}

    local sed_run_dir=${run_dir//\//\\\/}
    local sed_src_dir=$(echo ${src_dir} | sed 's_/_\\/_g')
    local ecearth_root=${compilation}/${arch_name}-trace
    local sed_ecearth_root=${ecearth_root//\//\\\/}

    local start_date=%TRACING.START_DATE%
    local end_date=%TRACING.END_DATE%
    local freq=%TRACING.FREQ%
    local interval=%TRACING.INTERVAL%

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
    sed -i "s/SRC_FOLDER/${sed_src_dir}/"            ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/"     ${config_file}
    sed -i "s/OIFS_PROCS/${oifs_procs}/"             ${config_file}
    sed -i "s/OIFS_OMP_THREADS/${oifs_omp_threads}/" ${config_file}
    sed -i "s/OIFS_PPN/${oifs_procs}/"               ${config_file}
    sed -i "s/NEMO_PROCS/${nemo_procs}/"             ${config_file}
    sed -i "s/NEMO_PPN/${nemo_procs}/"               ${config_file}
    sed -i "s/XIOS_PROCS/${xios_procs}/"             ${config_file}
    sed -i "s/XIOS_PPN/${xios_procs}/"               ${config_file}
    sed -i "s/FREQUENCY/${freq}/"                    ${config_file}
    sed -i "s/START_DATE/${start_date}/"             ${config_file}
    sed -i "s/END_DATE/${end_date}/"                 ${config_file}
    sed -i "s/INTERVAL_VAL/${interval}/"             ${config_file}

    # Change launch script
    sed -i "s/run-srun-multiprog.sh/trace-run.sh/" ${config_file}

    sed -i "s/RRULE:FREQ=MONTHLY;UNTIL=19900301;INTERVAL=1/RRULE:FREQ=DAILY;UNTIL=19900102;INTERVAL=1/" ${config_file}

    # Copy user functions list
    cp ${cfg}/trace/model/${model}/extrae_functions.txt ${run_dir}

    # Activate the SE enviroment and run
    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}-trace.yml scriptlib/main.yml

    # Reload modules to exit from SE
    source ${env_sources}

    cd ${run_dir} || exit

    actual_nemo_procs=$(grep "exceeds the maximum number of ocean subdomains" log/001/ocean.output | grep -oE "[0-9]+" || echo ${nemo_procs})

    components=("xios" "nemo" "rnf" "oifs")
    processors=($xios_procs $nemo_procs 1 $oifs_procs)

    cut_trace components processors "${model}.prv"

    rm -rf set-* ./*.nc
}

###################
# Start script
###################

source ${env_sources}

member="tracing"
test_name=${member}/${test}
arch_name=%TRACING.ARCH_NAME%
model_resolution=%TRACING.MODEL_RESOLUTION%       

trace_${model}
