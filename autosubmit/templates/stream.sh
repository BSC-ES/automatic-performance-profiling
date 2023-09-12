set -xv
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%

source ${env_sources}
cd $run_root/hardware_benchmarks/STREAM_RUN
./stream > stream_%NUMPROC%.txt
