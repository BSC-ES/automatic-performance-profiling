#!/bin/bash
#####################################################################################################################
# remote_setup.sh
# Brief: This script clones and downloads the inidata if needed 
#####################################################################################################################

###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
root_dir=%CURRENT_ROOTDIR%
members="%EXPERIMENT.MEMBERS%"
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
model_origin="%MODEL.ORIGIN%"
refresh_git=%COMMON.REFRESH_GIT_REPO%

function clone_nemo()
{
    mkdir -p ${dest_dir}
    cd ${dest_dir} || exit
    
    # Clone NEMO repository
    if [ ! -d nemo_${branch} ]; then
        git config --global http.sslVerify "false"
        git clone ${model_origin} nemo_${branch}
        git config --global http.sslVerify "true"
    fi
    
    cd nemo_${branch} || exit
    git checkout tags/${branch}

    if [ ! -d ${root_dir}/xios ]; then
        cd ${root_dir} || exit
        svn co https://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/trunk xios

        cp ${project}/cfg/arch/${platform}/xios/* ${root_dir}/xios/arch
    fi

    if [ ! -d ${inidata}/original ]; then
        cd ${inidata} || exit
        mkdir -p original
        wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar
        tar -xf ORCA2_ICE_v4.0.tar -C original
        gunzip original/*
        chmod -w original
        rm ORCA2_ICE_v4.0.tar
    fi
}

function clone_ecearth4()
{    
    # Create target directory
    mkdir -p ${dest_dir}
    cd ${dest_dir} || exit
    
    # Clone ECEARTH4 repository
    if [ ! -d ecearth4_${branch} ]; then
        git clone --recurse-submodules ${model_origin} ecearth4_${branch}
    fi
    
    cd ecearth4_${branch} || exit
    git checkout ${branch}
    git submodule update --init --recursive

    # Update config for AS to worl with SE
    sed -i "/- base.move:/a \ \ \ \ ignore_not_found: true" scripts/runtime/scriptlib/main.yml
    # Activate timing output log for NEMO
    sed -i 's/ln_timing   = .false./ln_timing   = .true./'  scripts/runtime/templates/nemo/nemo-oce.namelist.j2
    # Add trace launch script
    cp ${cfg}/trace/model/ecearth4/trace-run.sh.j2 scripts/runtime/templates/launch/

    cd ${dest_dir} || exit
    [ ! -d lucia-alternative ] && git clone https://earth.bsc.es/gitlab/es/lucia-alternative.git

    return 0
}

function clone_hw_benchmarks() 
{
    cd ${compilation} || exit

    osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
    osu_enabled=${osu_enabled,,}
    stream_enabled=%HW_BENCHMARKS.STREAM.ENABLED%
    stream_enabled=${stream_enabled,,}

    if ${osu_enabled}; then
        wget -O osu-micro-benchmarks.tar.gz http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-7.5-1.tar.gz
        tar -xvf osu-micro-benchmarks.tar.gz --one-top-level --strip-components=1
        rm osu-micro-benchmarks.tar.gz
    fi

    if ${stream_enabled} && [ ! -d STREAM ]; then
        git clone https://github.com/jeffhammond/STREAM.git STREAM
    fi
}

###################
# Start script
###################

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

mkdir -p ${compilation}
mkdir -p ${inidata}
mkdir -p ${binaries}
mkdir -p ${run_folder}
mkdir -p ${inidata}

# Clone the model source code
branch=%MODEL.BRANCH%
dest_dir=${compilation}
if [ ! -d ${model}_${branch} ]; then
    clone_${model}
fi

# If hardware benchmarks are run, clone OSU and STREAM
if echo "${members[@]}" | grep -q -w "HardwareBenchmarks"; then
    clone_hw_benchmarks
fi