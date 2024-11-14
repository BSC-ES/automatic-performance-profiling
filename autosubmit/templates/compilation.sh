#!/bin/bash
#####################################################################################################################
# compilation.sh
# Brief: This script compiles the model using the arch files set in the AS config
#####################################################################################################################

set -xv
###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
ntasks=%THREADS%
branch=%MODEL.BRANCH_LIST%
exp_root=%CURRENT_ROOTDIR%
cfg=%COMMON_PATH_LOCATIONS.CFG%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
members="%EXPERIMENT.MEMBERS%"
current_arch=%HPCARCH%
arch_name=%CURRENT_TEST_NAME%
current_member=%MEMBER%

#####################################################################################################################
# Brief: Compiles all arch FCM configurations for NEMO configured in the ARCH_NAMES AS variable
# Global:
#   - Paths: exp_root, project, binaries, compilation
#   - Other: platform, ntasks, model, branch, arch_name
# Param: None
#####################################################################################################################
function compile_nemo()
{
    # Compile XIOS
    cd ${exp_root}/xios || exit
    cp $project/cfg/arch/${platform}/xios/arch-* arch
    ./make_xios --dev --arch ifort_${platform} --job ${ntasks}
    
    # Compile NEMO
    model_sources=${compilation}/${model}_${branch}
    cd ${model_sources} || exit
    
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
}

#####################################################################################################################
# Brief: Compiles all arch YML configurations for ECEARTH 4 stated in the ARCH_NAMES AS variable
# Global:
#   - Paths: compilation, project, cfg
#   - Other: model, branch, arch_name, platform, ntasks
# Param: None
#####################################################################################################################
function compile_ecearth4()
{
    . ${cfg}/utils/${model}/se.sh

    model_sources=${compilation}/${model}_${branch}

    set +u

    # Fix for autosubmit logs
    sed -i "s/dst: 'log\/{{\"%03d\" % experiment.schedule.leg.num}}'/dst: 'log\/{{\"%03d\" % experiment.schedule.leg.num}}'\n    ignore_not_found: true/" ${model_sources}/scripts/runtime/scriptlib/main.yml

    # Update number of tasks
    cp ${project}/configurations/model/${model}/user-settings-${current_arch,,}.yml ${model_sources}/scripts/build/user-settings.yml
    sed -i "s/JOBS/${ntasks}/" ${model_sources}/scripts/build/user-settings.yml

    se_env_${current_arch,,} trunk

    # Compile production
    if ${compile_prod}; then
        coupling_enabled="%STRONGSCALING.COUPLING.ENABLED%"
        coupling_enabled=${coupling_enabled,,}
        arch_name_prod=${arch_name}-prod
        arch_file=${cfg}/arch/${platform}/${model}/${arch_name_prod}.yml
        prod_dir=${compilation}/${arch_name_prod}

        mkdir -p ${prod_dir}
        rsync -av --exclude='*.svn*' ${model_sources}/ ${prod_dir}

        # Turn on lucia if enabled
        ${coupling_enabled} && sed -i "s/nlogprt.*/nlogprt: \"1 0 1\"/" ${prod_dir}/scripts/runtime/templates/oasis/namcouple.yml
        
        cd ${prod_dir}/scripts/build || exit
        cp ${arch_file} ../platforms

        se user-settings.yml ../platforms/${arch_name_prod}.yml compile-all.yml
    fi

    # Compile trace
    if ${compile_trace}; then
        arch_name_trace=${arch_name}-trace
        arch_file=${cfg}/arch/${platform}/${model}/${arch_name_trace}.yml
        trace_dir=${compilation}/${arch_name_trace}
    
        mkdir -p ${trace_dir}
        rsync -av --exclude='*.svn*' ${model_sources}/ ${trace_dir}

        # Apply magiccut sentinel patch
        cd ${trace_dir}/sources/oifs-43r3v2 || exit
        git apply ${cfg}/trace/model/${model}/sentinel.diff

        cd ${trace_dir}/scripts/build || exit
        cp ${arch_file} ../platforms
        se user-settings.yml ../platforms/${arch_name_trace}.yml compile-all.yml
    fi
}


#####################################################################################################################
# Brief: Compiles STREAM and OSU HW benchmarks
# Global:
#   - Paths: compilation
#####################################################################################################################
function compile_hw()
{
    local osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
    local osu_enabled=${osu_enabled,,}
    local stream_enabled=%HW_BENCHMARKS.STREAM.ENABLED%
    local stream_enabled=${stream_enabled,,}

    if ${stream_enabled}; then
        cd ${compilation}/STREAM
        gcc -fopenmp -D_OPENMP stream.c -o stream
    fi

    if ${osu_enabled}; then
        cd ${compilation}/osu-micro-benchmarks-5.6.3
        ./configure CC=$(which mpicxx) CXX=$(which mpicc) --prefix=$(pwd)
        make install
        make
    fi
}

###################
# Start script
###################

mkdir -p $compilation
mkdir -p $binaries

source $env_sources

compile_prod=true
compile_trace=true
echo "${members[@]}" | grep -qwE "CompilationEfficiency|WeakScaling|StrongScaling" || compile_prod=false
echo "${members[@]}" | grep -qw Tracing || compile_trace=false

# Compile all model arch configurations
if [ ${current_member} = "HardwareBenchmarks" ]; then
    compile_hw
elif ${compile_prod} || ${compile_trace}; then
    compile_${model}
fi
