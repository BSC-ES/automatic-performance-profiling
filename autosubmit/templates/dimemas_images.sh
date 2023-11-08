current_member=%MEMBER%
model=%MODEL.NAME%
cfg=%COMMON_PATH_LOCATIONS.CFG%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
analysis_tools=%COMMON_PATH_LOCATIONS.CFG%/trace_analysis/
platform=%COMMON.PLATFORM%

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
dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/${platform}/*)
paraver_cfg=` readlink -f ${cfg}/trace_analysis/cfgs/UserFunctions.cfg`
for test in $tests
do
    test_name_=$test_name/${test}
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
        for config in ${dimemas_configurations[@]}
        do
            trace_name=${config##*/}
            trace_name=${n_cores}_${trace_name%.*}.prv
            image_name=${trace_name%.*}.png
            echo  ${analysis_tools}/paraver -i ../dimemeas_traces/${trace_name} ${paraver_cfg}
            # ${analysis_tools}/paraver -i ../dimemas_traces/${trace_name} ${paraver_cfg} && rm -f *.code.png &&  mv *${image_name} ${image_name} &
        done
        ##################
    done
done