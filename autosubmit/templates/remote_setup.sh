###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
platform=%COMMON.PLATFORM%
root_dir=%CURRENT_ROOTDIR%
members="%EXPERIMENT.MEMBERS%"
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%

function clone_nemo()
{
    mkdir -p ${dest_dir}
    cd ${dest_dir}
    
    # Clone NEMO repository
    if [ ! -d nemo_${branch} ]; then
        git config --global http.sslVerify "false"
        git clone https://forge.nemo-ocean.eu/nemo/nemo.git nemo_${branch}
        git config --global http.sslVerify "true"
    fi
    
    cd nemo_${branch}
    git checkout tags/${branch}
}

function clone_ecearth4()
{    
    # Create target directory
    mkdir -p ${dest_dir}
    cd ${dest_dir}
    
    # Clone ECEARTH4 repository
    if [ ! -d ecearth4_${branch} ]; then
        git clone --recurse-submodules https://git.smhi.se/ec-earth/ecearth4.git ecearth4_${branch}
    fi
    
    cd ecearth4_${branch}
    git checkout ${branch}
}

###################
# Start script
###################
if [ ! -d $project ] || [ %COMMON.REFRESH_GIT_REPO% == true ];
then
    chmod +w -R $project || :
    rm -rf $project% || :
    git clone --single-branch --branch ecearth4 https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git $project
fi

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

mkdir -p ${compilation}
mkdir -p ${inidata}
mkdir -p ${binaries}
mkdir -p ${run_folder}
mkdir -p ${inidata}

cd ${inidata}

# Clone the model source code
branchs_to_clone=(%MODEL.BRANCH_LIST%)
dest_dir=${compilation}
for branch in "${branchs_to_clone[@]}";
do
    if [[ ! -d ${model}_${branch} ]]
    then
        clone_${model}
    fi
done

# Clone XIOS if NEMO is run
if [ "${model}" = "nemo" ]; then
    if [ ! -d ${root_dir}/xios ]; then
        cd ${root_dir}
        svn co https://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/trunk xios

        cp ${project}/cfg/arch/${platform}/xios/* ${root_dir}/xios/arch
    fi

    if [ ! -d ${inidata}/original ]; then
        cd ${inidata}
        mkdir -p original
        wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar
        tar -xf ORCA2_ICE_v4.0.tar -C original
        gunzip original/*
        chmod -w original
        rm ORCA2_ICE_v4.0.tar
    fi
fi

# If hardware benchmarks are run, clone OSU and STREAM
if echo ${members[@]} | grep -q -w "HardwareBenchmarks"; then
    cd $compilation
    wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz
    tar -xvf osu-micro-benchmarks-5.6.3.tar.gz
    rm osu-micro-benchmarks-5.6.3.tar.gz

    if [ ! -d STREAM ]; then
        git clone https://github.com/jeffhammond/STREAM.git STREAM
    fi
fi