#!/bin/bash

model=%MODEL.NAME%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
latex_folder=${cfg}/latex/
report_folder=%REPORT.FOLDER%
report_conffile=%REPORT.CONFIG%
report_name=%REPORT.NAME%
report_full_path=${report_folder}/%REPORT.NAME%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
members="StrongScaling HardwareBenchmarks"
components="%MODEL.COMPONENTS%"
configuration_name=%STRONGSCALING.TEST_CONFIG%

components=($(echo $components | sed "s/\[\|\]\|,//g"))
components=$(for v in "${components[@]}"; do echo "$v";done| sort| uniq| xargs)

function add_HardwareBenchmarks()
{
    hardware_benchmarks_root=$run_root/hardware_benchmarks

    python3 ${latex_folder}/ReportGenerator.py \
                                            -O ${report_full_path}.pkl \
                                            -S "Hardware Benchmarks" \
                                            -s "OSU Benchmark" \
                                            --add-img  ${hardware_benchmarks_root}/OSU_RUN/IMAGE \
                                            -T ${cfg}/latex/text/OSU.txt
    python3 ${latex_folder}/ReportGenerator.py \
                                            -O ${report_full_path}.pkl \
                                            -S "Hardware Benchmarks" \
                                            -s "STREAM Benchmark" \
                                            --add-img  ${hardware_benchmarks_root}/OSU_RUN/IMAGE 
}

function add_StrongScaling()
{
    test_name="strong_scaling"
    papi_counters_plots="%TRACING.PAPI_COUNTERS_PLOTS%"
    tests="%STRONGSCALING.TEST_NAMES%"
    tests=($(echo $tests | sed "s/\[\|\]\|,//g"))
    tests=$(for v in "${tests[@]}"; do echo "$v";done| sort| uniq| xargs)

    # dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/${platform}/*)

    for test in $tests
    do
        test_name_=${test_name}/$(basename $test)
        test_root=$run_root/$test_name_

        cd ${test_root}

        # Modelfactors
        python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "Model Factors" --add-img modelfactors -T ${cfg}/latex/text/ModelFactors.txt
        
        # Scalability

        python3 ${latex_folder}/ReportGenerator.py \
                                                -O ${report_full_path}.pkl \
                                                -S "Scalability" \
                                                --add-csv cases_info.csv


        python3 ${latex_folder}/ReportGenerator.py \
                                                -O ${report_full_path}.pkl \
                                                -S "Scalability" \
                                                --add-img ${test}_scaling.png \
                                                --add-img-caption ${cfg}/latex/text/captions/Scalability.txt \
                                                --add-csv ${test}_scaling.csv \
                                                -T ${cfg}/latex/text/Scalability.txt
        
        for component in ${components}; do
            python3 ${latex_folder}/ReportGenerator.py \
                                                    -O ${report_full_path}.pkl \
                                                    -S "${component^^} Scalability" \
                                                    --add-img ${component}_${test}_scaling.png \
                                                    --add-csv ${component}_${test}_scaling.csv
        done

        # Paramedir
        for trace_folder in trace_*
        do
            trace_id=$(echo $trace_folder | sed 's/trace_//')
            for component in ${components}; do
                python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} MPI Call Profile" --add-csv ${test_root}/paramedir/${component}-${trace_id}-MPIcallprofile.csv --csv-convert -p
            done
        done

        # Function detail
        python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "Functions detailed report" -T ${cfg}/latex/text/Function.txt
        python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "Functions detailed report" -s "Most expensive function summary" --add-csv most_expensive_function_summary.csv
        for component in ${components}; do
            python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} Functions detailed report" -s "Most expensive function summary" --add-csv ${component}_most_expensive_function_summary.csv
            for scatter_plot in ${papi_counters_plots}; do
                python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} Functions detailed report" -s "PAPI counters plots" --add-img ${component}-${scatter_plot}.png
            done 
        done
    
        for component in ${components}; do
            functions=$(find function_csv/* | grep ${component})
            for func in ${functions} ; do \
                file_name=${func##function_csv/} ;\
                file_name=${file_name##tracking/MPI/} ;\
                func_name=${file_name%.csv} ;\
                echo ${func_name} ;\
                echo ${file_name} ;\
                python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} Functions detailed report" -s  ${func_name} --add-csv  function_csv/${file_name}  --silent;\
                python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} Functions detailed report" -s  ${func_name} --add-csv  tracking/MPI/${file_name} -p  --silent ;\
                python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} Functions detailed report" -s  ${func_name} --add-csv  tracking/counters/${file_name} -p --silent ;\
            done
        done
        
        # Paraver TODO X11 issue
        for component in ${components}; do
            for case in paraver_images/*; do
                for paraver_image in $(find $case | grep -E ".*@${component}.*png"); do 
                    python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} Paraver" -s "$(basename ${case})" --add-img ${paraver_image}
                done 
            done
            python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "${component^^} Paraver" -T ${cfg}/latex/text/ParaverViews.txt
        done

        # Coupling info (ECE4 only)
        if [ -d coupling ]; then
            for case in coupling/*; do
                python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "Coupling" -s "$(basename ${case})" --add-csv ${case}/summary.csv
                python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path}.pkl -S "Coupling" -s "$(basename ${case})" --add-img ${case}/stacked_events.png
            done
        fi
    done
}

function add_CompilationEfficiency()
{
    test_name="compilation_efficiency"
    flag=-s
    python3 ${cfg}/parser/comparator.py --json-files $run_root/$test_name/*/*.json ${flag} --file-out ${current_member}.csv
    python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl -S "Multi Experiment" -s ${current_member} --add-csv ${current_member}.csv
}

function add_WeakScaling()
{
    test_name="weakscaling"
    flag=-w
    python3 ${cfg}/parser/comparator.py --json-files $run_root/$test_name/*/*.json ${flag} --file-out ${current_member}.csv
    python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl -S "Multi Experiment" -s ${current_member} --add-csv ${current_member}.csv
}


###################
# Start script
###################
source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

rm -rf ${report_folder}
mkdir -p ${report_folder}

# Add the introduction to the report
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --section-title "Introduction" --section-number 1 -T ${cfg}/latex/Introduction.txt

for current_member in ${members}; do 
    add_${current_member}
done

source ${report_conffile}
echo model=${model^^} > param.cfg
echo configuration_name=${configuration_name} >> param.cfg
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --add-newcommand param.cfg
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --report-title "${title}"
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --report-authors "${authors}"

# Create the tex file
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path} --dump-to-file
# Compile the report
cd ${report_folder}
pdflatex ${report_name}.tex && pdflatex ${report_name}.tex