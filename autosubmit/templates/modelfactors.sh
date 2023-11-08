current_member=%MEMBER%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${project}/cfg/trace_analysis

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    tests="%STRONGSCALING.TEST_NAMES%"
fi

tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)

for test in $tests
do
    test_name_=$test_name"/"$(basename $test)
    test_root=$run_root/$test_name_
    mkdir -p ${test_root}/modelfactors
    trace_folders=$(find ${test_root} | grep trace_[0-9]*$)
    traces=$(find ${trace_folders} | grep ${model}.best_cut.prv)
    cd ${test_root}/modelfactors
    ${analysis_tools}/modelfactors ${traces}
done

