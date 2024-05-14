current_member=%MEMBER%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
papi_counters_plots="%TRACING.PAPI_COUNTERS_PLOTS%"
components="%MODEL.COMPONENTS%"

input_files=""
reporter_params=""
case "$current_member" in
    "StrongScaling")
        test_name="strong_scaling"
        tests="%STRONGSCALING.TEST_NAMES%"
        tile_size="-"
        reporter_params="-f function_csv \
                        --functions-file functions_summary.txt \
                        --most_expensive_function_summary most_expensive_function_summary.csv \
                        --tracking-folder tracking \
                        --scatter-plots $(echo $papi_counters_plots | sed 's/ /:/g')"
        input_files="paramedir/*pm"
        ;;
    "CompilationEfficiency")
        test_name="compilation_efficiency"
        tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
        tile_size="-"
        ;;
    "WeakScaling")
        test_name="weakscaling"
        tests="%WEAKSCALING.TEST_NAMES%"
        tile_size="%WEAKSCALING.TILE_SIZE%"
        ;;
esac

case  "${model}" in
    "nemo")
        input_files="${input_files} scalability_*/*.timing.pkl"
        ;;
    "ecearth4")
        input_files="${input_files} scalability_*/lucia_lite_results/table.csv"
        reporter_params="${reporter_params} --coupling-folder coupling"
        ;;
esac

tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)
components=($(echo $components | sed "s/\[\|\]\|,//g"))
components=$(for v in "${components[@]}"; do echo "$v";done| sort| uniq| xargs)

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u


for test in $tests
do
    test_name_=$test_name/$test
    cd $run_root/$test_name_

    tmp_reporter_params="${reporter_params} -j ${test}.json \
                         --sypd-file ${test}_scaling.csv \
                         --sypd-plot ${test}_scaling.png"
    tile_size=($(echo $tile_size | sed "s/\[\|\]\|,//g"))

    echo processes_per_node='112' > param.cfg
    echo configuration_name=${test} >> param.cfg
    echo tile_size=\'${tile_size}\' >> param.cfg
    echo number_of_processes=\'$(ls | grep -E trace_ | sed 's/.*trace_//')\' >> param.cfg
    python3 ${cfg}/parser/collector.py \
                                    --input-files ${input_files} \
                                    --output-file ${test} \
                                    --param-file param.cfg \
                                    --components "${components}"
	python3 ${cfg}/parser/reporter.py ${tmp_reporter_params}
done