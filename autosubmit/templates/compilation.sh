set -xv
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
ntasks=%NUMTASK%
branch=%COMMON.BRANCH_LIST%
platform=%COMMON.PLATFORM%
exp_root=%CURRENT_ROOTDIR%

source $env_sources

mkdir -p $compilation
mkdir -p $binaries

# End of experiment variables
if [ $current_member = "HardwareBenchmarks" ];
then
    source $inidata/hardware_benchmarks/param_bash.cfg
    cd ${compilation}/STREAM
    gcc -fopenmp -D_OPENMP stream.c -o stream

    cd ${compilation}/osu-micro-benchmarks-5.6.3
    ./configure CC=`which mpicxx` CXX=`which mpicc` --prefix=`pwd`
    make install
    make
else
    if [ "${model}" = "nemo" ]; then
        cd ${exp_root}/xios
        ./make_xios --dev --arch ifort_${platform} --job ${ntasks}
    fi

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

        exe_flavor=vanilla
        exe_flavor_trace=trace
        exe_flavor_scalability=scorep

        target_exe=${bin_name}_vanilla.exe
        target_exe_trace=${bin_name}_trace.exe
        target_exe_scalability=${bin_name}_scalability.exe

        model_sources=%COMMON.MODEL%_${branch}

        cd $compilation
        mkdir -p ${test_name[i]}
        mkdir -p $binaries/${test_name[i]}
        rsync -av --exclude='doc*' --exclude='*.svn*' ${model_sources}/* $compilation/${test_name[i]}
        cd $compilation/${test_name[i]}
        # This should also be astracted from the model
        cp $project/cfg/arch/${platform}/${model}/arch-* $compilation/${test_name[i]}/arch/

        if [ "$model" = "nemo" ];
        then
            # Add xios lib and include path to NEMO fcms
            for fcm in $compilation/${test_name[i]}/arch/*.fcm; do
                sed -i "0,/%XIOS_LIB/ s/%XIOS_LIB/%XIOS_LIB            -L$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/lib -lxios/g" ${fcm}
                sed -i "0,/%XIOS_INC/ s/%XIOS_INC/%XIOS_INC            -I$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/inc/g" ${fcm}
            done

            # Compile NEMO
            compilation_command=` echo $compilation/${test_name[i]}/makenemo -m ${arch_file_prefix}_${exe_flavor} -n ${configuration_name}_${exe_flavor} ${configuration_details} -j ${ntasks}`
            eval ${compilation_command}
            # Compile TRACE
            compilation_command=` echo $compilation/${test_name[i]}/makenemo -m ${arch_file_prefix}_${exe_flavor_trace} -n ${configuration_name}_${exe_flavor_trace} ${configuration_details} -j ${ntasks}`
            eval ${compilation_command}
            # Compile SCOREP
            compilation_command=` echo $compilation/${test_name[i]}/makenemo -m ${arch_file_prefix}_${exe_flavor_scalability} -n ${configuration_name}_${exe_flavor_scalability} ${configuration_details} -j ${ntasks}`
            eval ${compilation_command}
            # Copy binary into bin folder
            cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/nemo $binaries/${test_name[i]}/${target_exe}
            cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/nemo $binaries/${test_name[i]}/${target_exe_trace}
            cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_scalability}/EXP00/nemo $binaries/${test_name[i]}/${target_exe_scalability}
            
            if [[ ! -z ${configuration_resolution+x} ]]
            then
                #EXE_FOLDER
                cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg
                cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/namelist_cfg
                cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_scalability}/EXP00/namelist_cfg
            fi
            make $binaries/${test_name[i]}/nemo_vanilla.exe -j 48
            make $binaries/${test_name[i]}/nemo_trace.exe -j 48

            # Copy xios binary
            cp ${exp_root}/xios/bin/xios_server.exe $binaries/${test_name[i]}/xios_server.exe
        fi
        i=$((i+1))
    done
fi
