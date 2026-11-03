#!/bin/bash
#####################################################################################################################
# post.sh
# Brief: Gathers the raw outputs of a test member into the curated files the report consumes.
#        Generic wrapper: it resolves which runs belong to the member and hands each one to the model template
#        in autosubmit/templates/models/<MODEL>/post.sh, staged by Autosubmit, which provides post_<model>.
#####################################################################################################################

###################
# AS variables
###################
cfg=%COMMON_PATH_LOCATIONS.CFG%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
env_sources=${cfg}/env/${platform}/environment.env
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

jobname=%JOBNAME%
jobname=${jobname/%DEFAULT.EXPID%_}

components=($(bashify_array "%MODEL.COMPONENTS%" true))
report_components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

#####################################################################################################################
# Brief: Curates the hardware benchmark outputs; model independent, so it lives in this wrapper
# Global:
#   - Paths: cfg, run_root, project
#   - Other: model
#####################################################################################################################
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
        test_threads=($(bashify_array "%COMPILATION_EFFICIENCY.THREADS%"))
        test_config="%COMPILATION_EFFICIENCY.TEST_CONFIG%"
        splits="%COMPILATION_EFFICIENCY.SPLITS%"
        ;;
    "strongscaling")
        test_names=($(bashify_array "%STRONGSCALING.NAMES%"))
        test_tys=($(bashify_array "%STRONGSCALING.TEST_NAMES%"))
        test_procs=($(bashify_array "%STRONGSCALING.PROCESSORS%"))
        test_threads=($(bashify_array "%STRONGSCALING.THREADS%"))
        test_config="%STRONGSCALING.TEST_CONFIG%"
        splits="%STRONGSCALING.SPLITS%"
        ;;
    "weakscaling")
        test_names=($(bashify_array "%WEAKSCALING.NAMES%"))
        test_tys=($(bashify_array "%WEAKSCALING.TEST_NAMES%"))
        test_procs=($(bashify_array "%WEAKSCALING.PROCESSORS%"))
        test_threads=($(bashify_array "%WEAKSCALING.THREADS%"))
        test_config="%WEAKSCALING.TEST_CONFIG%"
        splits="%WEAKSCALING.SPLITS%"
        ;;
    "tracing")
        test_names=($(bashify_array "%TRACING.NAMES%"))
        test_tys=($(bashify_array "%TRACING.TEST_NAMES%"))
        test_procs=($(bashify_array "%TRACING.PROCESSORS%"))
        test_threads=($(bashify_array "%TRACING.THREADS%"))
        test_config="%TRACING.TEST_CONFIG%"
        splits=1
        ;;
esac

if [ "${current_member}" = "hw_benchmarks" ]; then
    post_hw_benchmarks
else
    # Source the model post template staged by Autosubmit
    model_post=%HPCLOGDIR%/post_${jobname}

    # AS stages each FILE entry as <stem>_<jobname>, so two entries with the same stem swap silently
    if ! grep -q "models/${model}/" "${model_post}"; then
        echo "[ERROR] ${model_post} is not the ${model} template (check the job FILE list)." >&2
        exit 1
    fi

    . "${model_post}"
    if ! declare -F "post_${model}" >/dev/null; then
        echo "[ERROR] post_${model} is not defined." >&2
        echo "        Add autosubmit/templates/models/${model}/post.sh to the job FILE list." >&2
        exit 1
    fi

    [[ "${splits}" =~ ^[0-9]+$ ]] || splits=1
    [ "${splits}" -gt 0 ] || splits=1

    i=0
    for test in "${test_names[@]}"; do
        set_run_paths "${test_tys[$i]}" "${test}"
        post_${model}
        i=$((i+1))
    done
fi
