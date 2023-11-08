current_member=%MEMBER%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
magiccut=%CURRENT_ROOTDIR%/magiccut/magicCut
timestep_zero=%TRACING.TIMESTEP_ZERO%
trace_steps=%TRACING.TRACE_STEPS%

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
    if [ "${timestep_zero}" = "TRUE" ]; then
        magiccut_steps=$(echo ${trace_steps}+1 | bc)
    else
        magiccut_steps=${trace_steps}
    fi
    
    # Iterate over all trace_* folders
    for trace_folder in ${run_root}/${test_name_}/trace_*
    do
        cd ${trace_folder}
        ${magiccut} ${model}.prv ${magiccut_steps}
    done
done
