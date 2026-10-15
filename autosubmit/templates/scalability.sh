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

# Source the model run template staged by Autosubmit. The job running this script declares the
# model template in its FILE list, so Autosubmit substitutes the model variables and copies it to
# the log directory as run_<jobname>. Each model implements run_<model>, dispatched at the end of
# this script. Fail fast with a clear message if the job forgot to declare it.
if [ ! -f %HPCLOGDIR%/run_${jobname} ]; then
    echo "[ERROR] Model run template %HPCLOGDIR%/run_${jobname} not found." >&2
    echo "        Add autosubmit/templates/models/%DEFAULT.MODEL%/run.sh to the job FILE list." >&2
    exit 1
fi
. %HPCLOGDIR%/run_${jobname}

# Source the tracing utils script copied by Autosubmit to the LOG_expid dir. It provides
# configure_extrae, create_trace_sh and generate_extrae_user_functions. Only the jobs whose FILE
# list includes cfg/trace/utils.sh (the tracing ones) stage it, so it is sourced only when present
# and the non-tracing tests do not depend on it.
if [ -f %HPCLOGDIR%/utils_${jobname} ]; then
    . %HPCLOGDIR%/utils_${jobname}
fi

###################
# Start script
###################

current_member=$(echo "%TASKTYPE%" | grep -oE "COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS")
current_member=${current_member,,}

# The test configuration is a per-test setting (e.g. the model test case or the ICON input
# package), so each test picks its own <TEST>.TEST_CONFIG. EXPERIMENT.TEST_CONFIG remains the
# fallback for tests that do not define one.
case "$current_member" in
    "compilation_efficiency")
        test_name=${current_member}/${test}
        arch_name=${test}
        test_config=%COMPILATION_EFFICIENCY.TEST_CONFIG%
        ;;
    "strongscaling")
        test_name=${current_member}/${test}
        arch_name=%STRONGSCALING.ARCH_NAME%
        test_config=%STRONGSCALING.TEST_CONFIG%
        ;;
    "weakscaling")
        test_name=${current_member}/${test}
        arch_name=%WEAKSCALING.ARCH_NAME%
        test_config=%WEAKSCALING.TEST_CONFIG%
        ;;
    "tracing")
        test_name=${current_member}/${test}
        arch_name=%TRACING.ARCH_NAME%
        test_config=%TRACING.TEST_CONFIG%
        ;;
esac

if [ -z "${test_config}" ]; then
    test_config=%EXPERIMENT.TEST_CONFIG%
fi

run_${model}

