root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
magiccut=%CURRENT_ROOTDIR%/magiccut/magicCut

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

for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    source $inidata/$test_name_/param_bash.cfg
    if [ "$timestep_0" = "TRUE" ]; then
        magiccut_steps=$(echo ${trace_steps}+1 | bc)
    else
        magiccut_steps=${trace_steps}
    fi

    # Iterate over all trace_* folders
    cd $run_root/$test_name
    for trace_folder in trace_*
    do
        cd $trace_folder
        $magiccut ${bin_name}.prv ${magiccut_steps}
    done
done
