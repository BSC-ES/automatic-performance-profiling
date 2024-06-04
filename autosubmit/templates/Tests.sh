compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
member=%MEMBER%

case "$member" in 
    "HardwareBenchmarks")
        mkdir -p $run_root/hardware_benchmarks/STREAM_RUN
        cp $compilation/STREAM/stream $run_folder/hardware_benchmarks/STREAM_RUN/stream
        ;;
    "CompilationEfficiency")
        mkdir -p $run_root/compilation_efficiency
        ;;
     "WeakScaling")
        mkdir -p $run_root/weakscaling
        ;;
    "StrongScaling")
        mkdir -p $run_root/strong_scaling
        ;;
    "Tracing")
        mkdir -p $run_root/tracing
        ;;
esac