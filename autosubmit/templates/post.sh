#!/bin/bash

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

components=($(bashify_array "%MODEL.COMPONENTS%" true))
report_components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))


function post_hw_benchmarks()
{
    osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
    osu_enabled=${osu_enabled,,}
    stream_enabled=%HW_BENCHMARKS.STREAM.ENABLED%
    stream_enabled=${stream_enabled,,}

    set +u
    export PYTHONPATH=$PYTHONPATH:${project}
    set -u

    cd ${run_root}/hardware_benchmarks || exit

    if ${osu_enabled}; then
        osu_tests=($(bashify_array "%HW_BENCHMARKS.OSU.TESTS%" true))
        mkdir -p OSU_RUN/IMAGE

        for test in "${osu_tests[@]}"
        do
            test_name=${test##*/}
            input_files=(OSU_RUN/DATA/${test_name}*)
            python3 ${cfg}/benchmarks/OSU/osu_test_plots.py -i "${input_files[@]}" -o OSU_RUN/IMAGE/
        done
    fi
    
    if ${stream_enabled}; then
        python3 ${cfg}/benchmarks/STREAM/stream_data_parser.py -i STREAM_RUN --png --png-output-name STREAM_RUN/${model}.png
    fi
}

function post_nemo()
{
    cd ${run_dir} || exit

    nemo_nproc=${test_procs[$i]}
    model_nproc=${nemo_nproc}

    case ${current_member} in
        "WeakScaling")
            nemo_ws_resolutions=($(bashify_array "%WEAKSCALING.RESOLUTION%"))
            nemo_resolution=${nemo_ws_resolutions[$i]}
            model_resolution=${nemo_resolution}
            . ${project}/configurations/model/nemo/resolutions.sh 
            nemo_grid_points=${nemo_resolutions[${nemo_resolution^^}]}
            model_grid_points=${nemo_grid_points}
        ;;
        *)
            model_resolution=%EXPERIMENT.RESOLUTION%
            nemo_resolution=${model_resolution}
        ;;
    esac

    # Rename timing output
    cp ${run_dir}/timing.output ${run_dir}/nemo-${test}-timing.output

    variables_to_report="nproc resolution"
    [ ${current_member} = "WeakScaling" ] && variables_to_report+=" grid_points"

    report_test_cfg ${variables_to_report} > ${run_dir}/${test}-test_info.csv
}

function post_ecearth4()
{
    oifs_on=false
    echo "${components[@]}" | grep -w "oifs" && oifs_on=true
    nemo_on=false
    echo "${components[@]}" | grep -w "nemo" && nemo_on=true

    cd ${run_dir} || exit

    if [ ${current_member} = "Tracing" ]; then
        multiprog_fn=${run_dir}/run/multiprog.conf
    else
        multiprog_fn=${run_dir}/multiprog.conf
    fi

    save_job_geometry multiprog ${multiprog_fn} > job_geometry.sh
    . ./job_geometry.sh

    for component in ${!job_geometry[@]}; do
        component_geometry=${job_geometry[${component}]}
        component_geometry=${component_geometry//,/ }
        component_nproc=${component}_nproc
        declare ${component_nproc}=0
        for procs_range in ${component_geometry}; do
            first_proc=$(echo ${procs_range} | cut -d'-' -f1)
            last_proc=$(echo ${procs_range} | cut -d'-' -f2)
            curr_sypd=${!component_nproc}
            declare ${component_nproc}=$((curr_sypd + (last_proc - first_proc + 1)))
        done
    done

    model_nproc=$((last_proc + 1))

    case ${current_member} in
        "Tracing")
            # Moce and cut the trace by the model's components

            mv run/*prv run/*pcf run/*row .

            cut_trace job_geometry.sh "${model}.prv"

            rm -rf set-* ./*.nc
        ;;
        *)
            local coupling_enabled="%STRONGSCALING.COUPLING_REPORT.ENABLED%"
            coupling_enabled=${coupling_enabled,,}
            # If enabled, run lucia to get the coupling report
            if ${coupling_enabled}; then
                # Get test timesteps
                if ${nemo_on}; then
                    lucia_ts=$(cat time.step)
                else 
                    # If nemo is not present, it means that oifs is running coupled with amipfr
                    sim_length=$(cat namelist.amip | grep -oE "RunLengthSec = [0-9]+" | awk -F ' ' '{print $3}')
                    amip_coupling_period=$(cat namelist.amip | grep -oE "TimeStepSec = [0-9]+" | awk -F ' ' '{print $3}')
                    lucia_ts=$((sim_length/amip_coupling_period))
                fi

                local ignore_ini_ts="%STRONGSCALING.COUPLING_REPORT.LUCIA.IGNORE_INI_TS%"
                local ignore_end_ts="%STRONGSCALING.COUPLING_REPORT.LUCIA.IGNORE_END_TS%"
                local ignored_ts=$((ignore_ini_ts+ignore_end_ts))
                while ! python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average ${ignore_ini_ts} ${ignore_end_ts} ${lucia_ts} --generate_plots true > lucia.log && [ ${lucia_ts} -gt ${ignored_ts} ]; do
                    lucia_ts=$((lucia_ts-1))
                done

                if [ ${lucia_ts} -le ${ignored_ts} ]; then
                    echo "[ERROR] Could not generate coupling report using lucia, check the logs or disable the coupling report in the AS settings." >&2 
                    return 1
                else
                    coupling_dir=${test_dir}/coupling/${test}
                    mkdir -p ${coupling_dir}
                    cp ${run_dir}/lucia_lite_plots/*    ${coupling_dir}
                    cp ${run_dir}/lucia_lite_results/*  ${coupling_dir}
                fi
            else
                # Get sypd from the logs since lucia is not enabled
                if ${oifs_on}; then
                    oifs_sypd=$(grep "FORECAST DAYS PER DAY" log/001/NODE.001_01 |  grep -oE "[0-9.]+" )
                    oifs_sypd=$(echo ${oifs_sypd} / 365 | bc -l)
                fi
                                
                ${nemo_on} && nemo_sypd=$(grep "Model speed excl overhead:" log/001/timing.log |  grep -oE "[0-9.]+" )

                model_sypd=$(grep "Model speed excl overhead:" log/001/timing.log |  grep -oE "[0-9.]+" )
            fi

            ${oifs_on} && cp ${run_dir}/log/001/ifs.stat ${run_dir}/oifs-${test}-ifs.stat
            ${nemo_on} && cp ${run_dir}/timing.output ${run_dir}/nemo-${test}-timing.output
        ;;
    esac


    case ${current_member} in
        "WeakScaling")
            # Get the grid points from the nemo timing output
            if ${oifs_on}; then
                oifs_ws_resolutions=($(bashify_array "%WEAKSCALING.OIFS_RESOLUTION%"))
                oifs_resolution=${oifs_ws_resolutions[$i]}
                . ${project}/configurations/model/oifs/resolutions.sh 
                oifs_grid_points=${oifs_resolutions[${oifs_resolution}]}
            fi

            if ${nemo_on}; then
                nemo_ws_resolutions=($(bashify_array "%WEAKSCALING.NEMO_RESOLUTION%"))
                nemo_resolution=${nemo_ws_resolutions[$i]}
                . ${project}/configurations/model/nemo/resolutions.sh 
                nemo_grid_points=${nemo_resolutions[${nemo_resolution}]}
            fi
        ;;
        *)
            model_resolution=%EXPERIMENT.RESOLUTION%
            ${oifs_on} && oifs_resolution=%EXPERIMENT.OIFS_RESOLUTION%
            ${nemo_on} && nemo_resolution=%EXPERIMENT.NEMO_RESOLUTION%
        ;;
    esac

    variables_to_report="nproc resolution"
    [ ${current_member} = "WeakScaling" ] && variables_to_report+=" grid_points"
    [ ${current_member} != "Tracing" ] && ! ${coupling_enabled} && variables_to_report+=" sypd"
    
    report_test_cfg ${variables_to_report} > ${run_dir}/${test}-test_info.csv

    return 0
}

function post_hpcw()
{
    post_nemo

    case ${current_member} in
        "Tracing")
            # Remove unneeded files
            cp ${run_dir}/${model}.prv ${run_dir}/nemo.prv
            cp ${run_dir}/${model}.pcf ${run_dir}/nemo.pcf
            cp ${run_dir}/${model}.row ${run_dir}/nemo.row
        ;;
    esac
}

# Run postprocessing
module purge
. ${env_sources}

case "$current_member" in
    "CompilationEfficiency")
        member="compilation_efficiency"
        test_names=($(bashify_array "%COMPILATION_EFFICIENCY.NAMES%"))
        test_tys=($(bashify_array "%COMPILATION_EFFICIENCY.TEST_NAMES%"))
        test_procs=($(bashify_array "%COMPILATION_EFFICIENCY.PROCESSORS%"))
        ;;
    "StrongScaling")
        member="strong_scaling"
        test_names=($(bashify_array "%STRONGSCALING.NAMES%"))
        test_tys=($(bashify_array "%STRONGSCALING.TEST_NAMES%"))
        test_procs=($(bashify_array "%STRONGSCALING.PROCESSORS%"))
        ;;
    "WeakScaling")
        member="weakscaling"
        test_names=($(bashify_array "%WEAKSCALING.NAMES%"))
        test_tys=($(bashify_array "%WEAKSCALING.TEST_NAMES%"))
        test_procs=($(bashify_array "%WEAKSCALING.PROCESSORS%"))
        ;;
    "Tracing")
        member="tracing"
        test_names=($(bashify_array "%TRACING.NAMES%"))
        test_tys=($(bashify_array "%TRACING.TEST_NAMES%"))
        test_procs=($(bashify_array "%TRACING.PROCESSORS%"))
        ;;
    "HardwareBenchmarks")
        post_hw_benchmarks
        ;;
esac

i=0
for test in "${test_names[@]}"; do
    run_dir=${run_root}/${member}/${test_tys[$i]}/run_${test}
    test_dir=${run_root}/${member}/${test_tys[$i]}/
    post_${model}
    i=$((i+1))
done