#MEMBERS=HardwareBenchmarks CompilationEfficiency WeakScaling StrongScaling
source %ENV_SOURCES%
if [ "%MEMBER%" = "HardwareBenchmarks" ];
then
     source %INIDATA_ROOT%/hardware_benchmarks/param_bash.cfg
     mkdir -p %RUN_ROOT%
     mkdir -p %RUN_ROOT%/hardware_benchmarks
     mkdir -p %RUN_ROOT%/hardware_benchmarks/STREAM_RUN
     cp %COMPILATION_ROOT%/STREAM/stream %RUN_ROOT%/hardware_benchmarks/STREAM_RUN/stream
fi
if [ "%MEMBER%" = "CompilationEfficiency" ];
then
     source %INIDATA_ROOT%/compilation_efficiency/param_bash.cfg
     mkdir -p %RUN_ROOT%
     mkdir -p %RUN_ROOT%/compilation_efficiency
fi
if [ "%MEMBER%" = "WeakScaling" ];
then
    source %INIDATA_ROOT%/weakscaling/param_bash.cfg
    mkdir -p %RUN_ROOT%
    mkdir -p %RUN_ROOT%/weakscaling
fi
if [ "%MEMBER%" = "StrongScaling" ];
then
    source %INIDATA_ROOT%/strong_scaling/param_bash.cfg
    mkdir -p %RUN_ROOT%
    mkdir -p %RUN_ROOT%/strong_scaling
fi
