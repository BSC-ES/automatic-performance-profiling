###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
numproc=%NUMPROC%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH_LIST%

source $env_sources

function functions_dir_nemo()
{
    model_sources=${model}_${branch}
    configuration_folder=tests

    for test in $tests
    do
        if [ "${current_member}" = "CompilationEfficiency" ]; then
            arch_name=${test}
        fi
        test_name_=${test_name}/${test}
        run_dir=$run_root/$test_name_/functions_dir
        mkdir -p ${run_dir}
        cd ${run_dir}
        model_exec=${run_dir}/$model
        
        # Copy function and extrae configuration
        cp -r $project/cfg/generate_func_list/* ${run_dir}/
        cp --remove-destination $compilation/${model_sources}/${configuration_folder}/${arch_name}_trace/EXP00/* ${run_dir}
        cp ${run_dir}/namelist_cfg_${model_resolution}_like ${run_dir}/namelist_cfg

        ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg nn_itend    5
        ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_icebergs .false.
        ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref ln_meshmask .false.
        n_functions=%TRACING.TRACE_N_FUNCTIONS%
        
        # Load EXTRAE module and create wrapper
        module load gcc/8.1.0
        module load EXTRAE/latest
        
        trace=./trace.sh
        cat << EOF > $trace
#!/bin/bash

export EXTRAE_CONFIG_FILE=${run_dir}/extrae.xml
source \$EXTRAE_HOME/etc/extrae.sh

export LD_PRELOAD=\${EXTRAE_HOME}/lib/libmpitracecf.so
export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
        
        chmod +x ${trace}
        
        # List of function not to trace
        function_to_avoid=$project/cfg/generate_func_list/model/$model/list_of_func_notto_trace.txt
        
        # Generate function list for xml
        function_file=extrae_functions.txt
        function_avg_dur_file=function_avg_dur.txt
        cat /dev/null > ${function_file}
        cat /dev/null > ${function_avg_dur_file}
        
        executable=${model_exec}
        # Spinup run
        time mpirun -genv I_MPI_DEBUG=4 -n ${numproc} ${trace} ${executable}
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
        rm -rf *nc
    done
}

function functions_dir_ecearth4()
{
    # TODO
    echo TODO
}

if [ "${current_member}" = "CompilationEfficiency" ]; then
    test_name="compilation_efficiency"
    tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
    model_resolution=%COMPILATION_EFFICIENCY.MODEL_RESOLUTION%
elif [ "${current_member}" = "WeakScaling" ]; then
    test_name="weakscaling"
    tests="%WEAKSCALING.TEST_NAMES%"
    arch_name=%WEAKSCALING.ARCH_NAME%
    model_resolution=%WEAKSCALING.MODEL_RESOLUTION%
elif [ "${current_member}" = "StrongScaling" ]; then
    test_name="strong_scaling"
    tests="%STRONGSCALING.TEST_NAMES%"
    arch_name=%STRONGSCALING.ARCH_NAME%
    model_resolution=%STRONGSCALING.MODEL_RESOLUTION%
fi

tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)

functions_dir_${model}