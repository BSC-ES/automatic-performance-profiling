root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${project}/cfg/trace_analysis/

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%
else 
    test_name="weakscaling"
    folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
fi

paramedir_configurations=$(find ${analysis_tools}/paramedir_configurations/*)
for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    source $inidata/$test_name_/param_bash.cfg
    cd $run_root/$test_name
    for trace_folder in trace_*
    do
        cd $trace_folder
        source $inidata/$test_name_/param_bash.cfg
        trace=${folders}/${trace_folder}/${bin_name}.best_cut.prv
        n_cores=$(echo $trace_folder | sed 's/test_//')

        # paramedir.target
        ##################
	    rm -f *.pm

        # Enter directory and process all paramedir configurations
        for cfg in ${paramedir_configurations[@]} 
        do
            ${analysis_tools}/paramedir ${trace} ${cfg} 
            # Get the extension
            cfg_extension=${cfg#*.}
            # Remove path
            cfg_name=${cfg##*/}
            # Remove the extension
            cfg_name=${cfg_name%.${cfg_extension}}
            # This is a 3D with function view
            if [[ ${cfg_extension} == "pm.cfg" ]] 
            then
                mv ${cfg_name}.pm ${n_cores}_${cfg_name}.pm
            # This is a normal csv which can be directly put in report
            else
                mv ${cfg_name} ${n_cores}_${cfg_name}.csv
            fi
        done
        ##################
    done
done

