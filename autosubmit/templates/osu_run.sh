compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
n_cores=%NUMPROC%

source ${env_sources}
source $inidata/hardware_benchmarks/param_bash.cfg
mkdir -p $run_folder/hardware_benchmarks/OSU_RUN/%NUMPROC%
cd $run_folder/hardware_benchmarks/OSU_RUN/%NUMPROC%

for test in ${osu_tests[@]}
do
    test_name=${test##*/}
    cp $compilation/osu-micro-benchmarks-5.6.3/mpi/${test} ${test_name}
    mpirun -np ${n_cores} ./${test_name} > ${test_name}_${n_cores}.txt
done

mkdir -p $run_folder/hardware_benchmarks/OSU_RUN/DATA
cp *txt $run_folder/hardware_benchmarks/OSU_RUN/DATA
