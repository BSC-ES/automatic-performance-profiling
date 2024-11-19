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

    arch_file=${cfg}/arch/${platform}/${model}/arch-${arch_name}.fcm
    target_exe=${model}_trace.exe
    fcm=${model_sources}/arch/arch-${arch_name}.fcm
    cp ${arch_file} ${model_sources}/arch/
    sed -i "0,/%XIOS_LIB/ s/%XIOS_LIB.*/%XIOS_LIB            -L$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/lib -lxios/g" ${fcm}
    sed -i "0,/%XIOS_INC/ s/%XIOS_INC.*/%XIOS_INC            -I$(echo ${exp_root} | sed 's_/_\\/_g')\/xios\/inc/g" ${fcm}
    compilation_command=$(echo ${model_sources}/makenemo -m ${arch_name} -n ${arch_name}_trace -a BENCH -j ${ntasks})
    eval ${compilation_command}
    cp ${model_sources}/${configuration_folder}/${arch_name}_trace/EXP00/nemo ${bin_folder}/${target_exe}

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
    coupling_enabled="%STRONGSCALING.COUPLING.ENABLED%"
    coupling_enabled=${coupling_enabled,,}

    arch_file=${cfg}/arch/${platform}/${model}/${arch_name}.yml
    arch_dir=${compilation}/${arch_name}

    mkdir -p ${arch_dir}
    rsync -av --exclude='*.svn*' ${model_sources}/ ${arch_dir}

    # Turn on lucia if enabled
    [ ${current_member} = "StrongScaling" ] && ${coupling_enabled} && sed -i "s/nlogprt.*/nlogprt: \"1 0 1\"/" ${arch_dir}/scripts/runtime/templates/oasis/namcouple.yml

    # Apply magiccut sentinel patch
    [ ${current_member} = "Tracing" ] && cd ${trace_dir}/sources/oifs-43r3v2 && git apply ${cfg}/trace/model/${model}/sentinel.diff
    
    cd ${arch_dir}/scripts/build || exit
    cp ${arch_file} ../platforms

    se user-settings.yml ../platforms/${arch_name}.yml compile-all.yml
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

compile_model=true
echo "${members[@]}" | grep -qwE "CompilationEfficiency|WeakScaling|StrongScaling|Tracing" || compile_model=false
${compile_model} && compile_${model}

[ ${current_member} = "HardwareBenchmarks" ] && compile_hw

return 0