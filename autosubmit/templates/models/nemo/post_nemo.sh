#!/bin/bash
#####################################################################################################################
# models/nemo/post_nemo.sh
# Brief: NEMO post-processing of one run, shared by the nemo model and by the hpcw model (which embeds NEMO).
#        Declared in the FILE list of the nemo and hpcw post jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as post_nemo_<jobname> (the model post template sources it).
# Contract, set by post.sh:
#   - Paths: cfg, test_dir, run_dir
#   - Other: model, test, current_member, splits, test_procs, i
# Declared by this file: project
#####################################################################################################################

###################
# AS variables
###################
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

#####################################################################################################################
# Brief: Writes the test_info files of one run
# Global:
#   - Paths: project, run_dir
#   - Other: model, test, current_member, splits, test_procs, i
#####################################################################################################################
function post_nemo()
{
    cd ${run_dir} || exit

    nemo_tasks=${test_procs[$i]}
    model_tasks=${nemo_tasks}
    nemo_threads=${test_threads[$i]:-1}
    model_threads=${nemo_threads}

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

    variables_to_report="tasks resolution threads"
    [ ${current_member} = "weakscaling" ] && variables_to_report+=" grid_points"

    # The split summary used to be written here; a leftover would mask the parsed values
    rm -f ${run_dir}/${test}-test_info.yaml

    report_test_cfg ${variables_to_report} > ${run_dir}/${test}-test_info.csv
}
