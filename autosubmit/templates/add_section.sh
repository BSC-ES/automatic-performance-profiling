root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%CFG%
latex_folder=${cfg}/latex/
report_file=%REPORT.NAME%.pkl
report_conffile=%REPORT.CONFIG%

if [ "${current_member}" = "StrongScaling" ]; then
	python ${latex_folder}/ReportGenerator.py \
                                            -O ${report_file} \ 
                                            -S "Scalability" \
                                            --add-img ${configuration_name}_scaling.png \
                                            --add-img-caption ${cfg}/latex/text/captions/Scalability.txt\
                                            --add-csv ${configuration_name}_scaling.csv \
                                            -T cfg/latex/text/Scalability.txt
elif [ "${current_member}" = "WeakScaling" ]; then

elif [ "${current_member}" = "CompilationEfficiency" ]; then

else 
    cd $run_root/hardware_benchmarks

    python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Hardware Benchmarks" -s "OSU Benchmark" --add-img  OSU_RUN/IMAGE -T ${cfg}/latex/text/OSU.txt
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Hardware Benchmarks" -s "STREAM Benchmark" --add-img  OSU_RUN/IMAGE -T cfg/latex/text/STREAM.txt
fi