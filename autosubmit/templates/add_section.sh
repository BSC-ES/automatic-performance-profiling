model=%MODEL.NAME%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
latex_folder=${cfg}/latex/
report_folder=%REPORT.FOLDER%
report_full_path=${report_folder}/%REPORT.NAME%.pkl
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
analysis_tools=${cfg}/trace_analysis/
members="%EXPERIMENT.MEMBERS%"
platform=%COMMON.PLATFORM%

function add_HardwareBenchmarks()
{
    hardware_benchmarks_root=$run_root/hardware_benchmarks

    python3 ${latex_folder}/ReportGenerator.py \
                                            -O ${report_full_path} \
                                            -S "Hardware Benchmarks" \
                                            -s "OSU Benchmark" \
                                            --add-img  ${hardware_benchmarks_root}/OSU_RUN/IMAGE \
                                            -T ${cfg}/latex/text/OSU.txt
    python3 ${latex_folder}/ReportGenerator.py \
                                            -O ${report_full_path} \
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

    dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/${platform}/*)

    for test in $tests
    do
        test_name_=${test_name}/$(basename $test)
        test_root=$run_root/$test_name_

        cd ${test_root}

        # Modelfactors
        python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Model Factors" --add-img modelfactors -T ${cfg}/latex/text/ModelFactors.txt
        
        # Scalability
        python3 ${latex_folder}/ReportGenerator.py \
                                                -O ${report_full_path} \
                                                -S "Scalability" \
                                                --add-img ${test}_scaling.png \
                                                --add-img-caption ${cfg}/latex/text/captions/Scalability.txt \
                                                --add-csv ${test}_scaling.csv \
                                                -T ${cfg}/latex/text/Scalability.txt
        # Paramedir
        trace_folders=$(find | grep trace_[0-9]*$)
        for trace_folder in ${trace_folders}
        do
            n_cores=$(echo $trace_folder | sed 's/trace_//')
            python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "MPI Call Profile" --add-csv ${test_root}/paramedir/${n_cores}_MPIcallprofile.csv --csv-convert -p
        done

        # Paraver TODO X11 issue
        # for paraver_image in paraver_images/*; do
        #     n_cores=${paraver_image##*/}
        #     python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Paraver" -s $n_cores' Core' --add-img $paraver_image
        # done
        # python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Paraver" -T ${cfg}/latex/text/ParaverViews.txt

        # Dimemas TODO X11 issue
        # python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Dimemas" --add-csv dimemas.csv -T ${cfg}/latex/text/Dimemas.txt
        # for config in ${dimemas_configurations}; do \
        #     config_type=${config##*/} ;\
        #     config_type=${config_type%.*} ;\
        #     for cores in ${number_of_processes}; do \
        #         image_name=${cores}_${config_type}.png ;\
        #         python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Dimemas" -s ${config_type} --add-img dimemas_images/${image_name} ;\
        #     done ;\
        # done

        # Function detail
        functions=$(find function_csv/*)
        python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -T ${cfg}/latex/text/Function.txt
        python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" --add-csv most_expensive_function_summary.csv
        for scatter_plot in ${papi_counters_plots}; do
            python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" --add-img ${scatter_plot}.png
        done 

        for func in ${functions} ; do \
            file_name=${func##function_csv/} ;\
            file_name=${file_name##tracking/MPI/} ;\
            func_name=${file_name%.csv} ;\
            echo ${func_name} ;\
            echo ${file_name} ;\
            python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -s  ${func_name} --add-csv  function_csv/${file_name}  --silent;\
            python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -s  ${func_name} --add-csv  tracking/MPI/${file_name} -p  --silent ;\
            python3 ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -s  ${func_name} --add-csv  tracking/counters/${file_name} -p --silent ;\
        done
    done
}

function add_CompilationEfficiency()
{
    test_name="compilation_efficiency"
    flag=-s
    python3 ${cfg}/parser/comparator.py --json-files $run_root/$test_name/*/*.json ${flag} --file-out ${current_member}.csv
    python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path} -S "Multi Experiment" -s ${current_member} --add-csv ${current_member}.csv
}

function add_WeakScaling()
{
    test_name="weakscaling"
    flag=-w
    python3 ${cfg}/parser/comparator.py --json-files $run_root/$test_name/*/*.json ${flag} --file-out ${current_member}.csv
    python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path} -S "Multi Experiment" -s ${current_member} --add-csv ${current_member}.csv
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
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path} --section-title "Introduction" --section-number 1 -T ${cfg}/latex/Introduction.txt

for current_member in ${members}; do 
    add_${current_member}
done