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
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
model=%MODEL.NAME%
branch=%MODEL.BRANCH%
test="%CURRENT_TEST_NAME%"

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

report_components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

jobname=%JOBNAME%
jobname=${jobname/%DEFAULT.EXPID%_}

# Source the model run template staged by Autosubmit
if [ ! -f %HPCLOGDIR%/run_${jobname} ]; then
    echo "[ERROR] Model run template %HPCLOGDIR%/run_${jobname} not found." >&2
    echo "        Add autosubmit/templates/models/%DEFAULT.MODEL%/run.sh to the job FILE list." >&2
    exit 1
fi
. %HPCLOGDIR%/run_${jobname}
if ! declare -F "run_${model}" >/dev/null; then
    echo "[ERROR] run_${model} is not defined after sourcing the run template." >&2
    echo "        Check the FILE list of this job: autosubmit/templates/models/%DEFAULT.MODEL%/run.sh" >&2
    exit 1
fi

# Source the model utils template staged by Autosubmit
if [ -f %HPCLOGDIR%/utils_${jobname} ]; then
    . %HPCLOGDIR%/utils_${jobname}
fi

###################
# Start script
###################

current_member=$(echo "%TASKTYPE%" | grep -oE "COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS")
current_member=${current_member,,}

case "$current_member" in
    "compilation_efficiency")
        test_name=${current_member}/${test}
        arch_name=%CURRENT_ARCH_NAME%
        [[ "${arch_name}" =~ ^% || -z "${arch_name}" ]] && arch_name=${test}
        test_config=%COMPILATION_EFFICIENCY.TEST_CONFIG%
        test_steps=%COMPILATION_EFFICIENCY.TEST_STEPS%
        output=%COMPILATION_EFFICIENCY.OUTPUT%
        ;;
    "strongscaling")
        test_name=${current_member}/${test}
        arch_name=%STRONGSCALING.ARCH_NAME%
        test_config=%STRONGSCALING.TEST_CONFIG%
        test_steps=%STRONGSCALING.TEST_STEPS%
        output=%STRONGSCALING.OUTPUT%
        ;;
    "weakscaling")
        test_name=${current_member}/${test}
        arch_name=%WEAKSCALING.ARCH_NAME%
        test_config=%WEAKSCALING.TEST_CONFIG%
        test_steps=%WEAKSCALING.TEST_STEPS%
        output=%WEAKSCALING.OUTPUT%
        ;;
    "tracing")
        test_name=${current_member}/${test}
        arch_name=%TRACING.ARCH_NAME%
        test_config=%TRACING.TEST_CONFIG%
        test_steps=%TRACING.TRACE_STEPS%
        output=%TRACING.OUTPUT%
        ;;
    *)
        echo "[ERROR] Unknown current member: ${current_member}" >&2
        exit 1
        ;;
esac

run_${model}

