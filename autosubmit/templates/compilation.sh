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
branch=%MODEL.BRANCH%
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
    target_exe=${model}.exe
    fcm=${model_sources}/arch/arch-${arch_name}.fcm
    cp ${arch_file} ${model_sources}/arch/
    sed_exp_root=${exp_root//\//\\\/}
    sed -i "0,/%XIOS_LIB/ s/%XIOS_LIB.*/%XIOS_LIB            -L${sed_exp_root}\/xios\/lib -lxios/g" ${fcm}
    sed -i "0,/%XIOS_INC/ s/%XIOS_INC.*/%XIOS_INC            -I${sed_exp_root}\/xios\/inc/g"        ${fcm}
    compilation_command=$(echo ${model_sources}/makenemo -m ${arch_name} -n ${arch_name} -a BENCH -j ${ntasks})
    eval ${compilation_command}
    cp ${model_sources}/${configuration_folder}/${arch_name}/EXP00/nemo ${bin_folder}/${target_exe}

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
    local inidata=%EXPERIMENT.INIDATA%
    local sed_inidata=${inidata//\//\\\/}
    # shellcheck source=proj/auto-performance-profiling/cfg/utils/ecearth4/se.sh
    . ${cfg}/utils/${model}/se.sh

    model_sources=${compilation}/${model}_${branch}

    set +u

    # Update number of tasks
    cp ${project}/configurations/model/${model}/user-settings-${current_arch,,}.yml ${model_sources}/scripts/build/user-settings.yml
    sed -i "s/JOBS/${ntasks}/" ${model_sources}/scripts/build/user-settings.yml

    se_env_${current_arch,,} trunk

    arch_file=${cfg}/arch/${platform}/${model}/${arch_name}.yml
    arch_dir=${compilation}/${arch_name}

    mkdir -p ${arch_dir}
    rsync -av --exclude='*.svn*' ${model_sources}/ ${arch_dir}

    # Enable lucia logs
    sed -i "s/nlogprt.*/nlogprt: \"1 0 1\"/" ${arch_dir}/scripts/runtime/templates/oasis/namcouple.yml

    printf "$(cat ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake)\nstring(CONCAT IFS_Fortran_FLAGS \"\${IFS_Fortran_FLAGS} -finstrument-functions -g\")" > ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake
    printf "$(cat ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake)\nstring(CONCAT ECBUILD_SHARED_LINKER_FLAGS \"\${ECBUILD_SHARED_LINKER_FLAGS} -rdynamic\")" > ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake
    
    # Add magiccut sentinel function
    cd ${arch_dir}/sources/oifs-48r1 || exit
    git apply ${cfg}/trace/model/${model}/sentinel.diff
    
    cd ${arch_dir}/scripts/build || exit
    cp "${arch_file}" ../platforms

    sed -i "s/INIDATA/${sed_inidata}/" ../platforms/${arch_name}.yml

    # Compile using SE
    se user-settings.yml ../platforms/${arch_name}.yml compile-components.yml
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
        cd ${compilation}/STREAM || exit
        gcc -fopenmp -D_OPENMP stream.c -o stream
    fi

    if ${osu_enabled}; then
        cd ${compilation}/osu-micro-benchmarks || exit
        ./configure CC="$(which mpicc)" CXX="$(which mpicxx)" --prefix="$(pwd)"
        make install -j
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

if [ ${current_member} = "HardwareBenchmarks" ]; then compile_hw; 
elif ${compile_model}; then compile_${model}; fi
