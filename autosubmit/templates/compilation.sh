#!/usr/bin/env bash
# Go to experiment folder
set -xv
mkdir -p %COMPILATION_ROOT%
mkdir -p %BINARIES_ROOT%
source %ENV_SOURCES%
cd %COMPILATION_ROOT%
#Load environment
run_folder=(%RUN_FOLDER%)
source %ENV_SOURCES%
if [ "%MEMBER%" = "HardwareBenchmarks" ];
then
    source %INIDATA_ROOT%/hardware_benchmarks/param_bash.cfg
    git clone https://github.com/jeffhammond/STREAM.git STREAM
    cd STREAM
    gcc -fopenmp -D_OPENMP stream.c -o stream
    #STREAM_RUN/stream.slurm
    cd %COMPILATION_ROOT%

    #stream.target (stream.sh)
    #osu_install
    wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz
    tar -xvf osu-micro-benchmarks-5.6.3.tar.gz
    rm osu-micro-benchmarks-5.6.3.tar.gz
    cd osu-micro-benchmarks-5.6.3
    ./configure CC=`which mpicxx` CXX=`which mpicc` --prefix=`pwd`
    make install
    make
    cd %COMPILATION_ROOT%
else
    declare -a configuration_folders
    if [ "%MEMBER%" = "CompilationEfficiency" ];
    then
        for config in %INIDATA_ROOT%/compilation_efficiency
        do
            configuration_folders+=$(config)/param_bash.cfg
        done
    elif [ "%MEMBER%" = "WeakScaling" ];
    then
        for config in %INIDATA_ROOT%/weakscaling
        do
            configuration_folders+=$(config)/param_bash.cfg
        done
    else
      #STRONG_SCALING
      configuration_folders+=%INIDATA_ROOT%/strong_scaling/param_bash.cfg
    fi
    for param_file in ${configuration_folders[@]};
    do
      source $param_file
      #exe_flavor=bin/${bin_name}_46
      exe_flavor=vanilla
      #$* filename
      target_exe=bin/${bin_name}_vanilla.exe
      exe_flavor_trace=trace
      #$* filename
      target_exe_trace=bin/${bin_name}_trace.exe
      #$@ target_name
      model_sources=%MODEL%_source
      ##$<
      mkdir -p %COMPILATION_ROOT%
      cd %COMPILATION_ROOT%
      rsync -av --exclude='doc*' --exclude='*.svn*' ${model_sources}/* %COMPILATION_ROOT%
      # This should also be astracted from the model
      cp %PROJECT_ROOT%/cfg/arch/arch-* %COMPILATION_ROOT%/arch/
      if [ "%MODEL%" = "nemo" ];
      then
          # Compile NEMO
          compilation_command=` echo %COMPILATION_ROOT%/makenemo -m ${arch_file_prefix}_${exe_flavor} -n ${configuration_name}_${exe_flavor} ${configuration_details} -j 16`
          eval ${compilation_command}
          # Compile TRACE
          compilation_command=` echo %COMPILATION_ROOT%/makenemo -m ${arch_file_prefix}_${exe_flavor_trace} -n ${configuration_name}_${exe_flavor_trace} ${configuration_details} -j 16`
          eval ${compilation_command}
          # Copy binary into bin folder
          cp %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/nemo %EXP_ROOT%/${target_exe}
          # To separate with split?
          cp %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/nemo %EXP_ROOT%/${target_exe_trace}

          if [[ ! -z ${configuration_resolution+x} ]]
          then
              #EXE_FOLDER
              cp %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg
              cp %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/namelist_cfg

          fi
          make %BINARIES_ROOT%/nemo_vanilla.exe -j 48
          make %BINARIES_ROOT%/nemo_trace.exe -j 48
        #Binaries XIOS_SERVER
        # TODO: HARDCODED dependency that at some point should be replaced with xios compilation
        cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe %BINARIES_ROOT%/xios_server.exe
      fi
    done
fi



