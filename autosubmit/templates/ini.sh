#!/bin/bash
#####################################################################################################################
# ini.sh
# Brief: This script creates the necessary inidata folders 
#####################################################################################################################

set -xuve
###################
# AS variables
###################
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
members="%EXPERIMENT.MEMBERS%"

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

###################
# Start script
###################

source ${env_sources}

mkdir -p ${inidata}
cd ${inidata}

for member in ${members}; do
    case "$member" in
        "CompilationEfficiency")
            folder="compilation_efficiency"
            tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
            test_config="%COMPILATION_EFFICIENCY.TEST_CONFIG%"
            ;;
        "WeakScaling")
            folder="weakscaling"
            tests="%WEAKSCALING.TEST_NAMES%"
            test_config="%WEAKSCALING.TEST_CONFIG%"
            ;;
        "StrongScaling")
            folder="strong_scaling"
            tests="%STRONGSCALING.TEST_NAMES%"
            test_config="%STRONGSCALING.TEST_CONFIG%"
            ;;
        "Tracing")
            folder="tracing"
            tests="%TRACING.TEST_NAMES%"
            test_config="%TRACING.TEST_CONFIG%"
            ;;
        *)
            continue
            ;;    
    esac
    
    tests=${tests//[\[,\]]/}
    tests=$(for v in $tests; do echo "$v";done| sort| uniq| xargs)

    ini_${model}
done




