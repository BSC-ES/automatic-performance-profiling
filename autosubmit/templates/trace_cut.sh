current_member=%MEMBER%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
magiccut=%CURRENT_ROOTDIR%/magiccut/magicCut
timestep_zero=%TRACING.TIMESTEP_ZERO%
trace_steps=%TRACING.TRACE_STEPS%

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    tests="%STRONGSCALING.TEST_NAMES%"
elif [ "$current_member" = "CompilationEfficiency" ]; then
    test_name="compilation_efficiency"
    tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
else
    test_name="weakscaling"
    tests="%WEAKSCALING.TEST_NAMES%"
fi

tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)

for test in $tests
do
    test_name_=$test_name/$test
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