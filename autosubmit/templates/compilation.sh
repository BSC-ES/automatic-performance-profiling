# This file clones and compiles the model, it requires connection to the outside ( login0 ) due the hardware benchmarks
# Go to experiment folder
set -xv
# Set the experiment variables
# At somepoint of AS 4, we will introduce the capability of extend the header provided by Autosubmit,
# in which we could add these variables common for all the scripts, and then we could remove them from here. Not yet done
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
mkdir -p $compilation
# MEMBER in this context, is a test type. It can be CompilationEfficiency, WeakScaling, StrongScaling or HardwareBenchmarks ( case-sensitive)
# Autosubmit Automatically tells you in which member you are with this placeholder
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
mkdir -p $binaries
source $env_sources
cd $compilation
#Load environment
source $env_sources
# End of experiment variables
if [ $current_member = "HardwareBenchmarks" ];
then
    #HardwareBenchmarks compilation extracted from the original makefile and modified to be compatible with the file structure
    source $inidata/hardware_benchmarks/param_bash.cfg
    git clone https://github.com/jeffhammond/STREAM.git STREAM
    cd STREAM
    gcc -fopenmp -D_OPENMP stream.c -o stream
    #STREAM_RUN/stream.slurm
    cd $compilation
    #stream.target (stream.sh)
    #osu_install
    wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz
    tar -xvf osu-micro-benchmarks-5.6.3.tar.gz
    rm osu-micro-benchmarks-5.6.3.tar.gz
    cd osu-micro-benchmarks-5.6.3
    ./configure CC=`which mpicxx` CXX=`which mpicc` --prefix=`pwd`
    #./configure CC="$(which mpicxx)" CXX="$(which mpicc)" --prefix="$(pwd)"
    make install
    make
    cd $compilation
else
    declare -a configuration_folders
    declare -a test_name
    if [ $current_member = "CompilationEfficiency" ];
    then
        mkdir -p $compilation/compilation_efficiency
        for config in $inidata/compilation_efficiency/*
        do
            configuration_folders+=($config/param_bash.cfg)
            mkdir -p $compilation/compilation_efficiency/${config##*/}
            test_name+=(compilation_efficiency/${config##*/})
        done
    elif [ $current_member = "WeakScaling" ];
    then
        mkdir -p $compilation/weakscaling
        for config in $inidata/weakscaling/*
        do
            configuration_folders+=($config/param_bash.cfg)
            mkdir -p $compilation/weakscaling/${config##*/}
            test_name+=(weakscaling/${config##*/})
        done
    else
      #STRONG_SCALING
      configuration_folders+=($inidata/strong_scaling/param_bash.cfg)
      mkdir -p $compilation/strong_scaling
      test_name+=(strong_scaling)
    fi
    i=0
    for param_file in ${configuration_folders[@]};
    do
      source $param_file
      #exe_flavor=bin/${bin_name}_46
      exe_flavor=vanilla
      #$* filename
      target_exe=${bin_name}_vanilla.exe
      exe_flavor_trace=trace
      #$* filename
      target_exe_trace=${bin_name}_trace.exe
      #$@ target_name
      model_sources=%COMMON.MODEL%_source_${model_branch}
      ##$<
      mkdir -p $compilation
      cd $compilation
      mkdir -p ${test_name[i]}
      mkdir -p $binaries/${test_name[i]}
      rsync -av --exclude='doc*' --exclude='*.svn*' ${model_sources}/* $compilation/${test_name[i]}
      cd $compilation/${test_name[i]}
      # This should also be astracted from the model
      cp $project/cfg/arch/arch-* $compilation/${test_name[i]}/arch/
      if [ "$model" = "nemo" ];
      then
          # Compile NEMO
          compilation_command=` echo $compilation/${test_name[i]}/makenemo -m ${arch_file_prefix}_${exe_flavor} -n ${configuration_name}_${exe_flavor} ${configuration_details} -j 16`
          eval ${compilation_command}
          # Compile TRACE
          compilation_command=` echo $compilation/${test_name[i]}/makenemo -m ${arch_file_prefix}_${exe_flavor_trace} -n ${configuration_name}_${exe_flavor_trace} ${configuration_details} -j 16`
          eval ${compilation_command}
          # Copy binary into bin folder
          cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/nemo $binaries/${test_name[i]}/${target_exe}
          # To separate with split?
          cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/nemo $binaries/${test_name[i]}/${target_exe_trace}

          if [[ ! -z ${configuration_resolution+x} ]]
          then
              #EXE_FOLDER
              cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg
              cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/namelist_cfg

          fi
          make $binaries/${test_name[i]}/nemo_vanilla.exe -j 48
          make $binaries/${test_name[i]}/nemo_trace.exe -j 48
        #Binaries XIOS_SERVER
        # TODO: HARDCODED dependency that at some point should be replaced with xios compilation
        cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe $binaries/${test_name[i]}/xios_server.exe
      fi
    i=$((i+1))
    done
fi
