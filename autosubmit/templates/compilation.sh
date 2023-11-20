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
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
arch_names="%MODEL.ARCH_NAMES%"
arch_names=($(echo $arch_names | sed "s/\[\|\]\|,//g"))
arch_names=$(for v in "${arch_names[@]}"; do echo "$v";done| sort| uniq| xargs)

#####################################################################################################################
# Path variables: TODO
# Other variables: TODO
# Purpose: Compiles all arch FCM configurations for NEMO configured in the ARCH_NAMES AS variable
#####################################################################################################################
function compile_nemo()
{
    # Compile XIOS
    cd ${exp_root}/xios
    cp $project/cfg/arch/${platform}/xios/arch-* arch
    ./make_xios --dev --arch ifort_${platform} --job ${ntasks}
    
    # Compile NEMO
    model_sources=${compilation}/${model}_${branch}
    cd ${model_sources}
    for arch_name in ${arch_names}; do
        arch_file_prod=${cfg}/arch/${platform}/${model}/arch-${arch_name}-prod.fcm
        arch_file_trace=${cfg}/arch/${platform}/${model}/arch-${arch_name}-trace.fcm

        configuration_folder=tests
        exe_flavor=prod
        exe_flavor_trace=trace
        target_exe=${model}_prod.exe
        target_exe_trace=${model}_trace.exe
        bin_folder=${binaries}/${arch_name}

        mkdir -p ${bin_folder}
        cp ${arch_file_prod} ${model_sources}/arch/
        cp ${arch_file_trace} ${model_sources}/arch/

        # Add xios lib and include path to NEMO fcms
        for fcm in ${model_sources}/arch/*.fcm; do
            sed -i "0,/%XIOS_LIB/ s/%XIOS_LIB/%XIOS_LIB            -L$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/lib -lxios/g" ${fcm}
            sed -i "0,/%XIOS_INC/ s/%XIOS_INC/%XIOS_INC            -I$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/inc/g" ${fcm}
        done

        # Compile NEMO
        compilation_command=` echo ${model_sources}/makenemo -m ${arch_name}-prod -n ${arch_name}_prod -a BENCH -j ${ntasks}`
        eval ${compilation_command}

        # Compile TRACE
        compilation_command=` echo ${model_sources}/makenemo -m ${arch_name}-trace -n ${arch_name}_trace -a BENCH -j ${ntasks}`
        eval ${compilation_command}

        # Copy binary into bin folder
        cp ${model_sources}/${configuration_folder}/${arch_name}_prod/EXP00/nemo ${bin_folder}/${target_exe}
        cp ${model_sources}/${configuration_folder}/${arch_name}_trace/EXP00/nemo ${bin_folder}/${target_exe_trace}

        # Copy xios binary
        cp ${exp_root}/xios/bin/xios_server.exe ${bin_folder}/xios_server.exe
    done
}

#####################################################################################################################
# Path variables: compilation, project
# Other variables: model, branch, platform, ntasks
# Purpose: Compiles all arch YML configurations for ECEARTH 4 configured in the ARCH_NAMES AS variable
#####################################################################################################################
function compile_ecearth4()
{
    model_sources=${compilation}/${model}_${branch}

    set +u
    module load conda
    conda activate /hpcperm/c3et/conda/ece4 

    cp ${project}/configurations/model/${model}/user-settings-hpc2020.yml ${model_sources}/sources/se
    sed -i "s/JOBS/${ntasks}" ${model_sources}/sources/se/user-settings-hpc2020.yml

    for arch_name in ${arch_names}; do
        cd ${compilation}
        arch_name_prod=${arch_name}-prod
        arch_file=${cfg}/arch/${platform}/${model}/${arch_name_prod}.yml
        mkdir -p ${arch_name_prod}
        rsync -av --exclude='*.svn*' ${model_sources}/* ${arch_name_prod}
        cd ${arch_name_prod}/sources/se
        cp ${arch_file} platforms
        se user-settings-hpc2020.yml platforms/${arch_name_prod}.yml compile-all.yml

        cd ${compilation}
        arch_name_trace=${arch_name}-trace
        arch_file=${cfg}/arch/${platform}/${model}/${arch_name_trace}.yml
        mkdir -p ${arch_name_trace}
        rsync -av --exclude='*.svn*' ${model_sources}/* ${arch_name_trace}
        cd ${arch_name_trace}/sources/se
        cp ${arch_file} platforms
        se user-settings-hpc2020.yml platforms/${arch_name_trace}.yml compile-all.yml
    done
}


#####################################################################################################################
# Path variables: compilation
# Purpose: Compiles STREAM and OSU HW benchmarks
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

# Compile hardware benchmarks
compile_hw

# Compile all model arch configurations
compile_${model}
