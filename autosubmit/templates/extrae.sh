###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
numproc=%NUMPROC%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH_LIST%
cfg=%COMMON_PATH_LOCATIONS.CFG%
test="%CURRENT_TEST_NAME%"
trace_steps="%TRACING.TRACE_STEPS%"
output="%MODEL.OUTPUT%"
papi_counters="%TRACING.PAPI_COUNTERS%"
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

#####################################################################################################################
# Parameters: run_dir
# Purpose: Creates the extrae launch script
#####################################################################################################################
function create_trace_sh()
{
    local run_directory=$1
    trace=${run_dir}/trace.sh
    cat << EOF > $trace
#!/bin/bash

export EXTRAE_CONFIG_FILE=${run_directory}/extrae.xml
source \$EXTRAE_DIR/etc/extrae.sh

export LD_PRELOAD=\${EXTRAE_DIR}/lib/libmpitracecf.so
export LD_LIBRARY_PATH=\${EXTRAE_DIR}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
    chmod +x ${trace}
}

#####################################################################################################################
# Parameters: components_names components_processors trace_file
# Purpose: Cut the whole model trace by its components
#####################################################################################################################
function cut_trace()
{
    local -n components_names="$1"
    local -n components_processors="$2"
    trace_file=$3

    first_proc=1
    i=0
    while [ $i -lt ${#components_names[@]} ]; do
        component_procs=${components_processors[i]}
        last_proc=$((first_proc+component_procs-1))

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
# Path variables: TODO
# Other variables: TODO
# Purpose: Traces NEMO using extrae
#####################################################################################################################
function trace_nemo()
{
    run_dir=${run_root}/${test_name_}/trace_nemo_${numproc}
    mkdir -p ${run_dir}
    # Remove all run folder content just in case it was already created
    rm -rf ${run_dir}/*
    cp ${cfg}/trace/model/${model}/extrae.xml ${run_dir}
    cp ${cfg}/trace/generate_function_list.sh ${run_dir}

    cd ${run_dir}

    model_sources=${model}_${branch}
    configuration_folder=tests

    # Link data
    cp $inidata/$test_name_/* ${run_dir}
    #Doble check this #TODO not sure if it should be original after the member changes
    ln -rsf $inidata/original ${run_dir}
    rsync -rv --exclude=.nc $inidata ${run_dir}
    cd ${run_dir}

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
    module load gcc/8.1.0
    module load EXTRAE/latest
    
    create_trace_sh $run_dir

    # Copy function.txt
    cp $run_root/$test_name_/functions_dir/extrae_functions.txt ${run_dir}/extrae_functions.txt

    # Generate function list for xml
    ./generate_function_list.sh ./nemo extrae_functions.txt

    if [ "${papi_counters}" != "" ]; then
        papi_counters_str=""
        for papi_counter in ${papi_counters}; do
            if command -v papi_avail &> /dev/null && [ "$(papi_avail | grep ${papi_counter} |  awk -F ' ' '{print $3}')" != "Yes" ]; then
                echo Warning! ${papi_counter} is not available
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
    time mpirun -genv I_MPI_DEBUG=4 -n $numproc ./${trace} ./nemo

    # Clean a little bit
    rm -rf set-* *.nc
}

#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: Traces ECEARTH4 using extrae
#####################################################################################################################
function trace_ecearth4()
{
    oifs_procs=%CURRENT_OIFS_PROCS%
    nemo_procs=%CURRENT_NEMO_PROCS%
    xios_procs=%CURRENT_XIOS_PROCS%

    run_dir=${run_root}/${test_name_}/trace_xios_${xios_procs}_nemo_${nemo_procs}_rnfm_1_oifs_${oifs_procs}
    mkdir -p ${run_dir}
    # Remove all run folder content just in case it was already created
    rm -rf ${run_dir}/*
    cp ${cfg}/trace/model/${model}/extrae.xml ${run_dir}
    cp ${cfg}/trace/generate_function_list.sh ${run_dir}

    cd ${compilation}/${arch_name}-trace/runtime/se

    create_trace_sh ${run_dir}

    # Update all variable according to AS config
    config_file=trace-${test}-${numproc}.yml
    cp ${project}/configurations/model/${model}/config.yml ${config_file}

    sed_run_dir=$(echo ${run_dir} | sed 's_/_\\/_g')
    ecearth_root=${compilation}/${arch_name}-trace
    sed_ecearth_root=$(echo ${ecearth_root} | sed 's_/_\\/_g')

    start_date=%TRACING.START_DATE%
    end_date=%TRACING.END_DATE%
    freq=%TRACING.FREQ%
    interval=%TRACING.INTERVAL%

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"        ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/" ${config_file}
    sed -i "s/OIFS_PROCS/${oifs_procs}/"         ${config_file}
    sed -i "s/OIFS_PPN/${oifs_procs}/"           ${config_file}
    sed -i "s/NEMO_PROCS/${nemo_procs}/"         ${config_file}
    sed -i "s/NEMO_PPN/${nemo_procs}/"           ${config_file}
    sed -i "s/XIOS_PROCS/${xios_procs}/"         ${config_file}
    sed -i "s/XIOS_PPN/${xios_procs}/"           ${config_file}
    sed -i "s/FREQUENCY/${freq}/"                ${config_file}
    sed -i "s/START_DATE/${start_date}/"         ${config_file}
    sed -i "s/END_DATE/${end_date}/"             ${config_file}
    sed -i "s/INTERVAL_VAL/${interval}/"         ${config_file}

    # Change launch script
    sed -i "s/run-srun-multiprog.sh/trace-run.sh/" ${config_file}

    sed -i "s/RRULE:FREQ=MONTHLY;UNTIL=19900301;INTERVAL=1/RRULE:FREQ=DAILY;UNTIL=19900102;INTERVAL=1/" ${config_file}

    cd ${run_dir}

    # Copy user functions list
    cp ${cfg}/trace/model/${model}/extrae_functions.txt .

    cd ${compilation}/${arch_name}-trace/runtime/se

    # Activate the SE enviroment and run
    set +u
    module load conda
    conda activate /hpcperm/c3et/conda/ece4
    se --nocolor --loglevel debug ../../sources/se/platforms/${arch_name}-trace.yml ${config_file} scriptlib/main.yml

    # Reload modules to exit from SE
    source ${env_sources}

    cd ${run_dir}

    actual_nemo_procs=$(grep "exceeds the maximum number of ocean subdomains" log/001/ocean.output | grep -oE "[0-9]+" || echo ${nemo_procs})

    # Rename output trace
    mv xios_server.exe.prv ${model}.prv
    mv xios_server.exe.pcf ${model}.pcf
    mv xios_server.exe.row ${model}.row

    components=("xios" "nemo" "rnf" "oifs")
    processors=($xios_procs $nemo_procs 1 $oifs_procs)

    cut_trace components processors "${model}.prv"

    rm -rf set-* ./*.nc
}

###################
# Start script
###################
source ${env_sources}

if [ "$current_member" = "CompilationEfficiency" ];
then
    test_name="compilation_efficiency"
    test_name_=${test_name}/${test}
    arch_name=${test}
    model_resolution=%COMPILATION_EFFICIENCY.MODEL_RESOLUTION%
elif [ "$current_member" = "StrongScaling" ];
then
    test_name="strong_scaling"
    test_name_=${test_name}/${test}
    arch_name=%STRONGSCALING.ARCH_NAME%
    model_resolution=%STRONGSCALING.MODEL_RESOLUTION%
elif [ "$current_member" = "WeakScaling" ];
then
    test_name="weakscaling"
    test_name_=${test_name}/${test}
    arch_name=%WEAKSCALING.ARCH_NAME%
    model_resolution=%WEAKSCALING.MODEL_RESOLUTION%
fi

trace_${model}
