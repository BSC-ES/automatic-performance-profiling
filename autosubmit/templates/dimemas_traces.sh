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
elif [ "$current_member" = "CompilationEfficiency" ]; then
    test_name="compilation_efficiency"
    folders=%COMPILATION_EFFICIENCY.COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
else
    test_name="weakscaling"
    folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
fi

paradim_configurations=$(find ${analysis_tools}/paramdim_configurations/*)
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
        
        # dimemas.target
        ##################
        # Remove path and extension
        trace_name=${trace##*/}
        trace_name=${trace_name%.*}
        for cfg in ${dimemas_configurations[@]} 
        do
            # Remove the path and extension
            cfg_name=${cfg##*/}
            cfg_name=${cfg_name%.*}

            ${analysis_tools}/Dimemas -S 32k --dim ${trace} -p ${trace_name}_${cfg_name}.prv --config-file ${cfg}
        done
        ##################
    done
done