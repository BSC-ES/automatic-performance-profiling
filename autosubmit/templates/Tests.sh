#MEMBERS=HardwareBenchmarks CompilationEfficiency WeakScaling StrongScaling
source %ENV_SOURCES%
if [ "%MEMBER%" = "HardwareBenchmarks" ];
then
     source %INIDATA_ROOT%/hardware_benchmarks/param_bash.cfg
fi
if [ "%MEMBER%" = "CompilationEfficiency" ];
then
     source %INIDATA_ROOT%/compilation_efficiency/param_bash.cfg
fi
if [ "%MEMBER%" = "WeakScaling" ];
then
    source %INIDATA_ROOT%/weakscaling/param_bash.cfg
fi
if [ "%MEMBER%" = "StrongScaling" ];
then
    source %INIDATA_ROOT%/strong_scaling/param_bash.cfg
    mkdir -p %RUN_ROOT%
    mkdir -p %RUN_ROOT%/strong_scaling
fi
