set -xv
###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
ntasks=%THREADS%
branch=%MODEL.BRANCH_LIST%
platform=%COMMON.PLATFORM%
exp_root=%CURRENT_ROOTDIR%
cfg=%COMMON_PATH_LOCATIONS.CFG%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
members="%EXPERIMENT.MEMBERS%"
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
        configuration_folder=tests
        bin_folder=${binaries}/${arch_name}
        mkdir -p ${bin_folder}

        # Compile PROD
        if ${compile_prod}; then
            arch_file_prod=${cfg}/arch/${platform}/${model}/arch-${arch_name}-prod.fcm
            target_exe=${model}_prod.exe
            fcm=${model_sources}/arch/arch-${arch_name}-prod.fcm
            cp ${arch_file_prod} ${model_sources}/arch/
            sed -i "0,/%XIOS_LIB/ s/%XIOS_LIB.*/%XIOS_LIB            -L$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/lib -lxios/g" ${fcm}
            sed -i "0,/%XIOS_INC/ s/%XIOS_INC.*/%XIOS_INC            -I$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/inc/g" ${fcm}
            compilation_command=$(echo ${model_sources}/makenemo -m ${arch_name}-prod -n ${arch_name}_prod -a BENCH -j ${ntasks})
            eval ${compilation_command}
            cp ${model_sources}/${configuration_folder}/${arch_name}_prod/EXP00/nemo ${bin_folder}/${target_exe}
        fi

        # Compile TRACE
        if ${compile_trace}; then
            arch_file_trace=${cfg}/arch/${platform}/${model}/arch-${arch_name}-trace.fcm
            target_exe_trace=${model}_trace.exe
            fcm=${model_sources}/arch/arch-${arch_name}-trace.fcm
            cp ${arch_file_trace} ${model_sources}/arch/
            sed -i "0,/%XIOS_LIB/ s/%XIOS_LIB.*/%XIOS_LIB            -L$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/lib -lxios/g" ${fcm}
            sed -i "0,/%XIOS_INC/ s/%XIOS_INC.*/%XIOS_INC            -I$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/inc/g" ${fcm}
            compilation_command=$(echo ${model_sources}/makenemo -m ${arch_name}-trace -n ${arch_name}_trace -a BENCH -j ${ntasks})
            eval ${compilation_command}
            cp ${model_sources}/${configuration_folder}/${arch_name}_trace/EXP00/nemo ${bin_folder}/${target_exe_trace}
        fi

        # Copy xios binary
        cp ${exp_root}/xios/bin/xios_server.exe ${bin_folder}/xios_server.exe
    done
}

#####################################################################################################################
# Path variables: compilation, project
# Other variables: model, branch, platform, ntasks
# Purpose: Compiles all arch YML configurations for ECEARTH 4 stated in the ARCH_NAMES AS variable
#####################################################################################################################
function compile_ecearth4()
{
    model_sources=${compilation}/${model}_${branch}

    set +u
    module load conda
    conda activate /hpcperm/c3et/conda/ece4 

    # Fix for autosubmit logs
    sed -i "s/dst: 'log\/{{\"%03d\" % experiment.schedule.leg.num}}'/dst: 'log\/{{\"%03d\" % experiment.schedule.leg.num}}'\n    ignore_not_found: true/" ${model_sources}/runtime/se/scriptlib/main.yml

    # Update number of tasks
    cp ${project}/configurations/model/${model}/user-settings-hpc2020.yml ${model_sources}/sources/se
    sed -i "s/JOBS/${ntasks}/" ${model_sources}/sources/se/user-settings-hpc2020.yml

    # Compile all arch stated in AS
    for arch_name in ${arch_names}; do
        # Compile production
        if ${compile_prod}; then
            cd ${compilation}
            arch_name_prod=${arch_name}-prod
            arch_file=${cfg}/arch/${platform}/${model}/${arch_name_prod}.yml
            mkdir -p ${arch_name_prod}
            rsync -av --exclude='*.svn*' ${model_sources}/ ${arch_name_prod}
            sed -i "/NLOGPRT/{n;s/.*/    1 0 1/}" ${arch_name_prod}/runtime/se/templates/oasis/namcouple.j2
            cd ${arch_name_prod}/sources/se
            cp ${arch_file} platforms
            se user-settings-hpc2020.yml platforms/${arch_name_prod}.yml compile-all.yml
        fi

        # Compile trace
        if ${compile_trace}; then
            cd ${compilation}
            arch_name_trace=${arch_name}-trace
            arch_file=${cfg}/arch/${platform}/${model}/${arch_name_trace}.yml
            mkdir -p ${arch_name_trace}
            rsync -av --exclude='*.svn*' ${model_sources}/ ${arch_name_trace}
            # Apply magiccut sentinel patch
            cd ${compilation}/${arch_name_trace}/sources/oifs-43r3v2
            git apply ${cfg}/trace/model/${model}/sentinel.diff

            cd ${compilation}/${arch_name_trace}/sources/se
            cp ${arch_file} platforms
            se user-settings-hpc2020.yml platforms/${arch_name_trace}.yml compile-all.yml
        fi
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
    ./configure CC=$(which mpicxx) CXX=$(which mpicc) --prefix=$(pwd)
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
if echo ${members[@]} | grep -q -w "HardwareBenchmarks"; then
    compile_hw
fi

compile_prod=true
compile_trace=true
echo ${members[@]} | grep -qwE "CompilationEfficiency|WeakScaling|StrongScaling" || compile_prod=false
echo ${members[@]} | grep -qw Tracing || compile_trace=false

# Compile all model arch configurations
if ${compile_prod} || ${compile_trace}; then
    compile_${model}
fi