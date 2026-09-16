#!/bin/bash
#####################################################################################################################
# tests.sh
# Brief: This creates the members necessary folders
#####################################################################################################################

run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
current_member=$(echo "%TASKTYPE%" | grep -oE "COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS")
current_member=${current_member,,}

case "$current_member" in 
    "hw_benchmarks")
        mkdir -p $run_root/hardware_benchmarks/STREAM_RUN
        ;;
    "compilation_efficiency")
        mkdir -p $run_root/compilation_efficiency
        ;;
     "weakscaling")
        mkdir -p $run_root/weakscaling
        ;;
    "strongscaling")
        mkdir -p $run_root/strong_scaling
        ;;
    "tracing")
        mkdir -p $run_root/tracing
        ;;
esac