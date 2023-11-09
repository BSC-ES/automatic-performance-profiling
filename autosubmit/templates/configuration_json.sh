current_member=%MEMBER%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
analysis_tools=${cfg}/trace_analysis/
papi_counters_plots="%TRACING.PAPI_COUNTERS_PLOTS%"

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    tests="%STRONGSCALING.TEST_NAMES%"
    tile_size=""
    n_procs="%WEAKSCALING.PROCESSORS%"
elif [ "$current_member" = "CompilationEfficiency" ]; then
    test_name="compilation_efficiency"
    tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
    tile_size=""
    n_procs="%WEAKSCALING.PROCESSORS%"
else
    test_name="weakscaling"
    tests="%WEAKSCALING.TEST_NAMES%"
    tile_size="%WEAKSCALING.TILE_SIZE%"
    n_procs="%WEAKSCALING.PROCESSORS%"
fi

tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

for test in $tests
do
    test_name_=$test_name/$test
    cd $run_root/$test_name_

    tile_size=($(echo $tile_size | sed "s/\[\|\]\|,//g"))

    echo processes_per_node='48' > param.cfg
    echo configuration_name=${test} >> param.cfg
    echo tile_size=\'${tile_size}\' >> param.cfg
    echo number_of_processes=\'$(ls | grep -E trace_ | sed 's/.*trace_//')\' >> param.cfg
    python3 ${cfg}/parser/collector.py \
                                    --input-files scalability_*/*.timing.pkl paramedir/*pm dimemas_traces/*dm \
                                    --output-file ${test} \
                                    --param-file param.cfg

	python3 ${cfg}/parser/reporter.py \
                                    -j ${test}.json \
                                    --sypd-file ${test}_scaling.csv \
                                    --sypd-plot ${test}_scaling.png \
                                    -f function_csv \
                                    --functions-file functions_summary.txt \
                                    --most_expensive_function_summary most_expensive_function_summary.csv \
		          	                --scatter-plots "${papi_counters_plots}" \
				                    --dimemas-file dimemas.csv \
    	                            --tracking-folder tracking
done