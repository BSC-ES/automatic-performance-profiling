cd %EXP_ROOT%
mkdir -p %COMPILATION_ROOT%



# Clone repository to the remote for needed files
# if exist or force refresh is true
if [ ! -d %PROJECT_ROOT% ] || [ %REFRESH_GIT_REPO% == true ];
then
    chmod +w -R %PROJECT_ROOT% || :
    rm -rf %PROJECT_ROOT%% || :
    git clone --single-branch --branch autosubmit-makefile1 https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git %PROJECT_ROOT%
fi
source %ENV_SOURCES%
export PYTHONPATH=$PYTHONPATH:$(pwd)
mkdir -p inidata
cd inidata

#Download common ini data

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
#mkdir -p %COMPILATION_ROOT%
#cd %COMPILATION_ROOT%
#wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz


