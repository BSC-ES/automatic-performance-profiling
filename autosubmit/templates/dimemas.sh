root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=%CFG%/trace_analysis/

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%
else
    test_name="weakscaling"
    folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
fi

dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/mn4/*)
for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    source $inidata/$test_name_/param_bash.cfg
    cd $run_root/$test_name
    mkdir -p dimemas_traces

    for trace_folder in trace_*
    do
        source $inidata/$test_name_/param_bash.cfg
        trace=${folders}/${trace_folder}/${bin_name}.best_cut.prv
        n_cores=$(echo $trace_folder | sed 's/test_//')
        dim_trace=dimemas_traces/${n_cores}.dim

    
        ${analysis_tools}/prv2dim ${trace} ${dim_trace}
        
        # dimemas.target
        ##################
        # Remove path and extension
        dim_trace_name=${dim_trace##*/}
        dim_trace_name=${dim_trace_name%.*}
        for cfg in ${dimemas_configurations[@]} 
        do
            # Remove the path and extension
            cfg_name=${cfg##*/}
            cfg_name=${cfg_name%.*}

            ${analysis_tools}/Dimemas -S 32k --dim ${trace} -p ${dim_trace_name}_${cfg_name}.prv --config-file ${cfg}
        done
        ##################
    done
done