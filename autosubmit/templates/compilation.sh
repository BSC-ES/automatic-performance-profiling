set -xv
###################
# AS variables
###################
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
cfg=%COMMON_PATH_LOCATIONS.CFG%

###################
# Compile NEMO
###################
function compile_nemo()
{
    # Compile XIOS
    cd ${exp_root}/xios
    ./make_xios --dev --arch ifort_${platform} --job ${ntasks}

    source $param_file

    exe_flavor=vanilla
    exe_flavor_trace=trace

    target_exe=${bin_name}_vanilla.exe
    target_exe_trace=${bin_name}_trace.exe

    model_sources=${model}_${branch}

    cd $compilation
    mkdir -p ${test_name[i]}
    mkdir -p $binaries/${test_name[i]}
    rsync -av --exclude='doc*' --exclude='*.svn*' ${model_sources}/* $compilation/${test_name[i]}
    cd $compilation/${test_name[i]}
    cp $project/cfg/arch/${platform}/${model}/arch-* $compilation/${test_name[i]}/arch/


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
    # Copy binary into bin folder
    cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/nemo $binaries/${test_name[i]}/${target_exe}
    cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/nemo $binaries/${test_name[i]}/${target_exe_trace}

    if [[ ! -z ${configuration_resolution+x} ]]
    then
        #EXE_FOLDER
        cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg
        cp $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor}/EXP00/namelist_cfg_${configuration_resolution}_like  $compilation/${test_name[i]}/${configuration_folder}/${configuration_name}_${exe_flavor_trace}/EXP00/namelist_cfg
    fi
    make $binaries/${test_name[i]}/nemo_vanilla.exe -j 48
    make $binaries/${test_name[i]}/nemo_trace.exe -j 48

    # Copy xios binary
    cp ${exp_root}/xios/bin/xios_server.exe $binaries/${test_name[i]}/xios_server.exe
}

###################
# Compile ECEARTH4 using SE
###################
function compile_ecearth4()
{
    model_sources=${model}_${branch}

    mkdir -p ${compilation}/${test_name[i]}
    mkdir -p ${binaries}/${test_name[i]}
    rsync -av --exclude='*.svn*' ${compilation}/${model_sources}/* ${compilation}/${test_name[i]}

    cd ${compilation}/${test_name[i]}/sources/se

    if [ $current_member = "CompilationEfficiency" ];
    then
        configs=${cfg}/arch/${platform}/${model}/${test_name[i]##*/}-*.yml
    else 
        configs=${cfg}/arch/${platform}/${model}/O3-*.yml
    fi

    set +u
    module load conda
    conda activate /hpcperm/c3et/conda/ece4
    for config in ${configs}; do
        cp ${config} platforms/${config##*/}
        se user-settings-hpc2020.yml platforms/${config##*/} compile-all.yml
    done
}


###################
# Compile HW benchmarks
###################
function compile_hw()
{
    cd ${compilation}/STREAM
    gcc -fopenmp -D_OPENMP stream.c -o stream

    cd ${compilation}/osu-micro-benchmarks-5.6.3
    ./configure CC=`which mpicxx` CXX=`which mpicc` --prefix=`pwd`
    make install
    make
}

###################
# Start script
###################
mkdir -p $compilation
mkdir -p $binaries

source $env_sources

if [ $current_member = "HardwareBenchmarks" ];
then
    compile_hw
else
    if [ $current_member = "CompilationEfficiency" ];
    then
        folder=compilation_efficiency
        folders=$(echo $inidata/$folder/*)
    elif [ $current_member = "WeakScaling" ];
    then
        folder=weakscaling
        folders=$(echo $inidata/$folder/*)
    else
        folder=strong_scaling
        folders=$(echo $inidata/$folder/*)
    fi

    declare -a configuration_folders
    declare -a test_name
    mkdir -p $compilation/${folder}
    for config in $folders
    do
        configuration_folders+=($config/param_bash.cfg)
        echo mkdir -p $compilation/$folder/${config##*/}
        mkdir -p $compilation/$folder/${config##*/}
        test_name+=($folder/${config##*/})
    done

    i=0
    for param_file in ${configuration_folders[@]};
    do
        # Call the corresponding compile function
        compile_${model}

        i=$((i+1))
    done
fi
