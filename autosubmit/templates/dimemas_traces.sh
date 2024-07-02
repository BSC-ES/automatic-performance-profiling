#!/bin/bash
#####################################################################################################################
# extrae.sh
# Brief: This script runs the model with Extrae in order to trace the PAPI counters, user functions and MPI events
#####################################################################################################################

###################
# AS variables
###################
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
analysis_tools=%COMMON_PATH_LOCATIONS.CFG%/trace_analysis/
platform=%COMMON.PLATFORM%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
components="%MODEL.COMPONENTS%"
tests="%TRACING.TEST_NAMES%"

source ${env_sources}

member="tracing"
tests=${tests//[\[,\]]/}
tests=$(for v in $tests; do echo "$v";done| sort| uniq| xargs)
components=${components//[\[,\]]/}
components=$(for v in $components; do echo "$v";done| sort| uniq| xargs)
dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/${platform}/*)

for test in $tests
do
    test_name=${member}/${test}
    
    # WORKING DIR: test's root folder
    cd $run_root/$test_name || exit
    mkdir -p dimemas_traces
    for trace_folder in trace_*
    do
        for component in ${components}; do
            trace=${trace_folder}/${component}.best_cut.prv
            trace_id=$(echo $trace_folder | sed 's/.*trace_//')
            dim_trace=dimemas_traces/${trace_id}.dim
            
            prv2dim ${trace} ${dim_trace}
            
            # dimemas.target
            ##################
            # Remove path and extension
            dim_trace_name=${dim_trace##*/}
            dim_trace_name=${dim_trace_name%.*}
            for cfg in $dimemas_configurations 
            do
                # Remove the path and extension
                cfg_name=${cfg##*/}
                cfg_name=${cfg_name%.*}

                Dimemas -S 32k --dim ${dim_trace} -p dimemas_traces/${dim_trace_name}_${cfg_name}.prv --config-file ${cfg}
            done
            ##################
        done
    done
done
