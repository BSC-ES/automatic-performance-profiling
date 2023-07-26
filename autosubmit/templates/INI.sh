set -xuve
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
mkdir -p $compilation
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
cd %COMMON.EXP_ROOT%
source %PARAMETERS_ENV_CONFIG.ENV_SOURCES%
export PYTHONPATH=$PYTHONPATH:$(pwd)
mkdir -p inidata
cd inidata
declare -a folders
if [ "%MEMBER%" = "HardwareBenchmarks" ];
then
    folders+="hardware_benchmarks"
    mkdir -p hardware_benchmarks
    python %PARAMETERS_ENV_CONFIG.CONVERT_PARAM_FILE% -p %HW_BENCHMARKS.HW_BENCHMARKS_PARAMETERS_ROOT% -o $inidata/hardware_benchmarks/param_bash.cfg
fi
if [ "%MEMBER%" = "CompilationEfficiency" ];
then
    folder="compilation_efficiency"
    mkdir -p compilation_efficiency
    multi_config=true
    for config in %COMPILATION_EFFICIENCY.COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*; do
        folders+=("$folder/${config##*/}")
        mkdir -p compilation_efficiency/${config##*/}
        python %PARAMETERS_ENV_CONFIG.CONVERT_PARAM_FILE% -p $config -o $inidata/compilation_efficiency/${config##*/}/param_bash.cfg
    done
fi
if [ "%MEMBER%" = "WeakScaling" ];
then
    folder="weakscaling"
    multi_config=true
    mkdir -p weakscaling
    for config in %WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*; do
        folders+=("$folder/${config##*/}")
        mkdir -p weakscaling/${config##*/}
        python %PARAMETERS_ENV_CONFIG.CONVERT_PARAM_FILE% -p $config -o $inidata/weakscaling/${config##*/}/param_bash.cfg
    done
fi
if [ "%MEMBER%" = "StrongScaling" ];
then
    folders+="strong_scaling"
    mkdir -p strong_scaling
    python %PARAMETERS_ENV_CONFIG.CONVERT_PARAM_FILE% -p %STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION% -o $inidata/strong_scaling/param_bash.cfg
fi
###
#Data
if [ "%MEMBER%" != "HardwareBenchmarks" ];
then
    #Load parameter configuration depending on the test
    for folder in "${folders[@]}";
    do
        source $inidata/$folder/param_bash.cfg
        # Clone model
        #if [ "%COMMON.MODEL%" = "nemo" ];
        #then
        #nemo_source.target
        # if the mirror has not been cloned yet
        #    if [[ ! -d nemo_mirror ]]
        #    then
        #      $project/cfg/clone_nemo.sh $compilation/nemo_mirror ${model_branch}
        #    fi
        #    ln -sf $compilation/nemo_mirror $compilation/${model}_source
        #fi
        
        if [[ ! -z ${configuration_resolution+x} ]]
        then
            # It is BENCH, copy the namelist into the configuration namelist_cfg
            cp $project/cfg/utils/%COMMON.MODEL%/iodef.xml  $inidata/$folder
            cp $project/cfg/utils/%COMMON.MODEL%/context_%COMMON.MODEL%.xml  $inidata/$folder
        else
            # Link inidata to each model
            ln -rsf original/* $inidata/$folder
            rsync -rv --exclude=.nc original/ $inidata/$folder
            #touch $@
        fi
    done
fi




