#MEMBERS =  CompilationEfficiency HardwareBenchmarks WeakScaling StrongScaling
#RUN_FOLDER =  hardware_benchmarks compilation_efficiency strong_scaling weakscaling
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%COMMON.MODEL%
number_of_cores=%NUMPROC%
test="%CURRENT_TEST_NAME%"

if [ "$current_member" = "CompilationEfficiency" ];
then
    test_name="compilation_efficiency"
    export test_name="compilation_efficiency"
    test_name_=${test_name}/${test}
elif [ "$current_member" = "StrongScaling" ];
then
    test_name="strong_scaling"
    export test_name="strong_scaling"
    test_name_=${test_name}/${test}
elif [ "$current_member" = "WeakScaling" ];
then
    test_name="weakscaling"
    export test_name="weakscaling"
    test_name_=${test_name}/${test}
fi

source ${env_sources}
source $inidata/$test_name_/param_bash.cfg
mkdir -p $run_folder/$test_name_/scalability_$number_of_cores

# Link inidata
cp $inidata/$test_name_/* $run_folder/$test_name_/scalability_$number_of_cores/
ln -rsf $inidata/original $run_folder/$test_name_/scalability_$number_of_cores/
rsync -rv --exclude=.nc $inidata $run_folder/$test_name_/scalability_$number_of_cores/

cd $run_folder/$test_name_/scalability_$number_of_cores

if [ "$model" = "nemo" ] || [ "$model" = "NEMO" ];
then
    # Copy everything from reference run_folder
    cp --remove-destination $compilation/$test_name_/${configuration_folder}/${configuration_name}_vanilla/EXP00/* $run_folder/$test_name_/scalability_$number_of_cores
    # Copy xios server
    cp $binaries/$test_name_/xios_server.exe $run_folder/$test_name_/scalability_$number_of_cores/
    
    # Change namelist parameters
    $project/cfg/replace_namelist_parameter $run_folder/$test_name_/scalability_$number_of_cores/namelist_cfg nn_itend ${test_steps}
    $project/cfg/replace_namelist_parameter $run_folder/$test_name_/scalability_$number_of_cores/namelist_cfg ln_icebergs .false.
    $project/cfg/replace_namelist_parameter $run_folder/$test_name_/scalability_$number_of_cores/namelist_ref ln_meshmask .false.
    $project/cfg/replace_namelist_parameter $run_folder/$test_name_/scalability_$number_of_cores/namelist_ref ln_timing   .true.
    $project/cfg/replace_namelist_parameter $run_folder/$test_name_/scalability_$number_of_cores/namelist_cfg ln_timing   .true.
    # Disable output
    if [ ${output} = FALSE ] ; then \
        sed -i "s/^.*file_definition.*$$//g" $run_folder/$test_name_/scalability_$number_of_cores/context_nemo.xml ; \
    fi

    time mpirun -genv I_MPI_DEBUG=4 -n $number_of_cores ./nemo # to change bin name
fi

# Rename timing output
mv timing.output ${number_of_cores}_test.timing
python3 $project/cfg/parser/utils/model/nemo/convert_timing_files.py -i ${number_of_cores}_test.timing -o ${number_of_cores}_test.timing