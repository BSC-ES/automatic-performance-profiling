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
branch=%MODEL.BRANCH%
test="%CURRENT_TEST_NAME%"
platform="%DEFAULT.HPCARCH%"

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

report_components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

#####################################################################################################################
# Biref: Updates the namelists with the AS member configuration and runs NEMO
# Global:
#   - Paths: inidata, binaries, compilation, run_dir
#   - Other: test_name, nemo_procs
#####################################################################################################################
function run_nemo()
{
    if [ ${current_member} = "WeakScaling" ]; then
        local nemo_resolution="%CURRENT_RESOLUTION%"
    else
        local nemo_resolution="%EXPERIMENT.RESOLUTION%"
    fi
    local nemo_procs=%NUMPROC%
    local output="%EXPERIMENT.OUTPUT%"
    local test_steps="%EXPERIMENT.TEST_STEPS%" 

    run_id=nemo_${nemo_procs}
    run_dir=${run_root}/${test_name}/scalability_${run_id}
    mkdir -p ${run_dir}

    source ${env_sources}

    model_sources=${model}_${branch}
    configuration_folder=tests
    
    # Link inidata
    cp ${inidata}/$test_name/* ${run_dir}
    ln -rsf ${inidata}/original ${run_dir}
    rsync -rv --exclude=.nc ${inidata} ${run_dir}

    # Copy everything from reference run_root
    cp --remove-destination ${compilation}/${model_sources}/${configuration_folder}/${arch_name}/EXP00/* ${run_dir}
    cp ${run_dir}/namelist_cfg_${nemo_resolution}_like ${run_dir}/namelist_cfg

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

    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
    if [ ${current_member} = "WeakScaling" ]; then
        . ${project}/configurations/model/${model}/resolutions.sh 
        local base_procs="%WEAKSCALING.BASE_PROCS%"
        local base_resolution="%WEAKSCALING.BASE_RESOLUTION%"
        local base_tile_size=${nemo_resolutions[${base_resolution^^}]}
        local nemo_curr_tile_size=${nemo_resolutions[${nemo_resolution^^}]}
        nemo_procs=$((base_procs*nemo_curr_tile_size/base_tile_size))
        local queue="%HPCQUEUE%"
        local proj="%CURRENT_PROJ%"
        time srun -A ${proj} -q ${queue} -n $nemo_procs ./nemo
    else
        time srun -n $nemo_procs ./nemo
    fi

    # Rename timing output
    cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output

    # Create test info csv for the JSON
    report_test_cfg
}

#####################################################################################################################
# Brief: Get all components AS variables to abstract run_ecearth4 function
# Global:
#   - Paths: project
#####################################################################################################################
function get_vars_ecearth4()
{
    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
    if [ ${current_member} = "WeakScaling" ]; then
        . ${project}/configurations/model/nemo/resolutions.sh 
        # Overwrite resolution var with the current test resolution
        nemo_resolution=%CURRENT_NEMO_RESOLUTION%
        nemo_base_procs=%WEAKSCALING.NEMO_BASE_PROCS%
        nemo_base_resolution=%WEAKSCALING.NEMO_BASE_RESOLUTION%
        base_tile_size=${nemo_resolutions[${nemo_base_resolution^^}]}
        nemo_curr_tile_size=${nemo_resolutions[${nemo_resolution^^}]}
        nemo_procs=$((nemo_base_procs*nemo_curr_tile_size/base_tile_size))

        . ${project}/configurations/model/oifs/resolutions.sh 
        # Overwrite resolution var with the current test resolution
        oifs_resolution=%CURRENT_OIFS_RESOLUTION%
        oifs_base_procs=%WEAKSCALING.OIFS_BASE_PROCS%
        oifs_base_resolution=%WEAKSCALING.OIFS_BASE_RESOLUTION%
        base_tile_size=${oifs_resolutions[${oifs_base_resolution^^}]}
        oifs_curr_tile_size=${oifs_resolutions[${oifs_resolution^^}]}
        oifs_procs=$((oifs_base_procs*oifs_curr_tile_size/base_tile_size))
    else 
        oifs_procs="%CURRENT_OIFS_PROCS%"
        oifs_resolution="%EXPERIMENT.OIFS_RESOLUTION%"

        nemo_procs="%CURRENT_NEMO_PROCS%"
        nemo_resolution="%EXPERIMENT.NEMO_RESOLUTION%"
    fi
    use_omp_threads="%USE_OMP_THREADS%"
    oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi
    
    xios_procs="%CURRENT_XIOS_PROCS%"

    rnfm_procs=1
}


#####################################################################################################################
# Brief: Updates the SE config file with the AS config and runs EC-Earth 4
# Global:
#   - Paths: run_root, compilation, project
#   - Other: test_name, model, number_of_cores, test, branch
#####################################################################################################################
function run_ecearth4()
{
    # Get AS variables

    get_vars_ecearth4

    local start_date="%EXPERIMENT.START_DATE%"
    local end_date="%EXPERIMENT.END_DATE%"
    local freq="%EXPERIMENT.FREQ%"
    local interval="%EXPERIMENT.INTERVAL%"

    . ${project}/cfg/utils/${model}/se.sh

    local model_sources=${compilation}/${model}_${branch}
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local run_dir=${test_dir}/scalability_${run_id}
    local src_dir=${compilation}/${arch_name}/sources/

    # Remove all run folder content just in case
    mkdir -p ${run_dir}
    rm -rf ${run_dir}/*

    cd ${compilation}/${arch_name}/scripts/runtime || exit


    # Update all configuration according to AS variables
    
    local config_file=config-${test}-${run_id}.yml
    cp ${project}/configurations/model/${model}/experiment_config.yml.tmpl ${config_file}

    local sed_run_dir=${run_dir//\//\\\/}
    local sed_src_dir=${src_dir//\//\\\/}
    local ecearth_root=${compilation}/${arch_name}
    local sed_ecearth_root=${ecearth_root//\//\\\/}

    sed -i "s/RUN_FOLDER/${sed_run_dir}/"            ${config_file}
    sed -i "s/BASE_FOLDER/${sed_run_dir}/"           ${config_file}
    sed -i "s/SRC_FOLDER/${sed_src_dir}/"            ${config_file}
    sed -i "s/ECEARTH_ROOT/${sed_ecearth_root}/"     ${config_file}
    sed -i "s/OIFS_OMP_THREADS/${oifs_omp_threads}/" ${config_file}
    for component in "${report_components[@]}"; do
        component_procs=${component}_procs
        sed -i "s/${component^^}_PPN/${!component_procs}/"   ${config_file}
        sed -i "s/${component^^}_PROCS/${!component_procs}/" ${config_file}
    done 
    sed -i "s/XIOS_PROCS/${xios_procs}/"             ${config_file}
    sed -i "s/XIOS_PPN/${xios_procs}/"               ${config_file}
    sed -i "s/FREQUENCY/${freq}/"                    ${config_file}
    sed -i "s/START_DATE/${start_date}/"             ${config_file}
    sed -i "s/END_DATE/${end_date}/"                 ${config_file}
    sed -i "s/INTERVAL_VAL/${interval}/"             ${config_file}
    sed -i "s/OIFS_RESOLUTION/${oifs_resolution}/"   ${config_file}
    sed -i "s/NEMO_RESOLUTION/${nemo_resolution}/"   ${config_file}

    # Set the queue and project only for weakscaling since it is run intercatively 
    # and it is not taking the AS platform configuration
    if [ "$current_member" = "WeakScaling" ]; then
        local queue="%HPCQUEUE%"
        local proj="%CURRENT_PROJ%"
        sed -i "s/QUEUE/${queue}/"                   ${config_file}
        sed -i "s/ACCOUNT/${proj}/"                  ${config_file}
    fi

    # Disable DR HOOK as it may cause issues
    sed -i "s/DR_HOOK=1/DR_HOOK=0/"              templates/launch/run-srun-multiprog.sh.j2


    # Activate the SE enviroment and run

    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}.yml scriptlib/main.yml


    # Post process model output

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
        lucia_ts=$(cat time.step)
        lucia_ts=$((lucia_ts-1))

        while ! python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average 1 1 ${lucia_ts} && [ $lucia_ts -gt 0 ]; do
            lucia_ts=$((lucia_ts-1))
        done

        run_id=${run_dir//*scalability_}
        coupling_dir=${test_dir}/coupling/${run_id}
        mkdir -p ${coupling_dir}
        cp ${run_dir}/lucia_lite_plots/*    ${coupling_dir}
        cp ${run_dir}/lucia_lite_results/*  ${coupling_dir}
    fi

    cp ${run_dir}/log/001/ifs.stat ${run_dir}/oifs-${run_id}-ifs.stat
    cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output

    # Create test info csv for the JSON
    report_test_cfg
}

###################
# Start script
###################

case "$current_member" in
    "CompilationEfficiency")
        member="compilation_efficiency"
        test_name=${member}/${test}
        arch_name=${test}
        ;;
    "StrongScaling")
        member="strong_scaling"
        test_name=${member}/${test}
        arch_name=%STRONGSCALING.ARCH_NAME%
        ;;
    "WeakScaling")
        member="weakscaling"
        test_name=${member}/${test}
        arch_name=%WEAKSCALING.ARCH_NAME%
        ;;
esac

run_${model}

