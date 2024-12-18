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
components="%MODEL.COMPONENTS%"
components=${components//[\[,\]]/}
components=$(for v in $components; do echo "$v";done| sort| uniq| xargs)

#####################################################################################################################
# Biref: Updates the namelists with the AS member configuration and runs NEMO
# Global:
#   - Paths: inidata, binaries, compilation, run_dir
#   - Other: test_name, number_of_cores
#####################################################################################################################
function run_nemo()
{
    local output="%EXPERIMENT.OUTPUT%"
    local test_steps="%EXPERIMENT.TEST_STEPS%" 

    run_id=nemo_${number_of_cores}
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
    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
    if [ ${current_member} = "WeakScaling" ]; then
        . ${project}/configurations/model/${model}/resolutions.sh 
        local base_procs=%WEAKSCALING.BASE_PROCS%
        local base_resolution=%WEAKSCALING.BASE_RESOLUTION%
        local base_tile_size=${nemo_resolutions[$base_resolution]}
        local curr_tile_size=${nemo_resolutions[$model_resolution]}
        number_of_cores=$((base_procs*curr_tile_size/base_tile_size))
        local queue=%HPCQUEUE%
        local proj=%CURRENT_PROJ%
        time srun -A ${proj} -q ${queue} -n $number_of_cores ./nemo
    else
        time srun -n $number_of_cores ./nemo
    fi

    # Rename timing output
    cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output
}


#####################################################################################################################
# Brief: Updates the SE config file with the AS config and runs EC-Earth 4
# Global:
#   - Paths: run_root, compilation
#   - Other: test_name, model, number_of_cores, test, branch
#####################################################################################################################
function run_ecearth4()
{
    local oifs_resolution="%EXPERIMENT.OIFS_RESOLUTION%"
    local nemo_resolution="%EXPERIMENT.NEMO_RESOLUTION%"
    local start_date="%EXPERIMENT.START_DATE%"
    local end_date="%EXPERIMENT.END_DATE%"
    local freq="%EXPERIMENT.FREQ%"
    local interval="%EXPERIMENT.INTERVAL%"

    . ${project}/cfg/utils/${model}/se.sh

    local model_sources=${compilation}/${model}_${branch}

    local xios_procs="%CURRENT_XIOS_PROCS%"
    local use_omp_threads="%USE_OMP_THREDS%"
    local oifs_omp_threads=1
    if [ "${use_omp_threads^^}" == "TRUE" ]; then
        oifs_omp_threads=%CURRENT_THREADS%
    fi

    # If it is Weak Scaling that is being run compute the current procs based on the
    # base procs and resolution
    if [ ${current_member} = "WeakScaling" ]; then
        . ${project}/configurations/model/nemo/resolutions.sh 
        local current_nemo_resolution=%CURRENT_NEMO_RESOLUTION%
        local nemo_base_procs=%WEAKSCALING.NEMO_BASE_PROCS%
        local nemo_base_resolution=%WEAKSCALING.NEMO_BASE_RESOLUTION%
        local base_tile_size=${nemo_resolutions[${nemo_base_resolution^^}]}
        local curr_tile_size=${nemo_resolutions[${current_nemo_resolution^^}]}
        local nemo_procs=$((nemo_base_procs*curr_tile_size/base_tile_size))

        . ${project}/configurations/model/oifs/resolutions.sh 
        local current_oifs_resolution=%CURRENT_OIFS_RESOLUTION%
        local oifs_base_procs=%WEAKSCALING.OIFS_BASE_PROCS%
        local oifs_base_resolution=%WEAKSCALING.OIFS_BASE_RESOLUTION%
        local base_tile_size=${oifs_resolutions[${oifs_base_resolution^^}]}
        local curr_tile_size=${oifs_resolutions[${current_oifs_resolution^^}]}
        local oifs_procs=$((oifs_base_procs*curr_tile_size/base_tile_size))
    else 
        local oifs_procs="%CURRENT_OIFS_PROCS%"
        local nemo_procs="%CURRENT_NEMO_PROCS%"
    fi

    local test_dir=${run_root}/${test_name}
    local run_id=xios_${xios_procs}_nemo_${nemo_procs}_rnfm_1_oifs_${oifs_procs}
    local run_dir=${test_dir}/scalability_${run_id}
    local src_dir=${compilation}/${arch_name}/sources/

    # Remove all run folder content just in case
    rm -rf ${run_dir}/*

    cd ${compilation}/${arch_name}/scripts/runtime

    # Update all variable according to AS config
    local config_file=config-${test}-${run_id}.yml
    cp ${project}/configurations/model/${model}/experiment_config.yml.tmpl ${config_file}

    local sed_run_dir=${run_dir//\//\\\/}
    local sed_src_dir=${src_dir//\//\\\/}
    local ecearth_root=${compilation}/${arch_name}
    local sed_ecearth_root=${ecearth_root//\//\\\/}

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
        sed -i "s/QUEUE/${queue}/"                   ${config_file}
        sed -i "s/ACCOUNT/${proj}/"                  ${config_file}
    fi

    # Disable DR HOOK as it may cause issues
    sed -i "s/DR_HOOK=1/DR_HOOK=0/"              templates/launch/run-srun-multiprog.sh.j2

    # Activate the SE enviroment and run
    set +u
    se_env_${platform,,} trunk
    se --nocolor --loglevel debug ${config_file} ../platforms/${arch_name}.yml scriptlib/main.yml

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

    cp ${run_dir}/log/001/ifs.stat ${run_dir}/oifs-${run_id}-ifs.stat
    cp ${run_dir}/timing.output ${run_dir}/nemo-${run_id}-timing.output

    echo "component,procs,resolution" > ${run_dir}/test_info.csv
    for component in $components; do
        component_procs="${component}_procs"
        component_resolution="${component}_resolution"
        echo "${component},${!component_procs},${!component_resolution}" >> ${run_dir}/test_info.csv
    done
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

model_resolution=%EXPERIMENT.RESOLUTION%

run_${model}

