model=%COMMON.MODEL%
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

source ${env_sources}
export PYTHONPATH=$PYTHONPATH:${project}

rm -rf ${report_folder}

mkdir -p ${report_folder}
python ${cfg}/latex/ReportGenerator.py -O ${report_full_path} --section-title "Introduction" --section-number 1 -T ${cfg}/latex/Introduction.txt

for current_member in ${members}; do 
    if [ "${current_member}" = "HardwareBenchmarks" ]; then
        hardware_benchmarks_root=$run_root/hardware_benchmarks

        python ${latex_folder}/ReportGenerator.py \
                                                -O ${report_full_path} \
                                                -S "Hardware Benchmarks" \
                                                -s "OSU Benchmark" \
                                                --add-img  ${hardware_benchmarks_root}/OSU_RUN/IMAGE \
                                                -T ${cfg}/latex/text/OSU.txt
        python ${latex_folder}/ReportGenerator.py \
                                                -O ${report_full_path} \
                                                -S "Hardware Benchmarks" \
                                                -s "STREAM Benchmark" \
                                                --add-img  ${hardware_benchmarks_root}/OSU_RUN/IMAGE \
        
    elif [ "$current_member" = "StrongScaling" ]; then
        test_name="strong_scaling"
        folders=%STRONGSCALING.STRONGSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%

        dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/mn4/*)

        for test in $folders
        do
            test_name_=${test_name}
            test_root=$run_root/$test_name_

            source $inidata/$test_name_/param_bash.cfg
            cd ${test_root}

            # Modelfactors
            python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Model Factors" --add-img modelfactors -T ${cfg}/latex/text/ModelFactors.txt
            
            # Scalability
            python ${latex_folder}/ReportGenerator.py \
                                                    -O ${report_full_path} \
                                                    -S "Scalability" \
                                                    --add-img ${configuration_name}_scaling.png \
                                                    --add-img-caption ${cfg}/latex/text/captions/Scalability.txt \
                                                    --add-csv ${configuration_name}_scaling.csv \
                                                    -T ${cfg}/latex/text/Scalability.txt
            # Paramedir
            trace_folders=$(find | grep trace_[0-9]*$)
            for trace_folder in ${trace_folders}
            do
                n_cores=$(echo $trace_folder | sed 's/trace_//')
                python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "MPI Call Profile" --add-csv ${test_root}/paramedir/${n_cores}_MPIcallprofile.csv --csv-convert -p
            done

            # Paraver TODO X11 issue
            # for paraver_image in paraver_images/*; do
            #     n_cores=${paraver_image##*/}
            #     python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Paraver" -s $n_cores' Core' --add-img $paraver_image
            # done
            # python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Paraver" -T ${cfg}/latex/text/ParaverViews.txt

            # Dimemas TODO X11 issue
            # python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Dimemas" --add-csv dimemas.csv -T ${cfg}/latex/text/Dimemas.txt
            # for config in ${dimemas_configurations}; do \
            #     config_type=${config##*/} ;\
            #     config_type=${config_type%.*} ;\
            #     for cores in ${number_of_processes}; do \
            #         image_name=${cores}_${config_type}.png ;\
            #         python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Dimemas" -s ${config_type} --add-img dimemas_images/${image_name} ;\
            #     done ;\
            # done

            # Function detail
            functions=$(find function_csv/* tracking/MPI/*)
            python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -T ${cfg}/latex/text/Function.txt
            python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" --add-csv most_expensive_function_summary.csv
            for scatter_plot in ${papi_counters_plots}; do
                python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" --add-img ${scatter_plot}.png
            done 

            for func in ${functions} ; do \
                file_name=${func##function_csv/} ;\
                file_name=${file_name##tracking/MPI/} ;\
                func_name=${file_name%.csv} ;\
                echo ${func_name} ;\
                echo ${file_name} ;\
                python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -s  ${func_name} --add-csv  function_csv/${file_name}  --silent;\
                python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -s  ${func_name} --add-csv  tracking/MPI/${file_name} -p  --silent ;\
                python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Functions detailed report" -s  ${func_name} --add-csv  tracking/counters/${file_name} -p --silent ;\
            done
        done
    else
        if [ "$current_member" = "CompilationEfficiency" ]; then
            test_name="compilation_efficiency"
            folders=%COMPILATION_EFFICIENCY.COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
            flag=-s
        else
            test_name="weakscaling"
            folders=%WEAKSCALING.WEAKSCALING_PARAMETERS_ROOT%/%COMMON.CONFIGURATION%/*
            flag=-w
        fi


        python ${cfg}/parser/comparator.py --json-files $run_root/$test_name/*/*.json ${flag} --file-out ${current_member}.csv
        python ${cfg}/latex/ReportGenerator.py -O ${report_full_path} -S "Multi Experiment" -s ${current_member} --add-csv ${current_member}.csv
    fi
done