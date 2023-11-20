set -xuve
###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%

#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: Creates the inidata folders for the different tests
#####################################################################################################################
function ini_nemo()
{
    mkdir -p ${folder}
    declare -a folders
    for test in ${tests}; do
        folders+=("$folder/$test")
        mkdir -p ${folder}/${test}
    done

    for folder in "${folders[@]}";
    do
        test=${folder##*/}
        if [ "${test_config}" = "BENCH" ]
        then
            # It is BENCH, copy the namelist into the configuration namelist_cfg
            cp $project/cfg/utils/${model}/iodef.xml  $inidata/$folder
            cp $project/cfg/utils/${model}/context_${model}.xml  $inidata/$folder
        else
            # Link inidata to each model
            ln -rsf ${inidata}/original/* $inidata/$folder
            rsync -rv --exclude=.nc ${inidata}/original/ $inidata/$folder
            #touch $@
        fi
    done
}

#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: NN for now
#####################################################################################################################
function ini_ecearth4()
{
    # TODO not necessary for now
    echo INI
}

function ini_hw()
{
    echo INI
}

###################
# Start script
###################
source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:$(pwd)
set -u

if [ "${current_member}" = "CompilationEfficiency" ]; then
    folder="compilation_efficiency"
    tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
    test_config="%COMPILATION_EFFICIENCY.TEST_CONFIG%"
elif [ "${current_member}" = "WeakScaling" ]; then
    folder="weakscaling"
    tests="%WEAKSCALING.TEST_NAMES%"
    test_config="%WEAKSCALING.TEST_CONFIG%"
elif [ "${current_member}" = "StrongScaling" ]; then
    folder="strong_scaling"
    tests="%STRONGSCALING.TEST_NAMES%"
    test_config="%STRONGSCALING.TEST_CONFIG%"
else
    model=hw
fi

tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)

mkdir -p ${inidata}
cd ${inidata}

ini_${model}



