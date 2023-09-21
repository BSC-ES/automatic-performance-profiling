# This script needs to be run in marenostrum0 (or any other machine with connection to outside)
# It will download the needed files to run the experiment
# TODO: change %_% placeholders in script for $var set at the beggining of the script like in the other files
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
platform=%COMMON.PLATFORM%
root_dir=%CURRENT_ROOTDIR%
members="%EXPERIMENT.MEMBERS%"
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%

# Clone repository to the remote for needed files
if [ ! -d $project ] || [ %COMMON.REFRESH_GIT_REPO% == true ];
then
    chmod +w -R $project || :
    rm -rf $project% || :
    git clone --single-branch --branch autosubmit https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git $project
fi

source ${env_sources}
export PYTHONPATH=$PYTHONPATH:${project}

mkdir -p ${compilation}
mkdir -p ${inidata}
mkdir -p ${binaries}
mkdir -p ${run_folder}
mkdir -p ${inidata}

cd ${inidata}

# Clone the model source code
branchs_to_clone=(%COMMON.BRANCH_LIST%)
for branch in "${branchs_to_clone[@]}";
do
    if [[ ! -d ${model}_${branch} ]]
    then
        $project/configurations/model/${model}/clone.sh $compilation $branch
        ln -sf $compilation/${model}_${branch} $compilation/%COMMON.MODEL%_source_$branch
    fi
done

if [ "${model}" = "nemo" ] && [ ! -d ${root_dir}/xios ]; then
    module load svn
    svn co https://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/trunk xios

    cd ${root_dir}/xios
    cp ${project}/cfg/arch/${platform}/xios/* arch

    mkdir -p original
    wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar
    tar -xf ORCA2_ICE_v4.0.tar -C original
    gunzip original/*
    chmod -w original
    rm ORCA2_ICE_v4.0.tar
fi

# If hardware benchmarks are run, clone OSU and STREAM
if echo ${members[@]} | grep -q -w "HardwareBenchmarks"; then
    mkdir -p $compilation
    cd $compilation
    wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz
    tar -xvf osu-micro-benchmarks-5.6.3.tar.gz
    rm osu-micro-benchmarks-5.6.3.tar.gz

    if [ ! -d STREAM ]; then
        git clone https://github.com/jeffhammond/STREAM.git STREAM
    fi
fi