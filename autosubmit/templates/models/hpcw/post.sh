#!/bin/bash
#####################################################################################################################
# models/hpcw/post.sh
# Brief: HPCW post-processing for the scalability tests (ICON and NEMO components).
#        Declared in the FILE list of the hpcw post jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as post_<jobname>. post.sh sources it and calls post_hpcw.
# Contract, set by post.sh:
#   - Paths: cfg, test_dir, run_dir
#   - Other: model, test, current_member, splits, test_procs, i
# Note: the NEMO component reuses models/nemo/post_nemo.sh, also declared in the hpcw post jobs FILE list
#####################################################################################################################

# shellcheck source=/dev/null
. %HPCLOGDIR%/post_nemo_${jobname}

#####################################################################################################################
# Brief: Writes the test_info files and the trace of one run
# Global:
#   - Paths: run_dir
#   - Other: model, test, current_member, splits, test_procs, i
#####################################################################################################################
function post_hpcw_icon()
{
    model_nproc=${test_procs[$i]}
    icon_nproc=${test_procs[$i]}

    report_test_cfg "nproc" > ${run_dir}/${test}-test_info.csv
    save_test_yaml "nproc" "nproc" "" > ${run_dir}/${test}-test_info.yaml

    case ${current_member} in
        "tracing")
            cp ${run_dir}/1/${model}.prv ${run_dir}/icon.prv
            cp ${run_dir}/1/${model}.pcf ${run_dir}/icon.pcf
            cp ${run_dir}/1/${model}.row ${run_dir}/icon.row
        ;;
    esac
}

#####################################################################################################################
# Brief: Runs the NEMO post-processing of one run (models/nemo/post_nemo.sh)
#####################################################################################################################
function post_hpcw_nemo()
{
    post_nemo
}

#####################################################################################################################
# Brief: Dispatches to the extraction of the component this job runs
# Global:
#   - Other: model
#####################################################################################################################
function post_hpcw()
{
    local component=${components[0],,}

    post_hpcw_${component}
}
