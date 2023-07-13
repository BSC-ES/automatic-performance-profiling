root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${project}/cfg/trace_analysis

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%
else 

for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    cd $run_root/$test_name
    mkdir -p modelfactors
    for trace_folder in trace_*
    do
        source $inidata/$test_name_/param_bash.cfg
        trace_path=${folders}/${trace_folder}/${bin_name}.best_cut.prv
        cd modelfactors
	    ${analysis_tools}/modelfactors ${trace_path}
        cd ..
    done
done

