root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
latex_folder=${cfg}/latex/
report_path=%REPORT.PATH%
report_full_path=${report_path}/%REPORT.NAME%.pkl
report_conffile=%REPORT.CONFIG%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

source ${env_sources}
export PYTHONPATH=$PYTHONPATH:${project}

mkdir -p ${report_path}

# TODO Hardware works, other members not checked
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
       
else
    cd $run_root/$current_member
    source $inidata/

    if ["${current_member}" = "StrongScaling" ]; then
        # Modelfactors
	    python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Model Factors" --add-img modelfactors -T ${cfg}/latex/text/ModelFactors.txt
    fi
    
    # Scalability
	python ${latex_folder}/ReportGenerator.py \
                                            -O ${report_full_path} \
                                            -S "Scalability" \
                                            --add-img ${configuration_name}_scaling.png \
                                            --add-img-caption ${cfg}/latex/text/captions/Scalability.txt \
                                            --add-csv ${configuration_name}_scaling.csv \
                                            -T ${cfg}/latex/text/Scalability.txt
	# Paramedir
    for trace_folder in trace_*; do
        n_cores=$(echo $trace_folder | sed 's/test_//')
	    python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "MPI Call Profile" --add-csv ${trace_folder}/${n_cores}_MPIcallprofile.csv --csv-convert -p
    done

    # Paraver
    for paraver_image in paraver_images/*; do
        n_cores=${paraver_image##*/}
        python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Paraver" -s $n_cores' Core' --add-img $paraver_image
    done
    python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Paraver" -T ${cfg}/latex/text/ParaverViews.txt

    # Dimemas
	python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Dimemas" --add-csv dimemas.csv -T ${cfg}/latex/text/Dimemas.txt
	for config in ${dimemas_configurations}; do \
		config_type=${config##*/} ;\
		config_type=${config_type%.*} ;\
		for cores in ${number_of_processes}; do \
			image_name=${cores}_${config_type}.png ;\
			python ${latex_folder}/ReportGenerator.py -O ${report_full_path} -S "Dimemas" -s ${config_type} --add-img dimemas_images/${image_name} ;\
		done ;\
	done

    # Function detail
    cd $run_root/$current_member
    functions=$(find function_csv/* tracking/MPI/*)
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -T ${cfg}/latex/text/Function.txt
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-csv most_expensive_function_summary.csv
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-img Instructions_L1.png
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-img Instructions_L2.png
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-img Instructions_L3.png
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-img Instructions_Time.png
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-img Instructions_IPC.png
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-img L3_IPC.png
	for func in ${functions} ; do \
        file_name=${func##function_csv/} ;\
        file_name=${file_name##tracking/MPI/} ;\
        func_name=${file_name%.csv} ;\
        echo ${func_name} ;\
        echo ${file_name} ;\
        python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -s  ${func_name} --add-csv  function_csv/${file_name}  --silent;\
        python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -s  ${func_name} --add-csv  tracking/MPI/${file_name} -p  --silent ;\
        python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -s  ${func_name} --add-csv  tracking/counters/${file_name} -p --silent ;\
    done
fi