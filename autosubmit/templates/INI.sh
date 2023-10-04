set -xuve
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%

source ${env_sources}
export PYTHONPATH=$PYTHONPATH:$(pwd)

mkdir -p ${inidata}
cd ${inidata}

if [ "${current_member}" = "HardwareBenchmarks" ]; then
    folder="hardware_benchmarks"
    configs="$(find %HW_BENCHMARKS.HW_BENCHMARKS_PARAMETERS_ROOT%)"
elif [ "${current_member}" = "CompilationEfficiency" ]; then
    folder="compilation_efficiency"
    configs="$(find %WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*)"
elif [ "${current_member}" = "WeakScaling" ]; then
    folder="weakscaling"
    configs="$(find %WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*)"
elif [ "${current_member}" = "StrongScaling" ]; then
    folder="strong_scaling"
    configs="$(find %STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%)"
fi

mkdir -p ${folder}
declare -a folders
for config in ${configs}; do
    folders+=("$folder/${config##*/}")
    mkdir -p ${folder}/${config##*/}
    python %PARAMETERS_ENV_CONFIG.CONVERT_PARAM_FILE% -p $config -o $inidata/${folder}/${config##*/}/param_bash.cfg
done

if [ "${current_member}" != "HardwareBenchmarks" ];
then
    #Load parameter configuration depending on the test
    for folder in "${folders[@]}";
    do
        source $inidata/$folder/param_bash.cfg
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




