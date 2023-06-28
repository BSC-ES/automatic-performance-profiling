#MEMBERS=HardwareBenchmarks CompilationEfficiency WeakScaling StrongScaling
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
if [ "%MEMBER%" = "HardwareBenchmarks" ];
then
     source $inidata/hardware_benchmarks/param_bash.cfg
     mkdir -p $run_root
     mkdir -p $run_root/hardware_benchmarks
     mkdir -p $run_root/hardware_benchmarks/STREAM_RUN
     cp $compilation/STREAM/stream $run_folder/hardware_benchmarks/STREAM_RUN/stream
fi
if [ "%MEMBER%" = "CompilationEfficiency" ];
then
     #source $inidata/compilation_efficiency/param_bash.cfg
     mkdir -p $run_root
     mkdir -p $run_root/compilation_efficiency
fi
if [ "%MEMBER%" = "WeakScaling" ];
then
    mkdir -p $run_root
    mkdir -p $run_root/weakscaling
    #for config in $inidata/weakscaling/*
    #do
    #    source $inidata/weakscaling/param_bash.cfg
    #done
fi
if [ "%MEMBER%" = "StrongScaling" ];
then
    source $inidata/strong_scaling/param_bash.cfg
    mkdir -p $run_root
    mkdir -p $run_root/strong_scaling
fi
