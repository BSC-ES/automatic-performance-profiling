compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%

if [ "%MEMBER%" = "HardwareBenchmarks" ];
then
    mkdir -p $run_root/hardware_benchmarks/STREAM_RUN
    cp $compilation/STREAM/stream $run_folder/hardware_benchmarks/STREAM_RUN/stream
fi
if [ "%MEMBER%" = "CompilationEfficiency" ];
then
    mkdir -p $run_root/compilation_efficiency
fi
if [ "%MEMBER%" = "WeakScaling" ];
then
    mkdir -p $run_root/weakscaling
fi
if [ "%MEMBER%" = "StrongScaling" ];
then
    mkdir -p $run_root/strong_scaling
fi
