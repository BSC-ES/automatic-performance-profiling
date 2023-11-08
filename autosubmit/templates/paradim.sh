current_member=%MEMBER%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${project}/cfg/trace_analysis/
model=%MODEL.NAME%

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
paradim_configurations=$(find ${analysis_tools}/paradim_configurations/*)
for test in $tests
do
    test_name_=$test_name/${test}
    cd ${run_root}/${test_name_}
    trace_folders=$(find | grep trace_[0-9]*$)
    for trace_folder in ${trace_folders}
    do
        trace=${trace_folder}/${model}.best_cut.prv
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

