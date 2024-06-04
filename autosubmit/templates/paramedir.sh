run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${project}/cfg/trace_analysis/
components="%MODEL.COMPONENTS%"
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%

function generate_threads_to_ignore_str()
{
    threads_to_ignore=""
    local i=0
    local first_proc=0
    while [ $i -lt ${#components_names[@]} ]; do
        component_procs=${components_procs[i]}
        last_proc=$((first_proc+component_procs-1))
        if [ "${components_names[i]}" != "${component}" ]; then
            for j in $(seq ${first_proc} ${last_proc}); do
                if [ "${threads_to_ignore}" != "" ]; then
                    threads_to_ignore="${threads_to_ignore}\n"
                fi
                threads_to_ignore="${threads_to_ignore}window_object thread { 0, $j, 1, { 0 } }"
            done
        fi
        first_proc=$((last_proc+1))
        i=$((i+1))
    done
}

###################
# Start script
###################

source ${env_sources}

member="tracing"
tests="%TRACING.TEST_NAMES%"
tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)
components=($(echo $components | sed "s/\[\|\]\|,//g"))
components=$(for v in "${components[@]}"; do echo "$v";done| sort| uniq| xargs)
paramedir_configurations=$(find ${analysis_tools}/paramedir_configurations/*)

for test in $tests
do
    test_folder=${run_root}/${member}/${test}
    mkdir -p  ${test_folder}/paramedir

    # WORKING DIRECTORY: paramedir folder in test's root folder
    cd ${test_folder}/paramedir
    rm -f *.pm

    for trace_folder in $test_folder/trace_*
    do
        basename_trace_folder=$(basename ${trace_folder})
        components_names=($(echo ${basename_trace_folder} | sed -e 's/\(trace_\|[0-9]\)//g' | sed 's/_/ /g'))
        components_procs=($(echo ${basename_trace_folder} | sed -e 's/\(trace_\|[a-zA-Z]\)//g' | sed 's/_/ /g'))
        trace_id=$(echo ${basename_trace_folder} | sed -e 's/trace_//')

        for component in ${components}; do
            trace=${trace_folder}/${component}.best_cut.prv

            generate_threads_to_ignore_str

            # paramedir.target
            ##################
            for cfg in ${paramedir_configurations[@]} 
            do
                cp ${cfg} .
                mod_cfg=$(basename ${cfg})

                sed -i "s/window_object appl { 1, { All } }/${threads_to_ignore}/" ${mod_cfg}

                ${analysis_tools}/paramedir ${trace} ${mod_cfg} 
                # Get the extension
                cfg_extension=${cfg#*.}
                # Remove path
                cfg_name=${cfg##*/}
                # Remove the extension
                cfg_name=${cfg_name%.${cfg_extension}}
                # This is a 3D with function view
                if [[ ${cfg_extension} == "pm.cfg" ]] 
                then
                    mv ${cfg_name}.pm ${component}-${trace_id}-${cfg_name}.pm
                # This is a normal csv which can be directly put in report
                else
                    mv ${cfg_name} ${component}-${trace_id}-${cfg_name}.csv
                fi
            done
            ##################
        done
    done
done

