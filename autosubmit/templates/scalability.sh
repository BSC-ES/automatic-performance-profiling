#MEMBERS =  CompilationEfficiency HardwareBenchmarks WeakScaling StrongScaling
#RUN_FOLDER =  hardware_benchmarks compilation_efficiency strong_scaling weakscaling

test_name=""
if [ "%MEMBER%" = "compilation_efficiency" ];
then
  test_name="compilation_efficiency"
  export test_name="compilation_efficiency"
elif [ "%MEMBER%" = "StrongScaling" ];
then
  test_name="strong_scaling"
  export test_name="strong_scaling"
elif [ "%MEMBER%" = "weakscaling" ];
then
  test_name="weakscaling"
  export test_name="weakscaling"
fi
#MEMBERS=HardwareBenchmarks CompilationEfficiency WeakScaling StrongScaling
source %ENV_SOURCES%
source %INIDATA_ROOT%/$test_name/param_bash.cfg
mkdir -p %RUN_ROOT%/$test_name/scalability_%NUMPROC%
# Link inidata
cp %INIDATA_ROOT%/$test_name/* %RUN_ROOT%/$test_name/scalability_%NUMPROC%/
ln -rsf %INIDATA_ROOT%/original %RUN_ROOT%/$test_name/scalability_%NUMPROC%/
rsync -rv --exclude=.nc %INIDATA_ROOT% %RUN_ROOT%/$test_name/scalability_%NUMPROC%/

if [ "%MODEL%" = "nemo" ] || [ "%MODEL%" = "NEMO" ];
then
    run_folder=%RUN_ROOT%
    number_of_cores=%NUMPROC%
    # Copy everything from reference run_folder
    cp --remove-destination %COMPILATION_ROOT%/$test_name/${configuration_folder}/${configuration_name}_vanilla/EXP00/* %RUN_ROOT%/$test_name/scalability_%NUMPROC%
    # cp --remove-destination /gpfs/scratch/bsc32/bsc32070/a036/compilation/tests/BENCH_vanilla/EXP00/* %RUN_ROOT%/strong_scaling/scalability_%NUMPROC%
    # Copy xios server
    cp %BINARIES_ROOT%/$test_name/xios_server.exe %RUN_ROOT%/$test_name/scalability_%NUMPROC%/

    # Change namelist parameters
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/scalability_%NUMPROC%/namelist_cfg nn_itend ${test_steps}
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/scalability_%NUMPROC%/namelist_cfg ln_icebergs .false.
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/scalability_%NUMPROC%/namelist_ref ln_meshmask .false.
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/scalability_%NUMPROC%/namelist_ref ln_timing   .true.
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/scalability_%NUMPROC%/namelist_cfg ln_timing   .true.
    # Disable output
    if [ ${output} = FALSE ] ; then \
       sed -i "s/^.*file_definition.*$$//g" %RUN_ROOT%/$test_name/scalability_%NUMPROC%/context_nemo.xml ; \
    fi
fi
cd %RUN_ROOT%/$test_name/scalability_%NUMPROC%
set -xuve
if [ "%MODEL%" = "nemo" ] || [ "%MODEL%" = "NEMO" ];
then
 time mpirun -genv I_MPI_DEBUG=4 -n %NUMPROC% ./nemo # to change bin name

fi

set +xuve
# Rename timing output
mv timing.output %NUMPROC%_test.timing
python3 %PROJECT_ROOT%/cfg/parser/utils/model/nemo/convert_timing_files.py -i %NUMPROC%_test.timing -o %NUMPROC%_test.timing







