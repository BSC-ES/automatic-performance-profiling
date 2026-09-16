#!/bin/bash
# IMPORTANT: This file MUST be parsed first by Autosubmit, as it contains AS variables placeholders

function configure_extrae()
{
    local run_directory=$1
    local extrae_xml=${run_directory}/extrae.xml
    local cfg=%COMMON_PATH_LOCATIONS.CFG%
    cp ${cfg}/trace/extrae.xml.tmpl ${extrae_xml}

    local sed_extrae_home=%TRACING.EXTRAE.HOME%
    if ! [ -d ${sed_extrae_home} ]; then
        sed_extrae_home=${EXTRAE_HOME:-}
    fi
    sed_extrae_home=${sed_extrae_home//\//\\\/}

    sed -i "s/HOME/${sed_extrae_home}/" ${extrae_xml}
    sed -i "s/TRACE_NAME/%TRACING.EXTRAE.TRACE_NAME%/" ${extrae_xml}
    sed -i "s/CALLERS_ENABLED/%TRACING.EXTRAE.CALLERS.ENABLED%/" ${extrae_xml}
    sed -i "s/CALLERS_MPI_ENABLED/%TRACING.EXTRAE.CALLERS.MPI.ENABLED%/" ${extrae_xml}
    sed -i "s/CALLERS_MPI_LEVELS/%TRACING.EXTRAE.CALLERS.MPI.LEVELS%/" ${extrae_xml}
    sed -i "s/CALLERS_SAMPLING_ENABLED/%TRACING.EXTRAE.CALLERS.SAMPLING.ENABLED%/" ${extrae_xml}
    sed -i "s/CALLERS_SAMPLING_LEVELS/%TRACING.EXTRAE.CALLERS.SAMPLING.LEVELS%/" ${extrae_xml}
    sed -i "s/MPI_ENABLED/%TRACING.EXTRAE.MPI.ENABLED%/" ${extrae_xml}
    sed -i "s/MPI_COUNTERS_ENABLED/%TRACING.EXTRAE.MPI.COUNTERS.ENABLED%/" ${extrae_xml}
    sed -i "s/OPENMP_ENABLED/%TRACING.EXTRAE.OPENMP.ENABLED%/" ${extrae_xml}
    sed -i "s/USER_FUNCTIONS_ENABLED/%TRACING.EXTRAE.USER_FUNCTIONS.ENABLED%/" ${extrae_xml}
    sed -i "s/USER_FUNCTIONS_LIST/.\/extrae_functions_for_xml.txt/" ${extrae_xml}
    sed -i "s/PAPI_COUNTERS_ENABLED/%TRACING.EXTRAE.PAPI_COUNTERS.ENABLED%/" ${extrae_xml}
    sed -i "s/PAPI_COUNTERS_LIST/%TRACING.EXTRAE.PAPI_COUNTERS.LIST%/" ${extrae_xml}
}

function create_trace_sh()
{
    local run_directory=$1
    local trace=${run_directory}/trace.sh
    local extrae_lib="%TRACING.EXTRAE.TRACING_LIB%"
    local extrae_home="%TRACING.EXTRAE.HOME%"
    cat << EOF > ${trace}
#!/bin/bash

export EXTRAE_ON=1
export EXTRAE_CONFIG_FILE=${run_directory}/extrae.xml
export EXTRAE_SKIP_AUTO_LIBRARY_INITIALIZE=1
source ${extrae_home}/etc/extrae.sh

export LD_PRELOAD=${extrae_home}/lib/${extrae_lib}
export LD_LIBRARY_PATH=${extrae_home}/lib/:\$LD_LIBRARY_PATH

\$*
EOF
    chmod +x ${trace}
}

function generate_extrae_user_functions()
{
    functions_list="${@: -1}"
    i=1
    for binary in "$@"; do
        if [ $i -eq $# ]; then
            continue
        fi
        nm $binary | grep -i " T " | grep -f $functions_list | awk '{print $3" # "$1}'
        i=$((i+1))
    done
}