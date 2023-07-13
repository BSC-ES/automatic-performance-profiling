root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%CFG%
analysis_tools=${cfg}/trace_analysis/

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%
else
    test_name="weakscaling"
    folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
fi

paraver_configurations=$(find ${analysis_tools}/paraver_configurations/*)
for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    source $inidata/$test_name_/param_bash.cfg
    cd $run_root/$test_name
    for trace_folder in trace_*
    do
        source $inidata/$test_name_/param_bash.cfg
        trace=${folders}/${trace_folder}/${bin_name}.best_cut.prv
        n_cores=$(echo $trace_folder | sed 's/test_//')
        mkdir -p paraver_images/${n_cores}
        ${cfg}/target/paraver.target ${trace} $paraver_images/$(n_cores) ${paraver_configurations}
        ${cfg}/target/create_paraver_function_legend.target most_expensive_function_summary.csv ${trace} ${n_cores}
        ${cfg}/target/create_paraver_legend.target ${trace} ${n_cores} ${paraver_configurations}
    done
done