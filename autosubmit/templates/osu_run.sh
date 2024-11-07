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
    env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
    run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
    n_cores=%NUMPROC%
    osu_tests=(%HW_BENCHMARKS.OSU_TESTS%)

    source ${env_sources}
    mkdir -p $run_folder/hardware_benchmarks/OSU_RUN/${n_cores}
    cd $run_folder/hardware_benchmarks/OSU_RUN/${n_cores}

    for test in "${osu_tests[@]}"
    do
        test_name=${test##*/}
        cp $compilation/osu-micro-benchmarks-5.6.3/mpi/${test} ${test_name}
        srun -n ${n_cores} ./${test_name} > ${test_name}_${n_cores}.txt
    done

    mkdir -p $run_folder/hardware_benchmarks/OSU_RUN/DATA
    cp *txt $run_folder/hardware_benchmarks/OSU_RUN/DATA
}


osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
osu_enabled=${osu_enabled,,}

${osu_enabled} && run_osu