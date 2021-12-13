#!/usr/bin/env bash
# Go to experiment folder
set -xv
mkdir -p %COMPILATION_ROOT%
mkdir -p %BINARIES_ROOT%
source %ENV_SOURCES%
cd %COMPILATION_ROOT%
#Load environment
run_folder=(%RUN_FOLDER%)
enabled=(%ENABLED_TESTS%)
source %ENV_SOURCES%
if %ENABLE_HW_BENCHMARKS%;
then
    sleep 1
fi
if %ENABLE_COMPILATION_EFFICIENCY%;
then
  sleep 1
fi
if %ENABLE_WEAKSCALING%;
then
  sleep 1
fi
if %ENABLE_STRONGSCALING%;
then
    source %INIDATA_ROOT%/strong_scaling/param_bash.cfg
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
    if [ "%MODEL%" = "nemo" ];
    then
        #nemo_source.target
        # if the mirror has not been cloned yet
        if [[ ! -d nemo_mirror ]]
        then
          %PROJECT_ROOT%/cfg/clone_nemo.sh %COMPILATION_ROOT%/nemo_mirror ${model_branch}
        fi
        ln -sf %COMPILATION_ROOT%/nemo_mirror %COMPILATION_ROOT%/${model}_source
    fi
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
        #trace


        #Binaries XIOS_SERVER
        # TODO: HARDCODED dependency that at some point should be replaced with xios compilation
        cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe %BINARIES_ROOT%/xios_server.exe
    fi
fi



