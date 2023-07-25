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

paradim_configurations=$(find ${analysis_tools}/paradim_configurations/*)
for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    if [ $current_member = "StrongScaling" ]; then
        test_name_=${test_name}
    fi
    source $inidata/$test_name_/param_bash.cfg
    cd ${run_root}/${test_name_}
    trace_folders=$(find | grep trace_[0-9]*$)
    for trace_folder in ${trace_folders}
    do
        source $inidata/$test_name_/param_bash.cfg
        trace=${trace_folder}/${bin_name}.best_cut.prv
        n_cores=$(echo $trace_folder | sed 's/.*trace_//')
        
        # paramdim.target
        ##################
        dimemas_traces=( dimemas_traces/${n_cores}*.prv )
        for trace in ${dimemas_traces[@]}
        do
            for cfg in ${paradim_configurations[@]}
            do
                ${analysis_tools}/paramedir ${trace} ${cfg}
                output_name=$(basename ${cfg/.cfg/} )
                new_name=${trace/.prv/}_${output_name}
                mv ${output_name} ${new_name}
            done
        done
        ##################
    done
done

