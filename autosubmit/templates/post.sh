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
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
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

    cd ${run_root}/hw_benchmarks || exit

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
        "weakscaling")
            nemo_ws_resolutions=($(bashify_array "%WEAKSCALING.RESOLUTION%"))
            nemo_resolution=${nemo_ws_resolutions[$i]}
            model_resolution=${nemo_resolution}
            . ${project}/configurations/model/nemo/resolutions.sh 
            nemo_grid_points=${nemo_resolutions[${nemo_resolution^^}]}
            model_grid_points=${nemo_grid_points}
        ;;
        *)
            model_resolution=%EXPERIMENT.RESOLUTION%
            [[ "${model_resolution}" =~ ^% || -z "${model_resolution}" ]] && model_resolution=${test_config}
            nemo_resolution=${model_resolution}
        ;;
    esac

    local split split_dir split_sypd
    local -a model_split_sypd=()
    rm -f ${run_dir}/nemo-${test}-timing.output
    for split in $(seq 1 ${splits}); do
        split_dir=${run_dir}/${split}
        if [ ! -f ${split_dir}/timing.output ]; then
            echo "[WARN] ${split_dir}/timing.output not found, skipping split ${split}" >&2
            model_split_sypd+=(0)
            continue
        fi
        cat ${split_dir}/timing.output >> ${run_dir}/nemo-${test}-timing.output
        split_sypd=$(grep -oE "SYPD: +[0-9.E+-]+" ${split_dir}/timing.output | grep -oE "[0-9.E+-]+" | awk '{sum += $1; count++} END {if (count) printf "%.4f", sum / count}')
        model_split_sypd+=(${split_sypd:-0})
    done
    model_sypd=$(printf '%s\n' "${model_split_sypd[@]}" | awk '{sum += $1} END {printf "%.4f", sum / NR}')
    nemo_sypd=${model_sypd}
    declare -a nemo_split_sypd=("${model_split_sypd[@]}")

    case ${current_member} in
        "tracing")
            cp ${run_dir}/1/${model}.prv ${run_dir}/nemo.prv
            cp ${run_dir}/1/${model}.pcf ${run_dir}/nemo.pcf
            cp ${run_dir}/1/${model}.row ${run_dir}/nemo.row
        ;;
    esac

    variables_to_report="nproc resolution"
    [ ${current_member} = "weakscaling" ] && variables_to_report+=" grid_points"

    report_test_cfg ${variables_to_report} > ${run_dir}/${test}-test_info.csv
    if [ "${splits}" -gt 1 ]; then
        save_test_yaml "${variables_to_report} sypd" "${variables_to_report} sypd" "sypd" > ${run_dir}/${test}-test_info.yaml
    fi
}

function post_ecearth4()
{
    oifs_on=false
    echo "${components[@]}" | grep -w "oifs" && oifs_on=true
    nemo_on=false
    echo "${components[@]}" | grep -w "nemo" && nemo_on=true

    cd ${run_dir} || exit

    if [ ${current_member} = "tracing" ]; then
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
        "tracing")
            mv run/*prv run/*pcf run/*row .

            cut_trace job_geometry.sh "${model}.prv"

            rm -rf set-* ./*.nc
        ;;
        *)
            local coupling_enabled="%STRONGSCALING.COUPLING_REPORT.ENABLED%"
            coupling_enabled=${coupling_enabled,,}
            if ${coupling_enabled}; then
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
        "weakscaling")
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
    [ ${current_member} = "weakscaling" ] && variables_to_report+=" grid_points"
    [ ${current_member} != "tracing" ] && ! ${coupling_enabled} && variables_to_report+=" sypd"
    
    report_test_cfg ${variables_to_report} > ${run_dir}/${test}-test_info.csv

    return 0
}

function post_hpcw_icon()
{
    local icon_nproc=${test_procs[$i]}
    local split split_dir split_time total_time=0
    local -a model_split_time=()

    for split in $(seq 1 ${splits}); do
        split_dir=${run_dir}/${split}
        if [ ! -f ${split_dir}/timing.output ]; then
            echo "[WARN] ${split_dir}/timing.output not found, skipping split ${split}" >&2
            model_split_time+=(0)
            continue
        fi
        split_time=$(sed -n 's/.*[[:space:]]\([0-9][0-9.]*\)elapsed.*/\1/p' ${split_dir}/timing.output 2>/dev/null | head -1)
        split_time=${split_time:-0}
        model_split_time+=(${split_time})
        total_time=$(awk -v total="${total_time}" -v t="${split_time}" 'BEGIN { printf "%.4f", total + t }')
    done

    if [ "${total_time}" = "0" ] || [ "${total_time}" = "0.0000" ]; then
        echo "[WARN] No timing data found for ${test} in ${run_dir}, skipping" >&2
        return 0
    fi

    model_nproc=${icon_nproc}
    model_time=$(awk -v total="${total_time}" -v n="${splits}" 'BEGIN { printf "%.4f", total / n }')
    icon_time=${model_time}
    # Read by save_test_yaml through indirect expansion (<component>_split_<var>[i])
    declare -a icon_split_time=("${model_split_time[@]}")

    printf '%s\n' "@hpcw-time: icon: 0.00user 0.00system ${model_time}elapsed 0%CPU (0text+0data 0max)k" > ${run_dir}/icon-${test}-timing.output

    report_test_cfg "nproc" > ${run_dir}/${test}-test_info.csv
    save_test_yaml "nproc time" "nproc time" "time" > ${run_dir}/${test}-test_info.yaml

    case ${current_member} in
        "tracing")
            cp ${run_dir}/1/${model}.prv ${run_dir}/icon.prv
            cp ${run_dir}/1/${model}.pcf ${run_dir}/icon.pcf
            cp ${run_dir}/1/${model}.row ${run_dir}/icon.row
        ;;
    esac
}

function post_hpcw_nemo()
{
    post_nemo
}

function post_hpcw()
{
    local component
    # shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
    component=$(bashify_array "%MODEL.COMPONENTS%" true)
    component=$(echo "${component%% *}" | tr '[:upper:]' '[:lower:]')

    post_hpcw_${component}
}

function post_monarch()
{
    if [ ${current_member} = "tracing" ]; then
        cp ${run_dir}/1/${model}.prv ${run_dir}/
        cp ${run_dir}/1/${model}.pcf ${run_dir}/
        cp ${run_dir}/1/${model}.row ${run_dir}/
        splits=1
    fi
    
    declare -a model_split_sdpd
    model_sdpd=0
    for split in $(seq 1 ${splits}); do
        split_run_dir=${run_dir}/${split}
        time_str=$(grep "real" ${split_run_dir}/model_output.log | awk '{print $2}')
        hours=$(echo "${time_str}" | grep -oE '[0-9]+h' | grep -oE '[0-9]+' 2>/dev/null || echo 0)
        minutes=$(echo "${time_str}" | grep -oE '[0-9]+m' | grep -oE '[0-9]+' 2>/dev/null || echo 0)
        seconds=$(echo "${time_str}" | grep -oE '[0-9]+(\.[0-9]+)?s' | grep -oE '[0-9]+(\.[0-9]+)?' 2>/dev/null || echo 0)
        execution_time=$(echo "scale=6; (${hours} * 3600) + (${minutes} * 60) + ${seconds}" | bc -l)
        simulated_hours=%MONARCH.NHOURS%
        split_sdpd=$(echo "scale=4; (3600 * ${simulated_hours}) / ${execution_time}" | bc -l)
        model_sdpd=$(echo "scale=4; ${model_sdpd} + ${split_sdpd}" | bc -l)
        model_split_sdpd+=(${split_sdpd})
    done
    declare -a monarch_split_sdpd=("${model_split_sdpd[@]}")
    model_sdpd=$(echo "scale=4; ${model_sdpd} / ${splits}" | bc -l)
    model_nproc=${test_procs[$i]}
    monarch_jnpes=${jnpes_list[$i]}
    monarch_inpes=${inpes_list[$i]}
    monarch_write_groups=${write_groups_list[$i]}
    monarch_write_tasks=${write_tasks_list[$i]}
    monarch_nproc=${model_nproc}
    monarch_sdpd=${model_sdpd}
    save_test_yaml "nproc sdpd" "nproc sdpd jnpes inpes write_groups write_tasks" "sdpd" > ${run_dir}/${test}-test_info.yaml
}

# Run postprocessing
module purge
. ${env_sources}

current_member=$(echo "%TASKTYPE%" | grep -oE "COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS")
current_member=${current_member,,}

splits=1
case "$current_member" in
    "compilation_efficiency")
        test_names=($(bashify_array "%COMPILATION_EFFICIENCY.NAMES%"))
        test_tys=($(bashify_array "%COMPILATION_EFFICIENCY.TEST_NAMES%"))
        test_procs=($(bashify_array "%COMPILATION_EFFICIENCY.PROCESSORS%"))
        test_config="%COMPILATION_EFFICIENCY.TEST_CONFIG%"
        if [ ${model} = "monarch" ]; then
            inpes_list=($(bashify_array "%COMPILATION_EFFICIENCY.INPES%"))
            jnpes_list=($(bashify_array "%COMPILATION_EFFICIENCY.JNPES%"))
            write_groups_list=($(bashify_array "%COMPILATION_EFFICIENCY.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%COMPILATION_EFFICIENCY.WRITE_TASKS%"))
        fi
        splits="%COMPILATION_EFFICIENCY.SPLITS%"
        ;;
    "strongscaling")
        test_names=($(bashify_array "%STRONGSCALING.NAMES%"))
        test_tys=($(bashify_array "%STRONGSCALING.TEST_NAMES%"))
        test_procs=($(bashify_array "%STRONGSCALING.PROCESSORS%"))
        test_config="%STRONGSCALING.TEST_CONFIG%"
        splits="%STRONGSCALING.SPLITS%"
        if [ ${model} = "monarch" ]; then
            inpes_list=($(bashify_array "%STRONGSCALING.INPES%"))
            jnpes_list=($(bashify_array "%STRONGSCALING.JNPES%"))
            write_groups_list=($(bashify_array "%STRONGSCALING.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%STRONGSCALING.WRITE_TASKS%"))
        fi
        ;;
    "weakscaling")
        test_names=($(bashify_array "%WEAKSCALING.NAMES%"))
        test_tys=($(bashify_array "%WEAKSCALING.TEST_NAMES%"))
        test_procs=($(bashify_array "%WEAKSCALING.PROCESSORS%"))
        test_config="%WEAKSCALING.TEST_CONFIG%"
        splits="%WEAKSCALING.SPLITS%"
        if [ ${model} = "monarch" ]; then
            inpes_list=($(bashify_array "%WEAKSCALING.INPES%"))
            jnpes_list=($(bashify_array "%WEAKSCALING.JNPES%"))
            write_groups_list=($(bashify_array "%WEAKSCALING.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%WEAKSCALING.WRITE_TASKS%"))
        fi
        ;;
    "tracing")
        test_names=($(bashify_array "%TRACING.NAMES%"))
        test_tys=($(bashify_array "%TRACING.TEST_NAMES%"))
        test_procs=($(bashify_array "%TRACING.PROCESSORS%"))
        test_config="%TRACING.TEST_CONFIG%"
        splits=1
        if [ ${model} = "monarch" ]; then
            inpes_list=($(bashify_array "%TRACING.INPES%"))
            jnpes_list=($(bashify_array "%TRACING.JNPES%"))
            write_groups_list=($(bashify_array "%TRACING.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%TRACING.WRITE_TASKS%"))
        fi
        ;;
    "HW_BENCHMARKS")
        post_hw_benchmarks
        ;;
esac

[[ "${splits}" =~ ^[0-9]+$ ]] || splits=1
[ "${splits}" -gt 0 ] || splits=1

i=0
for test in "${test_names[@]}"; do
    run_dir=${run_root}/${current_member}/${test_tys[$i]}/run_${test}
    test_dir=${run_root}/${current_member}/${test_tys[$i]}/
    post_${model}
    i=$((i+1))
done