# current_member=%MEMBER%
# run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
# inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
# cfg=%COMMON_PATH_LOCATIONS.CFG%
# analysis_tools=${cfg}/trace_analysis/
# model=%MODEL.NAME%

# if [ "$current_member" = "StrongScaling" ]; then
#     test_name="strong_scaling"
#     tests="%STRONGSCALING.TEST_NAMES%"
# elif [ "$current_member" = "CompilationEfficiency" ]; then
#     test_name="compilation_efficiency"
#     tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
# else 
#     test_name="weakscaling"
#     tests="%WEAKSCALING.TEST_NAMES%"
# fi

# tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
# tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)
# paraver_configurations=$(find ${analysis_tools}/paraver_configurations/*)
# for test in $tests
# do
#     test_name_=$test_name/$test

#     test_root=$run_root/$test_name_

#     cd ${test_root}
#     mkdir -p paraver_images
#     trace_folders=$(find | grep trace_[0-9]*$)
#     for trace_folder in ${trace_folders}
#     do
#         trace=${trace_folder}/${model}.best_cut.prv
#         n_cores=$(echo $trace_folder | sed 's/.*trace_//')
#         mkdir -p paraver_images/${n_cores}
#         export analysis_tools=$analysis_tools
#         # ${cfg}/target/paraver.target ${trace} paraver_images/${n_cores} ${paraver_configurations}
#         # ${cfg}/target/create_paraver_function_legend.target most_expensive_function_summary.csv ${trace} ${n_cores}
#         # ${cfg}/target/create_paraver_legend.target ${trace} ${n_cores} ${paraver_configurations}
#     done
# done

echo "Run the images.sh script from %CURRENT_ROOTDIR% to generate the Paraver images and then set this job as completed"
false 