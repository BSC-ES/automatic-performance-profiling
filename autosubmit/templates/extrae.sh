# This script is used to run the trace tests

# Set the experiment variables
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
numproc=%NUMPROC%
mkdir -p $compilation
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
cfg=%COMMON_PATH_LOCATIONS.CFG%

mkdir -p $binaries
cd $compilation
source $env_sources

test_name=""
if [ $current_member = "CompilationEfficiency" ];
then
    test_name="compilation_efficiency"
    export test_name="compilation_efficiency"
    folders=%COMPILATION_EFFICIENCY.COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
elif [ $current_member = "StrongScaling" ];
then
    test_name="strong_scaling"
    export test_name="strong_scaling"
    folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%
elif [ $current_member = "WeakScaling" ];
then
    test_name="weakscaling"
    export test_name="weakscaling"
    folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
fi


for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    if [ $current_member = "StrongScaling" ]; then
        test_name_=${test_name}
    fi
    
    source $inidata/$test_name_/param_bash.cfg
    mkdir -p $run_root/$test_name_/trace_$numproc
    cp ${cfg}/trace/* $run_root/$test_name_/trace_$numproc/
    
    cd $run_root/$test_name_/trace_$numproc/
    #Link inidata
    cp $inidata/$test_name_/* $run_root/$test_name_/trace_$numproc/
    #Doble check this #TODO not sure if it should be original after the member changes
    ln -rsf $inidata/original $run_root/$test_name_/trace_$numproc/
    rsync -rv --exclude=.nc $inidata $run_root/$test_name_/trace_$numproc/
    cd $run_root/$test_name_/trace_$numproc/
    if [ $model = "nemo" ] || [ $model = "NEMO" ];
    then
        run_folder=$run_root/$test_name_/trace_$numproc/
        number_of_cores=$numproc
        # Copy everything from reference folder
        cp --remove-destination $compilation/$test_name_/${configuration_folder}/${configuration_name}_trace/EXP00/* $run_root/$test_name_/trace_$numproc
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
    fi
    ### trace.target
    # Run extrae
    module load gcc/8.1.0
    module load EXTRAE/3.7.1
    
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
    ./generate_function_list.sh ${bin_name} extrae_functions.txt
    
    # Spinup run
    time mpirun -genv I_MPI_DEBUG=4 -n $numproc ./${trace} ./${bin_name}
    
    # Clean a little bit
    rm -rf set-* *.nc
done