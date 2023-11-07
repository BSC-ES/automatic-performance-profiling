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
model=%MODEL.NAME%
ntasks=%NUMTASK%
branch=%MODEL.BRANCH_LIST%
platform=%COMMON.PLATFORM%
exp_root=%CURRENT_ROOTDIR%
cfg=%COMMON_PATH_LOCATIONS.CFG%

#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: Compiles NEMO
#####################################################################################################################
function compile_nemo()
{
    # Compile XIOS
    cd ${exp_root}/xios
    cp $project/cfg/arch/${platform}/xios/arch-* arch
    ./make_xios --dev --arch ifort_${platform} --job ${ntasks}

    # Compile NEMO
    configuration_folder=tests
    exe_flavor=vanilla
    exe_flavor_trace=trace
    target_exe=${model}_vanilla.exe
    target_exe_trace=${model}_trace.exe
    model_sources=${model}_${branch}

    mkdir -p ${bin_folder}
    rsync -av --exclude='doc*' --exclude='*.svn*' ${compilation}/${model_sources}/* ${test_folder}
    cp $project/cfg/arch/${platform}/${model}/arch-* ${test_folder}/arch/

    # Add xios lib and include path to NEMO fcms
    for fcm in ${test_folder}/arch/*.fcm; do
        sed -i "0,/%XIOS_LIB/ s/%XIOS_LIB/%XIOS_LIB            -L$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/lib -lxios/g" ${fcm}
        sed -i "0,/%XIOS_INC/ s/%XIOS_INC/%XIOS_INC            -I$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/inc/g" ${fcm}
    done

    if [ $current_member = "CompilationEfficiency" ]; then
        arch_file_prefix=${test}
        if [ "${test}" = "O3" ]; then
            arch_file_prefix=prod
        fi
    else
        arch_file_prefix=prod
    fi

    # Compile NEMO
    compilation_command=` echo ${test_folder}/makenemo -m ${arch_file_prefix}_${exe_flavor} -n ${test}_${exe_flavor} -a BENCH -j ${ntasks}`
    eval ${compilation_command}

    # Compile TRACE
    compilation_command=` echo ${test_folder}/makenemo -m ${arch_file_prefix}_${exe_flavor_trace} -n ${test}_${exe_flavor_trace} -a BENCH -j ${ntasks}`
    eval ${compilation_command}

    # Copy binary into bin folder
    cp ${test_folder}/${configuration_folder}/${test}_${exe_flavor}/EXP00/nemo ${bin_folder}/${target_exe}
    cp ${test_folder}/${configuration_folder}/${test}_${exe_flavor_trace}/EXP00/nemo ${bin_folder}/${target_exe_trace}

    if [[ ! -z ${model_resolution+x} ]]
    then
        cp ${test_folder}/${configuration_folder}/${test}_${exe_flavor}/EXP00/namelist_cfg_${model_resolution}_like  ${test_folder}/${configuration_folder}/${test}_${exe_flavor}/EXP00/namelist_cfg
        cp ${test_folder}/${configuration_folder}/${test}_${exe_flavor}/EXP00/namelist_cfg_${model_resolution}_like  ${test_folder}/${configuration_folder}/${test}_${exe_flavor_trace}/EXP00/namelist_cfg
    fi

    make ${bin_folder}/nemo_vanilla.exe -j 48
    make ${bin_folder}/nemo_trace.exe -j 48

    # Copy xios binary
    cp ${exp_root}/xios/bin/xios_server.exe ${bin_folder}/xios_server.exe
}

#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: Compiles ECEARTH4
#####################################################################################################################
function compile_ecearth4()
{
    model_sources=${model}_${branch}

    mkdir -p ${test_folder}
    mkdir -p ${bin_folder}
    rsync -av --exclude='*.svn*' ${compilation}/${model_sources}/* ${test_folder}

    cd ${test_folder}/sources/se

    # Use O3 config for all members except for Compilation Efficiency
    if [ $current_member = "CompilationEfficiency" ];
    then
        configs=${cfg}/arch/${platform}/${model}/${test_name[i]##*/}-*.yml
    else 
        configs=${cfg}/arch/${platform}/${model}/O3-*.yml
    fi

    # Set number of compilation tasks 
    sed -i "0,/jobs:/s/        jobs:.*/        jobs: ${ntasks}/" user-settings-hpc2020.yml

    # Activate SE enviroment
    set +u
    module load conda
    conda activate /hpcperm/c3et/conda/ece4

    # Compile all member configurations
    for config in ${configs}; do
        cp ${config} platforms/${config##*/}
        se user-settings-hpc2020.yml platforms/${config##*/} compile-all.yml
    done
}


#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: Compiles HW benchmarks
#####################################################################################################################
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
        tests="%COMPILATION_EFFICIENCY.TEST_NAMES%"
        model_resolution=%COMPILATION_EFFICIENCY.MODEL_RESOLUTION%
    elif [ $current_member = "WeakScaling" ];
    then
        folder=weakscaling
        tests="%WEAKSCALING.TEST_NAMES%"
        model_resolution=%WEAKSCALING.MODEL_RESOLUTION%
    else
        folder=strong_scaling
        tests="%STRONGSCALING.TEST_NAMES%"
        model_resolution=%STRONGSCALING.MODEL_RESOLUTION%
    fi

    mkdir -p $compilation/${folder}

    # Convert from [O0, O1, O1] to "O0 O1"
    tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
    tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)

    for test in $tests
    do
        test_folder=$compilation/$folder/$test
        bin_folder=$binaries/$folder/$test
        mkdir -p ${test_folder}
        compile_${model}
    done
fi
