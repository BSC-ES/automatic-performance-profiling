current_member=%MEMBER%
model=%COMMON.MODEL%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${project}/cfg/trace_analysis

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%
fi

for test in $folders
do
    test_name_=$test_name"/"$(basename $test)

    source $inidata/$test_name_/param_bash.cfg
    test_root=$run_root/$test_name_
    mkdir -p ${test_root}/modelfactors
    trace_folders=$(find ${test_root} | grep trace_[0-9]*$)
    traces=$(find ${trace_folders} | grep ${bin_name}.best_cut.prv)
    cd ${test_root}/modelfactors
    ${analysis_tools}/modelfactors ${traces}
done

