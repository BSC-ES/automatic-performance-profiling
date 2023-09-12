current_member=%MEMBER%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
analysis_tools=${cfg}/trace_analysis/

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

paraver_configurations=$(find ${analysis_tools}/paraver_configurations/*)
for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    if [ $current_member = "StrongScaling" ]; then
        test_name_=${test_name}
    fi

    test_root=$run_root/$test_name_
    source $inidata/$test_name_/param_bash.cfg

    cd ${test_root}
    mkdir -p paraver_images
    trace_folders=$(find | grep trace_[0-9]*$)
    for trace_folder in ${trace_folders}
    do
        trace=${trace_folder}/${bin_name}.best_cut.prv
        n_cores=$(echo $trace_folder | sed 's/.*trace_//')
        mkdir -p paraver_images/${n_cores}
        export analysis_tools=$analysis_tools
        # ${cfg}/target/paraver.target ${trace} paraver_images/${n_cores} ${paraver_configurations}
        # ${cfg}/target/create_paraver_function_legend.target most_expensive_function_summary.csv ${trace} ${n_cores}
        # ${cfg}/target/create_paraver_legend.target ${trace} ${n_cores} ${paraver_configurations}
    done
done