model=%COMMON.MODEL%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

source $env_sources
source $inidata/hardware_benchmarks/param_bash.cfg
export PYTHONPATH=$PYTHONPATH:${project}

cd $run_root/hardware_benchmarks
mkdir -p OSU_RUN/IMAGE

for test in ${osu_tests[@]}
do
    test_name=${test##*/}
    python ${cfg}/benchmarks/OSU/OSU_test_plots.py -i OSU_RUN/DATA/${test_name}* -o OSU_RUN/IMAGE/
done

python ${cfg}/benchmarks/STREAM/STREAM_data_parser.py -i STREAM_RUN --png --png-output-name STREAM_RUN/${model}.png
