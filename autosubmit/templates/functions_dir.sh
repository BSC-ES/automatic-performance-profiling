#!/bin/bash
#####################################################################################################################
# functions_dir.sh
# Brief: This script runs a short model run to gather the most expensive user functions to be traced afterwards
#           using the extrae.sh script
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
current_member=tracing
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH%
n_functions=%TRACING.TRACE_N_FUNCTIONS%

source $env_sources

function functions_dir_nemo()
{
    configuration_folder=tests

    cd ${run_dir}
    model_exec=${run_dir}/$model
    
    cp --remove-destination $compilation/${model_sources}/${configuration_folder}/${arch_name}_trace/EXP00/* ${run_dir}
    cp ${run_dir}/namelist_cfg_${model_resolution}_like ${run_dir}/namelist_cfg

    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg nn_itend    5
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_icebergs .false.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref ln_meshmask .false.
    
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
    
    function_to_avoid=$project/cfg/generate_func_list/model/$model/list_of_func_notto_trace.txt
    
    function_file=extrae_functions.txt
    function_avg_dur_file=function_avg_dur.txt
    cat /dev/null > ${function_file}
    cat /dev/null > ${function_avg_dur_file}
    
    ulimit -c unlimited
    executable=${model_exec}
    time srun -n ${numproc} ${trace} ${executable}
   
    paramedir ${executable}.prv sampling_user_function.cfg
    set +xuve
    histo_file=sampling_user_function
    
    read -ra func_name < <(head -1 ${histo_file} | sed 's/\w*[..]\w*//g'| sed 's/\]//g' | sed 's/\[//g')
    read -ra func_avg_dur < <(grep -E "Average.*([0-9]+\.[0-9]+)+" ${histo_file} | sed 's/Average//g')
    
    for i_func_name in $(seq 0 $((${#func_name[@]}-1)))
    do
        echo ${func_name[${i_func_name}]} ${func_avg_dur[$i_func_name]} >> ${function_avg_dur_file}
    done
    
    cat ${function_avg_dur_file} > ${function_avg_dur_file}_tmp
    cat ${function_avg_dur_file}_tmp | sort -k 2 -nr  | column -t >  ${function_avg_dur_file}
    
    awk '{print $1}' ${function_avg_dur_file} | grep '_mp_' | grep -v -f ${function_to_avoid} | head -${n_functions}> ${function_file}
    
    rm -rf *nc
}

function functions_dir_ecearth4() 
{
#     cd ${compilation}/${arch_name}/runtime/se

#     trace=${run_dir}/trace.sh
#     cat << EOF > $trace
# #!/bin/bash

# export EXTRAE_CONFIG_FILE=${run_dir}/extrae.xml
# source \$EXTRAE_DIR/etc/extrae.sh

# export LD_PRELOAD=\${EXTRAE_DIR}/lib/libmpitracecf.so
# export LD_LIBRARY_PATH=\${EXTRAE_DIR}/lib/:\$LD_LIBRARY_PATH

# \$*
# EOF
#     chmod +x ${trace}

#     # Update all variable according to AS config
#     config_file=functions-dir-${test}-${numproc}.yml
#     cp ${project}/configurations/model/${model}/config.yml ${config_file}

#     # Change / to \/ for sed to work
#     sed_run_dir=$(echo $run_dir | sed 's_/_\\/_g')
#     ecearth_root=${compilation}/${arch_name}
#     sed_ecearth_root=$(echo $ecearth_root | sed 's_/_\\/_g')

#     oifs_procs=%TRACING.USER_FUNCTIONS_OIFS_PROCS%
#     nemo_procs=%TRACING.USER_FUNCTIONS_NEMO_PROCS%
#     xios_procs=%TRACING.USER_FUNCTIONS_XIOS_PROCS%

#     start_date=%TRACING.START_DATE%
#     end_date=%TRACING.END_DATE%
#     freq=%TRACING.FREQ%

#     sed -i "s/RUN_FOLDER/${sed_run_dir}/"        ${config_file}
#     sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/" ${config_file}
#     sed -i "s/OIFS_PROCS/${oifs_procs}/"         ${config_file}
#     sed -i "s/OIFS_PPN/${oifs_procs}/"           ${config_file}
#     sed -i "s/NEMO_PROCS/${nemo_procs}/"         ${config_file}
#     sed -i "s/NEMO_PPN/${nemo_procs}/"           ${config_file}
#     sed -i "s/XIOS_PROCS/${xios_procs}/"         ${config_file}
#     sed -i "s/XIOS_PPN/${xios_procs}/"           ${config_file}
#     sed -i "s/FREQUENCY/${freq}/"                ${config_file}
#     sed -i "s/START_DATE/${start_date}/"         ${config_file}
#     sed -i "s/END_DATE/${end_date}/"             ${config_file}

#     # Change launch script
#     sed -i "s/run-srun-multiprog.sh/trace-run.sh/" ${config_file}

#     # Activate the SE enviroment and run
#     set +u
#     module load conda
#     conda activate /hpcperm/c3et/conda/ece4
#     se --nocolor --loglevel debug ../../sources/se/platforms/${arch_name}.yml ${config_file} scriptlib/main.yml   

#     # Reload modules to exit from SE
#     source ${env_sources}

#     cd ${run_dir}

#     # Rename trace
#     mv xios_server.exe.prv ${model}.prv
#     mv xios_server.exe.pcf ${model}.pcf
#     mv xios_server.exe.row ${model}.row

#     paramedir ${model}.prv sampling_user_function.cfg
#     histo_file=sampling_user_function
#     function_file=extrae_functions.txt
#     function_avg_dur_file=function_avg_dur.txt
#     cat /dev/null > ${function_file}
#     cat /dev/null > ${function_avg_dur_file}
    
#     # Take function names
#     readarray -t func_name < <(head -1 sampling_user_function | grep -o '\[[^]]*\]' | sed 's/\]//g' | sed 's/\[//g' | sed 's/ //g')
#     # Take function average duration
#     read -a func_avg_dur < <(grep -E "Average.*([0-9]+\.[0-9]+)+" ${histo_file} | sed 's/Average//g')
    
#     # Save info to a file
#     for i_func_name in $(seq 0 $((${#func_name[@]}-1)))
#     do
#         echo  "${func_name[${i_func_name}]}" "${func_avg_dur[$i_func_name]}" >> ${function_avg_dur_file}
#     done
    
#     # Order data in decreasing order of average time
#     cat ${function_avg_dur_file} > ${function_avg_dur_file}_tmp
#     cat ${function_avg_dur_file}_tmp | sort -k 2 -nr >  ${function_avg_dur_file}
    
#     # Output first $n_function names
#     awk '{print $1}' ${function_avg_dur_file} | grep '_mp_' | head -n ${n_functions}> ${function_file}

#     cp ${cfg}/trace/model/${model}/extrae_functions.txt ${run_dir}
    echo Functions dir not used in ece4 yet
}

run_functions_dir() {
    test_name="tracing"
    arch_name=%TRACING.ARCH_NAME%
    model_resolution=%TRACING.RESOLUTION%

    tests="%TRACING.TEST_NAMES%"
    tests=${tests//[\[,\]]/}
    tests=$(for v in $tests; do echo "$v";done| sort| uniq| xargs)

    model_sources=${model}_${branch}

    for test in $tests
    do
        if [ "${current_member}" = "CompilationEfficiency" ]; then
            arch_name=${test}
        fi
        test_name_=${test_name}/${test}
        run_dir=$run_root/$test_name_/functions_dir

        mkdir -p ${run_dir}
        rm -rf ${run_dir:?}/*
        
        cp -r $project/cfg/generate_func_list/*                 ${run_dir}/
        cp -r $project/cfg/generate_func_list/model/${model}/*  ${run_dir}

        functions_dir_${model}
    done
}

###################
# Start script
###################

fd_enabled=%TRACING.EXTRAE.USER_FUNCTIONS.SAMPLING.ENABLED%
fd_enabled=${fd_enabled,,}

${fd_enabled} && run_functions_dir