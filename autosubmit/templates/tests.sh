#!/bin/bash
#####################################################################################################################
# tests.sh
# Brief: This creates the members necessary folders
#####################################################################################################################

run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%

if [ "%EXPERIMENT.APP_TESTS.WEAKSCALING.ENABLED%" == "TRUE" ]; then
    mkdir -p $run_root/weakscaling
fi
if [ "%EXPERIMENT.APP_TESTS.STRONGSCALING.ENABLED%" == "TRUE" ]; then
    mkdir -p $run_root/strong_scaling
fi
if [ "%EXPERIMENT.APP_TESTS.COMPILATION_EFFICIENCY.ENABLED%" == "TRUE" ]; then
    mkdir -p $run_root/compilation_efficiency
fi
if [ "%EXPERIMENT.APP_TESTS.TRACING.ENABLED%" == "TRUE" ]; then
    mkdir -p $run_root/tracing
fi
if [ "%EXPERIMENT.APP_TESTS.HARDWARE_BENCHMARKS.ENABLED%" == "TRUE" ]; then
    mkdir -p $run_root/hardware_benchmarks
fi