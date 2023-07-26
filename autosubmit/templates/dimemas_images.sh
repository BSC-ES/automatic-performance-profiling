root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
cfg=%COMMON_PATH_LOCATIONS.CFG%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=%COMMON_PATH_LOCATIONS.CFG%/trace_analysis/

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

dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/mn4/*)
paraver_cfg=` readlink -f ${cfg}/trace_analysis/cfgs/UserFunctions.cfg`
for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    if [ $current_member = "StrongScaling" ]; then
        test_name_=${test_name}
    fi
    source $inidata/$test_name_/param_bash.cfg
    test_root=$run_root/$test_name_

    mkdir -p $test_root/dimemas_images
    cd $test_root/dimemas_images

    trace_folders=$(find  $test_root | grep trace_[0-9]*$)
    for trace_folder in ${trace_folders}
    do
        n_cores=$(echo $trace_folder | sed 's/.*trace_//')
        
        # dimemas.target
        ##################
        # Remove path and extension
        for cfg in ${dimemas_configurations[@]}
        do
            trace_name=${cfg##*/}
            trace_name=${n_cores}_${trace_name%.*}.prv
            image_name=${trace_name%.*}.png
            echo  ${analysis_tools}/paraver -i ../dimemeas_traces/${trace_name} ${paraver_cfg}
            # ${analysis_tools}/paraver -i ../dimemas_traces/${trace_name} ${paraver_cfg} && rm -f *.code.png &&  mv *${image_name} ${image_name} &
        done
        ##################
    done
done