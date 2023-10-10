current_member=%MEMBER%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
analysis_tools=${cfg}/trace_analysis/

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

source ${env_sources}
export PYTHONPATH=$PYTHONPATH:${project}

for test in $folders
do
    test_name_=$test_name"/"$(basename $test)
    source $inidata/$test_name_/param_bash.cfg
    cd $run_root/$test_name_
        
    python ${cfg}/parser/collector.py \
                                    --input-files scalability_*/*.timing.pkl paramedir/*pm dimemas_traces/*dm \
                                    --output-file ${configuration_name} \
                                    --param-file $inidata/$test_name_/param_bash.cfg

	python ${cfg}/parser/reporter.py \
                                    -j ${configuration_name}.json \
                                    --sypd-file ${configuration_name}_scaling.csv \
                                    --sypd-plot ${configuration_name}_scaling.png \
                                    -f function_csv \
                                    --functions-file functions_summary.txt \
                                    --most_expensive_function_summary most_expensive_function_summary.csv \
		          	                --scatter-plots "${papi_counters_plots}" \
				                    --dimemas-file dimemas.csv \
    	                            --tracking-folder tracking
done