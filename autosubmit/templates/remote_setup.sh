compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=(%COMMON.RUN_FOLDER%)
mkdir -p $compilation
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cd %COMMON.EXP_ROOT%


# Clone repository to the remote for needed files
# if exist or force refresh is true
if [ ! -d $project ] || [ %COMMON.REFRESH_GIT_REPO% == true ];
then
    chmod +w -R $project || :
    rm -rf $project% || :
    git clone --single-branch --branch autosubmit-makefile1 https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git $project
fi
source %PARAMETERS_ENV_CONFIG.ENV_SOURCES%
export PYTHONPATH=$PYTHONPATH:$(pwd)
mkdir -p $compilation
mkdir -p $inidata
mkdir -p $binaries
mkdir -p $run_folder

mkdir -p inidata
cd inidata

#Download common ini data
# Clone model
branchs_to_clone=(%COMMON.BRANCH_LIST%)
if [ "%COMMON.MODEL%" = "nemo" ];
then
    #nemo_source.target
    # if the mirror has not been cloned yet
    for branch in "${branchs_to_clone[@]}";
    do
      if [[ ! -d nemo_mirror_$branch ]]
      then
          $project/cfg/clone_nemo.sh $compilation/nemo_mirror_$branch $branch
          ln -sf $compilation/nemo_mirror_$branch $compilation/%COMMON.MODEL%_source_$branch
      fi
    done
fi
#This needs an if only HW is on members
# This is common except for HW so it is valid as running once. This could be at INI.sh but it is running = member
mkdir -p original
wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar #Revise
tar -xf ORCA2_ICE_v4.0.tar -C original
gunzip original/*
# Remove write permissions to avoid unwilingly manipulate the input files
chmod -w original
# Remove compressed file
rm ORCA2_ICE_v4.0.tar
####
#mkdir -p $compilation
#cd $compilation
#wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz


