current_member=%MEMBER%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
papi_counters_plots="%TRACING.PAPI_COUNTERS_PLOTS%"
components="%MODEL.COMPONENTS%"

if [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
    tests="%STRONGSCALING.TEST_NAMES%"
    tile_size="-"
elif [ "$current_member" = "CompilationEfficiency" ]; then
    test_name="compilation_efficiency"
    tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
    tile_size="-"
else
    test_name="weakscaling"
    tests="%WEAKSCALING.TEST_NAMES%"
    tile_size="%WEAKSCALING.TILE_SIZE%"
fi

tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)
components=($(echo $components | sed "s/\[\|\]\|,//g"))
components=$(for v in "${components[@]}"; do echo "$v";done| sort| uniq| xargs)

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

if [ "${model}" = "nemo" ]; then
    input_files="scalability_*/*.timing.pkl"
elif [ "${model}" = "ecearth4" ]; then
    input_files="scalability_*/lucia_lite_results/table.csv"
fi

input_files="${input_files} paramedir/*pm"

for test in $tests
do
    test_name_=$test_name/$test
    cd $run_root/$test_name_

    tile_size=($(echo $tile_size | sed "s/\[\|\]\|,//g"))

    echo processes_per_node='128' > param.cfg
    echo configuration_name=${test} >> param.cfg
    echo tile_size=\'${tile_size}\' >> param.cfg
    echo number_of_processes=\'$(ls | grep -E trace_ | sed 's/.*trace_//')\' >> param.cfg
    python3 ${cfg}/parser/collector.py \
                                    --input-files ${input_files} \
                                    --output-file ${test} \
                                    --param-file param.cfg \
                                    --components "${components}"

	python3 ${cfg}/parser/reporter.py \
                                    -j ${test}.json \
                                    --sypd-file ${test}_scaling.csv \
                                    --sypd-plot ${test}_scaling.png \
                                    -f function_csv \
                                    --functions-file functions_summary.txt \
                                    --most_expensive_function_summary most_expensive_function_summary.csv \
		          	                --scatter-plots "${papi_counters_plots}" \
    	                            --tracking-folder tracking
done