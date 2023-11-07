###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
numproc=%NUMPROC%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
model=%MODEL.NAME%
cfg=%COMMON_PATH_LOCATIONS.CFG%
test="%CURRENT_TEST_NAME%"
trace_steps="%TRACING.TRACE_STEPS%"
output="%MODEL.OUTPUT%"
papi_counters="%TRACING.PAPI_COUNTERS%"

#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: Traces NEMO using extrae
#####################################################################################################################
function trace_nemo()
{
    configuration_folder=tests
    # Link data
    cp $inidata/$test_name_/* $run_root/$test_name_/trace_$numproc/
    #Doble check this #TODO not sure if it should be original after the member changes
    ln -rsf $inidata/original $run_root/$test_name_/trace_$numproc/
    rsync -rv --exclude=.nc $inidata $run_root/$test_name_/trace_$numproc/
    cd $run_root/$test_name_/trace_$numproc/

    run_folder=$run_root/$test_name_/trace_$numproc/
    number_of_cores=$numproc
    # Copy everything from reference folder
    cp --remove-destination $compilation/$test_name_/${configuration_folder}/${test}_trace/EXP00/* $run_root/$test_name_/trace_$numproc
    # Copy xios server
    cp $binaries/$test_name_/xios_server.exe $run_root/$test_name_/trace_$numproc/
    # Fix namelist parameters
    ${cfg}/replace_namelist_parameter $run_root/$test_name_/trace_$numproc/namelist_cfg nn_itend ${trace_steps}
    ${cfg}/replace_namelist_parameter $run_root/$test_name_/trace_$numproc/namelist_cfg ln_icebergs .false.
    ${cfg}/replace_namelist_parameter $run_root/$test_name_/trace_$numproc/namelist_ref ln_meshmask .false.
    # Set ice frequency to 1
    ${cfg}/replace_namelist_parameter $run_root/$test_name_/trace_$numproc/namelist_ref nn_fsbc 1
    # Disable output
    if [ "${output}" = FALSE ] ; then \
        sed -i "s/^.*file_definition.*$$//g" $run_root/$test_name_/trace_$numproc/context_nemo.xml ; \
    fi

    ### trace.target
    # Run extrae
    module load gcc/8.1.0
    module load EXTRAE/latest

    trace=trace.sh
    cat << EOF > $trace
#!/bin/bash

export EXTRAE_CONFIG_FILE=$run_root/$test_name_/trace_$numproc/extrae.xml
source \$EXTRAE_HOME/etc/extrae.sh

export LD_PRELOAD=\${EXTRAE_HOME}/lib/libmpitracecf.so
export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
    chmod +x ${trace}

    # Copy function.txt
    cp $run_root/$test_name_/functions_dir/extrae_functions.txt $run_root/$test_name_/trace_$numproc/extrae_functions.txt

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
    # TODO
    echo TRACE
}

###################
# Start script
###################
source ${env_sources}

if [ "$current_member" = "CompilationEfficiency" ];
then
    test_name="compilation_efficiency"
    test_name_=${test_name}/${test}
elif [ "$current_member" = "StrongScaling" ];
then
    test_name="strong_scaling"
    test_name_=${test_name}/${test}
elif [ "$current_member" = "WeakScaling" ];
then
    test_name="weakscaling"
    test_name_=${test_name}/${test}
fi

mkdir -p ${run_root}/${test_name_}/trace_${numproc}
cp ${cfg}/trace/* $run_root/$test_name_/trace_$numproc/

cd $run_root/$test_name_/trace_$numproc/
trace_${model}