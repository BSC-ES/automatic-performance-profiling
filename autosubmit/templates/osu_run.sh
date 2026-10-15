#!/bin/bash
#####################################################################################################################
# osu_run.sh
# Brief: This script runs the osu benchmark
#####################################################################################################################

###################
# AS variables
###################
function run_osu() {
    compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
    cfg=%COMMON_PATH_LOCATIONS.CFG%
    platform=%DEFAULT.HPCARCH%
    platform=${platform,,}
    env_sources=${cfg}/arch/${platform}/hw_benchmarks/environment.env
    run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
    n_cores=%NUMPROC%

    # shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
    . ${cfg}/utils/bash/utils.sh

    . ${env_sources}

    osu_tests=($(bashify_array "%HW_BENCHMARKS.OSU.TESTS%" true))

    mkdir -p $run_folder/hardware_benchmarks/OSU_RUN/${n_cores}
    cd $run_folder/hardware_benchmarks/OSU_RUN/${n_cores}

    for test in "${osu_tests[@]}"
    do
        test_name=${test##*/}
        cp $compilation/osu-micro-benchmarks/c/mpi/${test} ${test_name}
        srun -n ${n_cores} ./${test_name} > ${test_name}_${n_cores}.txt
    done

    mkdir -p $run_folder/hardware_benchmarks/OSU_RUN/DATA
    cp *txt $run_folder/hardware_benchmarks/OSU_RUN/DATA
}


osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
osu_enabled=${osu_enabled,,}

${osu_enabled} && run_osu