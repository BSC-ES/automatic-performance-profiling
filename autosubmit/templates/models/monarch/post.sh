#!/bin/bash
#####################################################################################################################
# models/monarch/post.sh
# Brief: MONARCH post-processing for the scalability tests.
#        Declared in the FILE list of the monarch post jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as post_<jobname>. post.sh sources it and calls post_monarch.
# Contract, set by post.sh:
#   - Paths: cfg, test_dir, run_dir
#   - Other: model, test, current_member, splits, test_procs, i
#####################################################################################################################

###################
# AS variables
###################
nhours=%MONARCH.NHOURS%

#####################################################################################################################
# Brief: Reads the MONARCH decomposition arrays of the current member
# Global:
#   - Other: current_member
# Sets:
#   - inpes_list, jnpes_list, write_groups_list, write_tasks_list
#####################################################################################################################
function configure_monarch()
{
    case "$current_member" in
        "compilation_efficiency")
            inpes_list=($(bashify_array "%COMPILATION_EFFICIENCY.INPES%"))
            jnpes_list=($(bashify_array "%COMPILATION_EFFICIENCY.JNPES%"))
            write_groups_list=($(bashify_array "%COMPILATION_EFFICIENCY.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%COMPILATION_EFFICIENCY.WRITE_TASKS%"))
        ;;
        "strongscaling")
            inpes_list=($(bashify_array "%STRONGSCALING.INPES%"))
            jnpes_list=($(bashify_array "%STRONGSCALING.JNPES%"))
            write_groups_list=($(bashify_array "%STRONGSCALING.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%STRONGSCALING.WRITE_TASKS%"))
        ;;
        "weakscaling")
            inpes_list=($(bashify_array "%WEAKSCALING.INPES%"))
            jnpes_list=($(bashify_array "%WEAKSCALING.JNPES%"))
            write_groups_list=($(bashify_array "%WEAKSCALING.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%WEAKSCALING.WRITE_TASKS%"))
        ;;
        "tracing")
            inpes_list=($(bashify_array "%TRACING.INPES%"))
            jnpes_list=($(bashify_array "%TRACING.JNPES%"))
            write_groups_list=($(bashify_array "%TRACING.WRITE_GROUPS%"))
            write_tasks_list=($(bashify_array "%TRACING.WRITE_TASKS%"))
        ;;
    esac
}

#####################################################################################################################
# Brief: Computes the SDPD of one MONARCH run and writes its test_info file
# Global:
#   - Paths: run_dir
#   - Other: model, test, current_member, splits, test_procs, i, nhours
#   - Set by configure_monarch: inpes_list, jnpes_list, write_groups_list, write_tasks_list
#####################################################################################################################
function post_monarch()
{
    configure_monarch

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
        split_sdpd=$(echo "scale=4; (3600 * ${nhours}) / ${execution_time}" | bc -l)
        model_sdpd=$(echo "scale=4; ${model_sdpd} + ${split_sdpd}" | bc -l)
        model_split_sdpd+=(${split_sdpd})
    done
    declare -a monarch_split_sdpd=("${model_split_sdpd[@]}")
    model_sdpd=$(echo "scale=4; ${model_sdpd} / ${splits}" | bc -l)
    model_tasks=${test_procs[$i]}
    monarch_threads=${test_threads[$i]:-1}
    model_threads=${monarch_threads}
    monarch_jnpes=${jnpes_list[$i]}
    monarch_inpes=${inpes_list[$i]}
    monarch_write_groups=${write_groups_list[$i]}
    monarch_write_tasks=${write_tasks_list[$i]}
    monarch_tasks=${model_tasks}
    monarch_sdpd=${model_sdpd}
    save_test_yaml "tasks sdpd threads" "tasks sdpd jnpes inpes write_groups write_tasks threads" "sdpd" > ${run_dir}/${test}-test_info.yaml
}
