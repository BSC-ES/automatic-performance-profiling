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
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
ntasks=%THREADS%
build_tasks=%PROCESSORS%
branch=%MODEL.BRANCH%
exp_root=%CURRENT_ROOTDIR%
cfg=%COMMON_PATH_LOCATIONS.CFG%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
current_arch=%HPCARCH%
arch_name=%CURRENT_TEST_NAME%

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

#####################################################################################################################
# Brief: Compiles all arch FCM configurations for NEMO configured in the ARCH_NAMES AS variable
# Global:
#   - Paths: exp_root, project, binaries, compilation
#   - Other: platform, ntasks, model, branch, arch_name
# Param: None
#####################################################################################################################
function compile_nemo()
{
    env_file=${cfg}/arch/${platform}/${model}/${arch_name}.env
    . ${env_file}

    cd ${exp_root}/xios || exit
    cp $project/cfg/arch/${platform}/xios/arch-* arch
    # Use GCC/OpenMPI for XIOS (ICC has shared_ptr ambiguity with C++11)
    ./make_xios --dev --arch gcc_${platform} --job ${ntasks}
    
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

    cp ${project}/configurations/model/${model}/user-settings-${current_arch,,}.yml ${model_sources}/scripts/build/user-settings.yml
    sed -i "s/JOBS/${ntasks}/" ${model_sources}/scripts/build/user-settings.yml

    se_env_${current_arch,,} trunk

    arch_file=${cfg}/arch/${platform}/${model}/${arch_name}.yml
    arch_dir=${compilation}/${arch_name}

    mkdir -p ${arch_dir}
    rsync -av --exclude='*.svn*' ${model_sources}/ ${arch_dir}

    sed -i "s/nlogprt.*/nlogprt: \"1 0 1\"/" ${arch_dir}/scripts/runtime/templates/oasis/namcouple.yml

    printf "$(cat ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake)\nstring(CONCAT IFS_Fortran_FLAGS \"\${IFS_Fortran_FLAGS} -finstrument-functions -g\")" > ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake
    printf "$(cat ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake)\nstring(CONCAT ECBUILD_SHARED_LINKER_FLAGS \"\${ECBUILD_SHARED_LINKER_FLAGS} -rdynamic\")" > ${arch_dir}/sources/oifs-48r1/ifs-source/cmake/compile_flags.cmake
    
    cd ${arch_dir}/sources/oifs-48r1 || exit
    git apply ${cfg}/trace/model/${model}/sentinel.diff
    
    cd ${arch_dir}/scripts/build || exit
    cp "${arch_file}" ../platforms

    sed -i "s/INIDATA/${sed_inidata}/" ../platforms/${arch_name}.yml

    se user-settings.yml ../platforms/${arch_name}.yml compile-components.yml
}

#####################################################################################################################
# Brief: Links the ExternalData store of the HPCW compilation directory to the shared object cache. HPCW appends its
#        own stores (${CMAKE_SOURCE_DIR}/hpcw-store) to the CMake ExternalData module, so setting the
#        ExternalData_OBJECT_STORES environment variable has no effect and the source-dir store has to be linked.
#        Objects already cached in the shared store are then reused instead of being downloaded again by every
#        compilation job (the ICON inputs alone are several tens of GB).
# Global:
#   - Other: model
# Param:
#   - arch_dir: HPCW source/build directory of the current arch
#####################################################################################################################
function link_hpcw_store()
{
    local arch_dir="$1"
    local store=%MODEL.STORE%
    local algo

    [ -n "${store}" ] || return 0

    mkdir -p "${store}" "${arch_dir}"

    if [ -d "${arch_dir}/hpcw-store" ] && [ ! -L "${arch_dir}/hpcw-store" ]; then
        for algo in MD5 SHA256; do
            [ -d "${arch_dir}/hpcw-store/${algo}" ] || continue
            mkdir -p "${store}/${algo}"
            mv -n "${arch_dir}/hpcw-store/${algo}"/* "${store}/${algo}/" 2>/dev/null || true
        done
        rm -rf "${arch_dir:?}/hpcw-store"
    fi

    ln -sfn "${store}" "${arch_dir}/hpcw-store"
}

#####################################################################################################################
# Brief: Compiles the HPCW model. It sources the MN5 environment of the selected component with the APP
#        overrides (cfg/arch/<platform>/hpcw/<component>/<ARCH>.env) and builds it with the parallelism of
#        the job
# Global:
#   - Paths: compilation, cfg
#   - Other: platform, model, branch, arch_name, build_tasks
# Param: None
#####################################################################################################################
function compile_hpcw()
{
    local model_sources=${compilation}/${model}_${branch}
    local arch_dir=${compilation}/${arch_name}
    local jobs=${build_tasks:-4}
    local component
    component=$(bashify_array "%MODEL.COMPONENTS%" true)
    component=$(echo "${component%% *}" | tr '[:upper:]' '[:lower:]')
    local arch_cmake=${cfg}/arch/${platform}/${model}/${component}/${arch_name}.cmake
    local env_file=${cfg}/arch/${platform}/${model}/${component}/${arch_name}.env

    rsync -av ${model_sources}/ ${arch_dir}

    link_hpcw_store "${arch_dir}"

    mkdir -p ${arch_dir}/build/${component}
    cd ${arch_dir}/build/${component} || exit

    # A build interrupted by the scheduler can leave a 0-byte object behind; make treats it as
    # up to date and the link then fails with undefined references, so drop empty objects
    find ${arch_dir}/build -name '*.o' -size 0 -delete

    HPCW_SOURCE_DIR=${arch_dir} source ${env_file}

    if [ "${component}" == "icon" ]; then
        # ICON-specific cmake flags: stage data inputs, enable large inputs
        local cmake_flags="-DBUILD_PARALLEL_LEVEL=${jobs} -DENABLE_icon=ON -DCMAKE_TOOLCHAIN_FILE=${arch_cmake} -DHPCW_SOURCE_DIR=${arch_dir} -DCOPY_ICON_INPUTS=ON -DENABLE_icon_large_inputs=ON"

        cmake ${cmake_flags} ${arch_dir}

        make offline -j1

        make VERBOSE=1 -j${jobs}
    else
        sed -i "s/%FCFLAGS -g.*/%FCFLAGS \${CMAKE_Fortran_FLAGS} >/g" ${arch_dir}/projects/nemo.cmake

        local cmake_flags="-DBUILD_PARALLEL_LEVEL=${jobs} -DENABLE_nemo=ON -DCMAKE_TOOLCHAIN_FILE=${arch_cmake} -DHPCW_SOURCE_DIR=${arch_dir}"

        cmake ${cmake_flags} ${arch_dir}

        make VERBOSE=1 -j${jobs}
    fi
}


#####################################################################################################################
# Brief: Compiles STREAM and OSU HW benchmarks
# Global:
#   - Paths: compilation
#####################################################################################################################
function compile_hw()
{
    local env_sources=${cfg}/arch/${platform}/hw_benchmarks/environment.env
    local osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
    local osu_enabled=${osu_enabled,,}
    local stream_enabled=%HW_BENCHMARKS.STREAM.ENABLED%
    local stream_enabled=${stream_enabled,,}

    . ${env_sources}

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

compile_${model}
