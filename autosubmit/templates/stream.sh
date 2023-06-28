#!/usr/bin/env bash
# Go to experiment folder
set -xv
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
mkdir -p $compilation
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
source %PARAMETERS_ENV_CONFIG.ENV_SOURCES%
cd $run_root/hardware_benchmarks/STREAM_RUN
./stream > stream_%NUMPROC%.txt
