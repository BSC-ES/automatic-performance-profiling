# HW benchmark osu_run
#MEMBERS=HardwareBenchmarks CompilationEfficiency WeakScaling StrongScaling
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
mkdir -p $compilation
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
source %PARAMETERS_ENV_CONFIG.ENV_SOURCES%
source $inidata/hardware_benchmarks/param_bash.cfg
mkdir -p $run_folder/hardware_benchmarks/OSU_RUN_%NUMPROC%
mkdir -p /gpfs/scratch/bsc32/bsc32070/a036/run/hardware_benchmarks/OSU_RUN_%NUMPROC%
cd /gpfs/scratch/bsc32/bsc32070/a036/run/hardware_benchmarks/OSU_RUN_%NUMPROC%


for test in ${osu_tests[@]}
do
  test_name=${test##*/}
  cp $compilation/osu-micro-benchmarks-5.6.3/mpi/${test} ${test_name}
  mpirun -np 48 ./${test_name} > ${test_name}_48.txt
done
mkdir -p $run_folder/hardware_benchmarks/DATA
cp *txt $run_folder/hardware_benchmarks/DATA
