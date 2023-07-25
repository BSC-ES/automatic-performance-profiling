root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${project}/cfg/trace_analysis/

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%
elif [ "$current_member" = "CompilationEfficiency" ]; then
    test_name="compilation_efficiency"
    folders=%COMPILATION_EFFICIENCY.COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
else 
    test_name="weakscaling"
    folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
fi

paramedir_configurations=$(find ${analysis_tools}/paramedir_configurations/*)
for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    if [ $current_member = "StrongScaling" ]; then
        test_name_=${test_name}
    fi
    source $inidata/$test_name_/param_bash.cfg
    mkdir -p  ${run_root}/${test_name_}/paramedir

    # WORKING DIRECTORY: paramedir folder in test's root folder
    cd ${run_root}/${test_name_}/paramedir
    rm -f *.pm

    trace_folders=$(find ${run_root}/${test_name_} | grep trace_[0-9]*$)
    for trace_folder in ${trace_folders}
    do
        source $inidata/$test_name_/param_bash.cfg
        trace=${trace_folder}/${bin_name}.best_cut.prv
        n_cores=$(echo $trace_folder | sed 's/.*trace_//')

        # paramedir.target
        ##################
        for cfg in ${paramedir_configurations[@]} 
        do
            ${analysis_tools}/paramedir ${trace} ${cfg} 
            # Get the extension
            cfg_extension=${cfg#*.}
            # Remove path
            cfg_name=${cfg##*/}
            # Remove the extension
            cfg_name=${cfg_name%.${cfg_extension}}
            # This is a 3D with function view
            if [[ ${cfg_extension} == "pm.cfg" ]] 
            then
                mv ${cfg_name}.pm ${n_cores}_${cfg_name}.pm
            # This is a normal csv which can be directly put in report
            else
                mv ${cfg_name} ${n_cores}_${cfg_name}.csv
            fi
        done
        ##################
    done
done

