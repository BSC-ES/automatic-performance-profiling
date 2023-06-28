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
mkdir -p $binaries
source $env_sources
cd $compilation
#Load environment
source $env_sources
# End of experiment variables

source $inidata/strong_scaling/param_bash.cfg
# only once

#RUN_FOLDER =  hardware_benchmarks compilation_efficiency strong_scaling weakscaling

test_name=""
if [ "$current_member" = "CompilationEfficiency" ];
then
  test_name="compilation_efficiency"
  export test_name="compilation_efficiency"
  folders=%COMPILATION_EFFICIENCY.COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
elif [ "$current_member" = "StrongScaling" ];
then
  test_name="strong_scaling"
  export test_name="strong_scaling"
elif [ "$current_member" = "WeakScaling" ];
then
  test_name="weakscaling"
  export test_name="weakscaling"
  folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
fi
if [ "$current_member" = "WeakScaling" ] || [ "$current_member" = "CompilationEfficiency" ];
then
   for test in $folders
   do
        test_name_=$test_name"/"$(basename $test)
        mkdir -p $run_root/$test_name_/functions_dir
        cd $run_root/$test_name_/functions_dir
        cp $binaries/$test_name_/%COMMON.MODEL%*trace.exe $run_root/$test_name_/functions_dir/%COMMON.MODEL%
        model_exec=$run_root/$test_name_/functions_dir/%COMMON.MODEL% #?

        # Copy function and extrae configuration
        cp -r $project/cfg/generate_func_list/* $run_root/$test_name_/functions_dir/
        cp --remove-destination $compilation/$test_name_/${configuration_folder}/${configuration_name}_trace/EXP00/* $run_root/$test_name_/functions_dir


        $project/cfg/replace_namelist_parameter $run_root/$test_name_/functions_dir/namelist_cfg nn_itend 5
        $project/cfg/replace_namelist_parameter $run_root/$test_name_/functions_dir/namelist_cfg ln_icebergs .false.
        $project/cfg/replace_namelist_parameter $run_root/$test_name_/functions_dir/namelist_ref ln_meshmask .false.
        n_functions=%COMMON.TRACE_N_FUNCTIONS%

        # Load EXTRAE module and create wrapper
        module load gcc/8.1.0
        module load EXTRAE/3.7.1

        trace=./trace.sh
        #TODO check if new $(test_name) is well passed
        cat << EOF > $trace
#!/bin/bash

export EXTRAE_CONFIG_FILE=$run_root/$test_name_/functions_dir/extrae.xml
source \$EXTRAE_HOME/etc/extrae.sh

export LD_PRELOAD=\${EXTRAE_HOME}/lib/libmpitracecf.so
export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

\$*
EOF

        chmod +x ${trace}

        # List of function not to trace
        function_to_avoid=$project/cfg/generate_func_list/model/%COMMON.MODEL%/list_of_func_notto_trace.txt

        # Generate function list for xml
        function_file=extrae_functions.txt
        function_avg_dur_file=function_avg_dur.txt
        cat /dev/null > ${function_file}
        cat /dev/null > ${function_avg_dur_file}

        executable=${model_exec}
        # Spinup run
        time mpirun -genv I_MPI_DEBUG=4 -n %NUMPROC% ${trace} ${executable}
        $project/cfg/trace_analysis/paramedir ${executable}.prv sampling_user_function.cfg
        # Create list extrae_functions.txt
        set +xuve
        histo_file=sampling_user_function

        # Take function names
        read -a func_name < <(head -1 ${histo_file} | sed 's/\w*[..]\w*//g'| sed 's/\]//g' | sed 's/\[//g')
        # Take function average duration
        read -a func_avg_dur < <(grep Average ${histo_file} | awk '{$1=""; print $0}')

        # Save info to a file
        for i_func_name in `seq 0 $((${#func_name[@]}-1))`
        do
            echo  ${func_name[${i_func_name}]} ${func_avg_dur[$i_func_name]} >> ${function_avg_dur_file}
        done

        # Order data in decreasing order of average time
        cat ${function_avg_dur_file} > ${function_avg_dur_file}_tmp
        cat ${function_avg_dur_file}_tmp | sort -k 2 -nr  | column -t >  ${function_avg_dur_file}

        # Output first $n_function names
        awk '{print $1}' ${function_avg_dur_file} | grep '_mp_' | grep -v -f ${function_to_avoid} | head -${n_functions}> ${function_file}

        #rm ${function_avg_dur_file}_tmp
        #rm -rf *nc
   done
elif [ "$current_member" = "StrongScaling" ];
then
    mkdir -p $run_root/$test_name/functions_dir
    cd $run_root/$test_name/functions_dir
    cp $binaries/$test_name/%COMMON.MODEL%*trace.exe $run_root/$test_name/functions_dir/%COMMON.MODEL%
    model_exec=$run_root/$test_name/functions_dir/%COMMON.MODEL% #?

    # Copy function and extrae configuration
    cp -r $project/cfg/generate_func_list/* $run_root/$test_name/functions_dir/
    cp --remove-destination $compilation/$test_name/${configuration_folder}/${configuration_name}_trace/EXP00/* $run_root/$test_name/functions_dir


    $project/cfg/replace_namelist_parameter $run_root/$test_name/functions_dir/namelist_cfg nn_itend 5
    $project/cfg/replace_namelist_parameter $run_root/$test_name/functions_dir/namelist_cfg ln_icebergs .false.
    $project/cfg/replace_namelist_parameter $run_root/$test_name/functions_dir/namelist_ref ln_meshmask .false.
    n_functions=%COMMON.TRACE_N_FUNCTIONS%

    # Load EXTRAE module and create wrapper
    module load gcc/8.1.0
    module load EXTRAE/3.7.1

    trace=./trace.sh
    #TODO check if new $(test_name) is well passed
    cat << EOF > $trace
#!/bin/bash

export EXTRAE_CONFIG_FILE=$run_root/$test_name/functions_dir/extrae.xml
source \$EXTRAE_HOME/etc/extrae.sh

export LD_PRELOAD=\${EXTRAE_HOME}/lib/libmpitracecf.so
export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

\$*
EOF

    chmod +x ${trace}

    # List of function not to trace
    function_to_avoid=$project/cfg/generate_func_list/model/%COMMON.MODEL%/list_of_func_notto_trace.txt

    # Generate function list for xml
    function_file=extrae_functions.txt
    function_avg_dur_file=function_avg_dur.txt
    cat /dev/null > ${function_file}
    cat /dev/null > ${function_avg_dur_file}

    executable=${model_exec}
    # Spinup run
    time mpirun -genv I_MPI_DEBUG=4 -n %NUMPROC% ${trace} ${executable}
    $project/cfg/trace_analysis/paramedir ${executable}.prv sampling_user_function.cfg
    # Create list extrae_functions.txt
    set +xuve
    histo_file=sampling_user_function

    # Take function names
    read -a func_name < <(head -1 ${histo_file} | sed 's/\w*[..]\w*//g'| sed 's/\]//g' | sed 's/\[//g')
    # Take function average duration
    read -a func_avg_dur < <(grep Average ${histo_file} | awk '{$1=""; print $0}')

    # Save info to a file
    for i_func_name in `seq 0 $((${#func_name[@]}-1))`
    do
        echo  ${func_name[${i_func_name}]} ${func_avg_dur[$i_func_name]} >> ${function_avg_dur_file}
    done

    # Order data in decreasing order of average time
    cat ${function_avg_dur_file} > ${function_avg_dur_file}_tmp
    cat ${function_avg_dur_file}_tmp | sort -k 2 -nr  | column -t >  ${function_avg_dur_file}

    # Output first $n_function names
    awk '{print $1}' ${function_avg_dur_file} | grep '_mp_' | grep -v -f ${function_to_avoid} | head -${n_functions}> ${function_file}

    #rm ${function_avg_dur_file}_tmp
    #rm -rf *nc
fi