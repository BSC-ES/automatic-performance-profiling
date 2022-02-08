#MEMBERS=HardwareBenchmarks CompilationEfficiency WeakScaling StrongScaling
source %ENV_SOURCES%
source %INIDATA_ROOT%/hardware_benchmarks/param_bash.cfg
mkdir -p %RUN_ROOT%/hardware_benchmarks/OSU_RUN_%NUMPROC%
mkdir -p /gpfs/scratch/bsc32/bsc32070/a036/run/hardware_benchmarks/OSU_RUN_%NUMPROC%
cd /gpfs/scratch/bsc32/bsc32070/a036/run/hardware_benchmarks/OSU_RUN_%NUMPROC%


for test in ${osu_tests[@]}
do
  test_name=${test##*/}
  cp %COMPILATION_ROOT%/osu-micro-benchmarks-5.6.3/mpi/${test} ${test_name}
  mpirun -np 48 ./${test_name} > ${test_name}_48.txt
done
mkdir -p %RUN_ROOT%/hardware_benchmarks/DATA
cp *txt %RUN_ROO%/hardware_benchmarks/DATA
