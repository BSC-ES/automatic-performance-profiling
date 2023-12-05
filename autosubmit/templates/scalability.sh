###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_folder=%COMMON_PATH_LOCATIONS.RUN_ROOT%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH_LIST%
number_of_cores=%NUMPROC%
test="%CURRENT_TEST_NAME%"

#####################################################################################################################
# Path variables: inidata, binaries, compilation, run_dir
# Other variables: test_name_, number_of_cores
# Purpose: Updates the namelists with the AS member configuration and runs NEMO
#####################################################################################################################
function run_nemo()
{
    model_sources=${model}_${branch}
    output="%MODEL.OUTPUT%"
    test_steps="%MODEL.TEST_STEPS%"
    configuration_folder=tests
    
    # Link inidata
    cp ${inidata}/$test_name_/* ${run_dir}
    ln -rsf ${inidata}/original ${run_dir}
    rsync -rv --exclude=.nc ${inidata} ${run_dir}

    # Copy everything from reference run_folder
    cp --remove-destination ${compilation}/${model_sources}/${configuration_folder}/${arch_name}_prod/EXP00/* ${run_dir}
    cp ${run_dir}/namelist_cfg_${model_resolution}_like ${run_dir}/namelist_cfg

    # Change namelist parameters
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg nn_itend    ${test_steps}
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_icebergs .false.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref ln_meshmask .false.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_ref ln_timing   .true.
    ${project}/cfg/replace_namelist_parameter ${run_dir}/namelist_cfg ln_timing   .true.
    # Disable output
    if [ ${output} = False ] ; then \
        sed -i "s/^.*file_definition.*$$//g" ${run_dir}/context_nemo.xml ; \
    fi

    cd ${run_dir}
    time mpirun -n $number_of_cores ./nemo

    # Rename timing output
    mv timing.output ${number_of_cores}_test.timing
    python3 ${project}/cfg/parser/utils/model/nemo/convert_timing_files.py -i ${number_of_cores}_test.timing -o ${number_of_cores}_test.timing
}

#####################################################################################################################
# Path variables: run_folder, compilation
# Other variables: test_name_, model, number_of_cores, test
# Purpose: Updates the SE config file with the AS config and runs EC-Earth 4
#####################################################################################################################
function run_ecearth4()
{
    # Remove all run folder content just in case
    rm -rf ${run_dir}/*

    cd ${compilation}/${arch_name}-prod/runtime/se

    # Update all variable according to AS config
    config_file=config-${test}-${number_of_cores}.yml
    cp ${project}/configurations/model/${model}/config.yml ${config_file}

    sed_run_dir=$(echo ${run_dir} | sed 's_/_\\/_g')
    ecearth_root=${compilation}/${arch_name}-prod
    sed_ecearth_root=$(echo ${ecearth_root} | sed 's_/_\\/_g')

    oifs_procs=%CURRENT_OIFS_PROCS%
    nemo_procs=%CURRENT_NEMO_PROCS%
    xios_procs=%CURRENT_XIOS_PROCS%

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"        ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/" ${config_file}
    sed -i "s/OIFS_PROCS/${oifs_procs}/"         ${config_file}
    sed -i "s/OIFS_PPN/${oifs_procs}/"           ${config_file}
    sed -i "s/NEMO_PROCS/${nemo_procs}/"         ${config_file}
    sed -i "s/NEMO_PPN/${nemo_procs}/"           ${config_file}
    sed -i "s/XIOS_PROCS/${xios_procs}/"         ${config_file}
    sed -i "s/XIOS_PPN/${xios_procs}/"           ${config_file}

    # Disable DR HOOK as it may cause issues
    sed -i "s/DR_HOOK=1/DR_HOOK=0/"              templates/launch/run-srun-multiprog.sh.j2

    # Activate the SE enviroment and run
    set +u
    module load conda
    conda activate /hpcperm/c3et/conda/ece4
    se --nocolor --loglevel debug ../../sources/se/platforms/${arch_name}-prod.yml ${config_file} scriptlib/main.yml   
}

###################
# Start script
###################
if [ "$current_member" = "CompilationEfficiency" ];
then
    test_name="compilation_efficiency"
    test_name_=${test_name}/${test}
    arch_name=${test}
    model_resolution=%COMPILATION_EFFICIENCY.MODEL_RESOLUTION%
elif [ "$current_member" = "StrongScaling" ];
then
    test_name="strong_scaling"
    test_name_=${test_name}/${test}
    arch_name=%STRONGSCALING.ARCH_NAME%
    model_resolution=%STRONGSCALING.MODEL_RESOLUTION%
elif [ "$current_member" = "WeakScaling" ];
then
    test_name="weakscaling"
    test_name_=${test_name}/${test}
    arch_name=%WEAKSCALING.ARCH_NAME%
    model_resolution=%WEAKSCALING.MODEL_RESOLUTION%
fi

source ${env_sources}
run_dir=${run_folder}/${test_name_}/scalability_${number_of_cores}
mkdir -p ${run_dir}

run_${model}

