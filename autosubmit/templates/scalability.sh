#!/bin/bash
#####################################################################################################################
# scalability.sh
# Brief: This script runs the model to get the SYPD of the current procs config
#####################################################################################################################

###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
current_member=%MEMBER%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH_LIST%
number_of_cores=%NUMPROC%
test="%CURRENT_TEST_NAME%"
platform="%DEFAULT.HPCARCH%"

#####################################################################################################################
# Biref: Updates the namelists with the AS member configuration and runs NEMO
# Global:
#   - Paths: inidata, binaries, compilation, run_dir
#   - Other: test_name, number_of_cores
#####################################################################################################################
function run_nemo()
{
    case "$current_member" in
        "CompilationEfficiency")
            local output="%COMPILATION_EFFICIENCY.OUTPUT%"
            local test_steps="%COMPILATION_EFFICIENCY.TEST_STEPS%" 
            ;;
        "StrongScaling")
            local output="%STRONGSCALING.OUTPUT%"
            local test_steps="%STRONGSCALING.TEST_STEPS%" 
            ;;
        "WeakScaling")
            local output="%WEAKSCALING.OUTPUT%"
            local test_steps="%WEAKSCALING.TEST_STEPS%" 
            ;;
    esac
    run_dir=${run_root}/${test_name}/scalability_nemo_${number_of_cores}
    mkdir -p ${run_dir}

    source ${env_sources}

    model_sources=${model}_${branch}
    configuration_folder=tests
    
    # Link inidata
    cp ${inidata}/$test_name/* ${run_dir}
    ln -rsf ${inidata}/original ${run_dir}
    rsync -rv --exclude=.nc ${inidata} ${run_dir}

    # Copy everything from reference run_root
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

    cd ${run_dir} || exit
    # If weakscaling is run, compute the processors corresponding to the current resolution
    if [ ${current_member} = "WeakScaling" ]; then
        source ${project}/configurations/model/${model}/resolutions.sh 
        local base_procs=%WEAKSCALING.BASE_PROCS%
        local base_resolution=%WEAKSCALING.BASE_RESOLUTION%
        local base_tile_size=${resolutions[$base_resolution]}
        local curr_tile_size=${resolutions[$model_resolution]}
        number_of_cores=$((base_procs*curr_tile_size/base_tile_size))
        local queue=%HPCQUEUE%
        local proj=%CURRENT_PROJ%
        time srun -A ${proj} -q ${queue} -n $number_of_cores ./nemo
    else
        time srun -n $number_of_cores ./nemo
    fi

    # Rename timing output
    mv timing.output ${number_of_cores}_test.timing
    python3 ${project}/cfg/parser/utils/model/nemo/convert_timing_files.py -i ${number_of_cores}_test.timing -o ${number_of_cores}_test.timing
}


#####################################################################################################################
# Brief: Updates the SE config file with the AS config and runs EC-Earth 4
# Global:
#   - Paths: run_root, compilation
#   - Other: test_name, model, number_of_cores, test, branch
#####################################################################################################################
function run_ecearth4()
{
    case "$current_member" in
        "CompilationEfficiency")
            local start_date="%COMPILATION_EFFICIENCY.START_DATE%"
            local end_date="%COMPILATION_EFFICIENCY.END_DATE%"
            local freq="%COMPILATION_EFFICIENCY.FREQ%"
            local interval="%COMPILATION_EFFICIENCY.INTERVAL%"
            local oifs_resolution="%COMPILATION_EFFICIENCY.OIFS_RESOLUTION%"
            local nemo_resolution="%COMPILATION_EFFICIENCY.NEMO_RESOLUTION%"
            ;;
        "StrongScaling")
            local start_date="%STRONGSCALING.START_DATE%"
            local end_date="%STRONGSCALING.END_DATE%"
            local freq="%STRONGSCALING.FREQ%"
            local interval="%STRONGSCALING.INTERVAL%"
            local oifs_resolution="%STRONGSCALING.OIFS_RESOLUTION%"
            local nemo_resolution="%STRONGSCALING.NEMO_RESOLUTION%"
            ;;
        "WeakScaling")
            local start_date="%WEAKSCALING.START_DATE%"
            local end_date"=%WEAKSCALING.END_DATE%"
            local freq="%WEAKSCALING.FREQ%"
            local interval="%WEAKSCALING.INTERVAL%"
            local oifs_resolution="%WEAKSCALING.OIFS_RESOLUTION%"
            local nemo_resolution="%WEAKSCALING.NEMO_RESOLUTION%"
            ;;
    esac

    . ${project}/cfg/utils/${model}/se.sh

    local model_sources=${compilation}/${model}_${branch}
    local oifs_procs=%CURRENT_OIFS_PROCS%
    local nemo_procs=%CURRENT_NEMO_PROCS%
    local xios_procs=%CURRENT_XIOS_PROCS%
    local use_omp_threads="%USE_OMP_THREDS%"
    local oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi

    local test_dir=${run_root}/${test_name}
    local run_id=xios_${xios_procs}_nemo_${nemo_procs}_rnfm_1_oifs_${oifs_procs}
    local run_dir=${test_dir}/scalability_${run_id}
    local src_dir=${compilation}/${arch_name}-prod/sources/

    # Remove all run folder content just in case
    rm -rf ${run_dir}/*

    cd ${compilation}/${arch_name}-prod/scripts/runtime

    # Update all variable according to AS config
    local config_file=config-${test}-${run_id}.yml
    cp ${project}/configurations/model/${model}/experiment_config.yml.tmpl ${config_file}

    local sed_run_dir=$(echo ${run_dir} | sed 's_/_\\/_g')
    local sed_src_dir=$(echo ${src_dir} | sed 's_/_\\/_g')
    local ecearth_root=${compilation}/${arch_name}-prod
    local sed_ecearth_root=$(echo ${ecearth_root} | sed 's_/_\\/_g')

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
    sed -i "s/SRC_FOLDER/${sed_src_dir}/"            ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/"     ${config_file}
    sed -i "s/OIFS_PROCS/${oifs_procs}/"             ${config_file}
    sed -i "s/OIFS_OMP_THREADS/${oifs_omp_threads}/" ${config_file}
    sed -i "s/OIFS_PPN/${oifs_procs}/"               ${config_file}
    sed -i "s/NEMO_PROCS/${nemo_procs}/"             ${config_file}
    sed -i "s/NEMO_PPN/${nemo_procs}/"               ${config_file}
    sed -i "s/XIOS_PROCS/${xios_procs}/"             ${config_file}
    sed -i "s/XIOS_PPN/${xios_procs}/"               ${config_file}
    sed -i "s/FREQUENCY/${freq}/"                    ${config_file}
    sed -i "s/START_DATE/${start_date}/"             ${config_file}
    sed -i "s/END_DATE/${end_date}/"                 ${config_file}
    sed -i "s/INTERVAL_VAL/${interval}/"             ${config_file}
    sed -i "s/OIFS_RESOLUTION/${oifs_resolution}/"   ${config_file}
    sed -i "s/NEMO_RESOLUTION/${nemo_resolution}/"   ${config_file}

    if [ "$current_member" = "WeakScaling" ]; then
        local queue=%HPCQUEUE%
        local proj=%CURRENT_PROJ%
        sed -i "s/QUEUE/${queue}/"                      ${config_file}
        sed -i "s/ACCOUNT/${proj}/"                     ${config_file}
    fi

    # Disable DR HOOK as it may cause issues
    sed -i "s/DR_HOOK=1/DR_HOOK=0/"              templates/launch/run-srun-multiprog.sh.j2

    # Activate the SE enviroment and run
    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}-prod.yml scriptlib/main.yml

    module purge
    source ${env_sources}
    # Temporary issue regarding xarray module in mn5
    if [ "${platform,,}" = "mn5" ]; then
        source /gpfs/home/bsc/bsc032333/.venv/bin/activate
    fi

    local coupling_enabled="%STRONGSCALING.COUPLING.ENABLED%"
    coupling_enabled=${coupling_enabled,,}
    if ${coupling_enabled}; then
        cd ${run_dir} || exit
        python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average 1 1 30

        run_id=${run_dir//*scalability_}
        coupling_dir=${test_dir}/coupling/${run_id}
        mkdir -p ${coupling_dir}
        cp ${run_dir}/lucia_lite_plots/*    ${coupling_dir}
        cp ${run_dir}/lucia_lite_results/*  ${coupling_dir}
    fi
}

###################
# Start script
###################

case "$current_member" in
    "CompilationEfficiency")
        member="compilation_efficiency"
        test_name=${member}/${test}
        arch_name=${test}
        model_resolution=%COMPILATION_EFFICIENCY.RESOLUTION%
        ;;
    "StrongScaling")
        member="strong_scaling"
        test_name=${member}/${test}
        arch_name=%STRONGSCALING.ARCH_NAME%
        model_resolution=%STRONGSCALING.RESOLUTION%
        ;;
    "WeakScaling")
        member="weakscaling"
        test_name=${member}/${test}
        arch_name=%WEAKSCALING.ARCH_NAME%
        model_resolution=${test}
        ;;
esac

run_${model}

