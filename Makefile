# Reading Input parameters
parameters_file?=configurations/model/nemo/strongscaling/BENCH
# If no queue has been specified it will use debug where possible
slurm_queue?=debug
# File to save all the data to produce the report
report_file?=report.pkl
# Reading some parameters from the config file
include ${parameters_file}
# Check that the io server has been specified
ifndef  main_folder
$(error main_folder must be defined in configuration file )
endif
main_folder_fullpath=run_dir/${main_folder}

# Tools folder
cfg=$(CURDIR)/cfg
analysis_tools=${cfg}/trace_analysis/
export analysis_tools

latex_folder=${cfg}/latex
# Reading the report settings
report_file_full_path=$(CURDIR)/${report_file}
report_cfg=${cfg}/latex/report.cfg
include ${report_cfg}

cores?=8
# Check environment is loaded
####################################################
$(eval ssh_id := $(shell echo ${SSH_CONNECTION} | awk '{print $$2}'))
ifeq ("$(wildcard .$(ssh_id).env_loaded )","")
  $(error Please load the environment sourcing load_env.sh file)
endif
###################################################
# Experiment recipes specified in param.cfg file
experiment:
	for recipe in ${experiment_recipes} ; do \
                echo $${recipe} ; \
				[ ! -d ${main_folder_fullpath} ] && git clone . ${main_folder_fullpath} ;\
				cp ${parameters_file} ${main_folder_fullpath}/param.cfg ;\
				cd  ${main_folder_fullpath} ;\
				source ./load_env.sh ;\
				cd - ;\
				$(MAKE) -C ./${main_folder_fullpath} parameters_file=param.cfg slurm_queue=${slurm_queue} $${recipe} ; \
        done


####################################################
# Recipes to prepare inidata
inidata:
	# Download data, put it in inidata and remove write permissions to avoid undesired modifications
	mkdir -p inidata
	${cfg}/target/model/${model}/inidata.target
%/.inidata.done: inidata
	mkdir -p $(@D)
	# Link inidata
	ln -rsf inidata/* $(@D)
	rsync -rv --exclude=.nc inidata/ $(@D)
	touch $@


####################################################
# The sources are prepared
%_source:
	${cfg}/target/model/${model}/$*_source.target ${cfg}

####################################################
# Recipe to compile different model versions
# The subscript indicates the version that we are compiling (vanilla, trace)
bin/${model}_%.exe: ${model}_source
	mkdir -p $(@D)
	${cfg}/target/model/${model}/${model}_exec.target $* $@ $<


####################################################
# Recipes to prepare functions file for tracing
# TODO: find a better way of prepare these rundirs without repeating code
functions_dir/extrae_functions.txt: bin/${model}_trace.exe bin/xios_server.exe
	${MAKE} $(@D)/.inidata.done
	${cfg}/target/model/${model}/functions_dir.target $(@D)
	python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/function.slurm \
                                     --set-time  120 \
                                     --set-core $(word 1, ${number_of_processes}) \
                                     --set-core-per-node ${processes_per_node} \
                                     --job-name $(@D) \
				     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/function.slurm \
                                            --set-workload ${cfg}/target/functions_dir.target bin/${model}_trace.exe

	sbatch --wait --chdir $(@D) $(@D)/function.slurm


#################### TRACE
TRACE_EXPERIMENTS=$(foreach var, $(number_of_processes), trace_$(var)/trace.slurm)
trace_experiments: functions_dir/extrae_functions.txt bin/${model}_trace.exe inidata
	make -j${cores} $(TRACE_EXPERIMENTS)

# Recipe to make traces
trace_%/trace.slurm: functions_dir/extrae_functions.txt bin/${model}_trace.exe inidata
	mkdir -p $(@D)
	cp $< $(@D)
	${MAKE} $(@D)/.inidata.done

	# Copy jobscript and trace utils
	cp cfg/trace/* $(@D)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time  120 \
                                     --set-core $* \
                                     --set-core-per-node ${processes_per_node} \
                                     --job-name $(@F) \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name  $@ \
                                            --set-workload ${cfg}/target/model/${model}/trace.target $*
	# Launch jobscript
	sbatch --wait --chdir $(@D) $@


# prepare env for cutting the trace
export PATH := $(CURDIR)/magiccut/bin:$(PATH)
magiccut:
	# Download sources
	git clone https://earth.bsc.es/gitlab/ces/magiccut.git --branch numpy_version
	# Setup tool
	cd $@; ./setup_tool.cmd

### Cut the trace
TRACE_CUT=$(foreach var, $(number_of_processes), trace_$(var)/${model}.best_cut.prv)
trace_cut:
	make -j${cores} $(TRACE_CUT)

trace_%/${model}.best_cut.prv: trace_%/trace.slurm | magiccut
	# Magic Cut
	cd $(@D); magicCut ${model}.prv ${trace_steps}

#################### PARAMEDIR
PARAMEDIR_EXPERIMENTS=$(foreach var, $(number_of_processes), trace_$(var)/paramedir.slurm)
paramedir_experiments: trace_cut
	 make -j${cores} $(PARAMEDIR_EXPERIMENTS)

paramedir_configurations=$(wildcard ${analysis_tools}/paramedir_configurations/*)
trace_%/paramedir.slurm: trace_%/${model}.best_cut.prv
	 python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time-second  $$((10 * $*)) \
                                     --set-core 48 \
                                     --set-core-per-node ${processes_per_node} \
                                     --job-name paramedir_$* \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name  $@ \
                                            --set-workload ${cfg}/target/paramedir.target $(<F) $* ${paramedir_configurations}
	# Launch jobscript
	sbatch --wait --chdir $(@D) $@

trace_%/report_add_paramedir: trace_%/paramedir.slurm
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "MPI Call Profile" --add-csv $(@D)/$*_MPIcallprofile.csv --csv-convert -p

REPORT_ADD_PARAMEDIR=$(foreach var, $(number_of_processes), trace_$(var)/report_add_paramedir)
report_add_paramedir: $(REPORT_ADD_PARAMEDIR)

####################### PARAVER
PARAVER_IMAGES=$(foreach var, $(number_of_processes), paraver_images/$(var))
paraver_images: trace_cut .info_report.done
	make -j${cores} $(PARAVER_IMAGES)

paraver_configurations=$(wildcard ${analysis_tools}/paraver_configurations/*)
paraver_images/%: trace_%/${model}.best_cut.prv .info_report.done
	# Make paraver images
	mkdir -p  $@
	${cfg}/target/paraver.target $< $@ ${paraver_configurations}
	${cfg}/target/create_paraver_function_legend.target most_expensive_function_summary.csv $< $*
	${cfg}/target/create_paraver_legend.target $< $* ${paraver_configurations}

### Add paraver to the report
report_add_%_paraver: paraver_images/%
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Paraver" -s $*' Core' --add-img $<

REPORT_ADD_PARAVER=$(foreach var, $(number_of_processes), report_add_$(var)_paraver)
report_add_paraver: $(REPORT_ADD_PARAVER) 
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Paraver" -T cfg/latex/text/ParaverViews.txt

####################### DIMEMAS
dimemas_configurations=$(wildcard ${analysis_tools}/dimemas_configurations/*)

DIMEMAS_TRC=$(foreach var, $(number_of_processes), dimemas_traces/$(var).dim)
dimemas_trc: trace_cut
	make -j${cores} $(DIMEMAS_TRC)

dimemas_traces/%.dim: trace_%/${model}.best_cut.prv
	mkdir -p $(@D)
	python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/prv2dim.slurm \
                                     --set-time-seconds $$(( $* )) \
                                     --job-name $(@F) \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/prv2dim.slurm --set-workload ${analysis_tools}/prv2dim $< $(@F)
	sbatch --wait --chdir dimemas_traces $(@D)/prv2dim.slurm

DIMEMAS_EXPERIMENTS=$(foreach var, $(number_of_processes), dimemas_traces/dimemas_$(var).slurm)
dimemas_experiments: dimemas_trc
	make -j${cores} $(DIMEMAS_EXPERIMENTS)

dimemas_traces/dimemas_%.slurm: dimemas_traces/%.dim
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time-seconds $$(( $* * 7 )) \
                                     --job-name dimemas_$* \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ --set-workload cfg/target/dimemas.target $< ${dimemas_configurations}
	sbatch --wait --chdir dimemas_traces $@

### Process images
DIMEMAS_IMAGES=$(foreach var, $(number_of_processes), dimemas_images/.dimemas_images_$(var).done)
dimemas_images: dimemas_experiments
	make -j${cores} $(DIMEMAS_IMAGES)

dimemas_images/.dimemas_images_%.done: dimemas_traces/dimemas_%.slurm
	mkdir -p $(@D)
	@${cfg}/target/dimemas_images.target $* ${dimemas_configurations}
	touch $@

report_add_dimemas_images: $(DIMEMAS_IMAGES)
	for config in ${dimemas_configurations}; do \
		config_type=$${config##*/} ;\
		config_type=$${config_type%.*} ;\
		for cores in ${number_of_processes}; do \
			image_name=$${cores}_$${config_type}.png ;\
			python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Dimemas" -s $${config_type} --add-img dimemas_images/$${image_name} ;\
		done ;\
	done

report_add_dimemas: .info_report.done
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Dimemas" --add-csv dimemas.csv -T cfg/latex/text/Dimemas.txt
	$(MAKE) report_add_dimemas_images

####################### PARADIM
# Run the paramedir configurations with all the dimemas traces
PARADIM_EXPERIMENTS=$(foreach var, $(number_of_processes), dimemas_traces/paradim_$(var).slurm)
paradim_experiments: dimemas_experiments
	make -j${cores} $(PARADIM_EXPERIMENTS)

paradim_configurations=$(wildcard cfg/trace_analysis/paradim_configurations/*)
dimemas_traces/paradim_%.slurm: dimemas_traces/dimemas_%.slurm
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time-seconds $$(( $* * 8 )) \
                                     --job-name paradim_$* \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ --set-workload cfg/target/paradim.target $* ${paradim_configurations}
	sbatch --wait --chdir dimemas_traces dimemas_traces/paradim_$*.slurm

###################### TEST
SCALABILITY=$(foreach var, $(number_of_processes), test_$(var)/test.slurm)
scalability:  bin/${model}_vanilla.exe bin/xios_server.exe inidata
	make -j${cores} $(SCALABILITY)

# Recipes to launch some basic tests
test_%/test.slurm: bin/${model}_vanilla.exe bin/xios_server.exe
	${MAKE} $(@D)/.inidata.done
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time 120 \
                                     --set-core $* \
                                     --set-core-per-node ${processes_per_node} \
                                     --job-name $(@D) \
                                     --set-queue $(slurm_queue)
	# Moldel specific instruction
	python cfg/slurm/SlurmJobCreator.py --file-name $@ --set-workload ${cfg}/target/model/${model}/test.target $*
	# Launch job
	sbatch --wait --chdir $(@D)  $@
####################################################

# Some other recipes

# Xios server
bin/xios_server.exe:
	mkdir -p $(@D)
	# TODO: HARDCODED dependency that at some point should be replaced with xios compilation
	cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe bin/xios_server.exe

####################################################
# Clean recipes
# Delete (almost)-everything
clean:
	rm -rf  nemo_source nemo_mirror *.prv *.row *.pcf modelfactors* histogram_* trace_* functions_dir extrae_functions.txt *_workdir bin test_*
	rm -rf function_csv/
	rm -rf OSU* osu* bin/osu_bench .osu*
	rm -rf STREAM* stream* bin/stream_bench .stream*
	rm -rf *.json
	rm -rf *.pkl
	rm -rf .*.done
	rm -rf report_*
	rm -rf dimemas_traces
	rm -rf MultiExperimentRuns
	rm -rf cfg/target/param_bash.cfg
hard_clean:
	-chmod +w inidata
	-chmod +w InitialConditions.nc
	rm -rf inidata InitialConditions.nc 
clean_%:
	rm -rf $*

################ MODELFACTORS
TRACE_CUT_FULL_PATH=$(foreach var, $(number_of_processes), $(CURDIR)/trace_$(var)/${model}.best_cut.prv)
modelfactors: $(TRACE_CUT)
	mkdir -p $@
	cd $@  ;\
	${analysis_tools}/modelfactors $(TRACE_CUT_FULL_PATH) ;\
	rm -rf *hybrid*
report_add_modelfactors: modelfactors
	# Add produced pictures to latex report
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Model Factors" --add-img $^ -T cfg/latex/text/ModelFactors.txt

# Function histograms
histogram_%.txt: trace_%/${model}.best_cut.prv
	${analysis_tools}/paramedir $< ${analysis_tools}/cfgs/FunctionTimeHistogram.cfg
	mv FunctionTimeHistogram histogram_$*.txt

histograms_dependencies=$(foreach var, $(number_of_processes), histogram_$(var).txt)
histograms: $(histogram_dependencies)

analysis: histograms modelfactors scalability	


################ JSON
# Stores the info produces from all the experiments in a json file
JSON= $(SCALABILITY) $(PARAMEDIR_EXPERIMENTS) $(PARADIM_EXPERIMENTS)
# Submits a job to creat json file: used when the traces have been taken on a big N of cores
process_json.slurm: $(JSON)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-core 48 \
                                     --set-time 120 \
                                     --job-name ${configuration_name}.json \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ --set-workload make ${configuration_name}.json
	sbatch --wait --chdir . $@

${configuration_name}.json: $(JSON)
	python cfg/parser/collector.py --input-files test_*/*.timing trace_*/*pm dimemas_traces/*dm \
                                       --output-file ${configuration_name} \
                                       --param-file param.cfg


################ INFO
# Produces imagaes and csv files from info stored in a json file
.info_report.done: ${configuration_name}.json
	python cfg/parser/reporter.py \
                                    -j ${configuration_name}.json \
                                    --sypd-file ${configuration_name}_scaling.csv \
                                    --sypd-plot ${configuration_name}_scaling.png \
                                    -f function_csv \
                                    --functions-file functions_summary.txt \
                                    --most_expensive_function_summary most_expensive_function_summary.csv \
		          	    --L3_IPC_scatterplot L3_vs_IPC.png \
				    --dimemas-file dimemas.csv \
    	                            --tracking-folder tracking
	touch $@
clean_info_report:
	rm -f ${configuration_name}_scaling.csv
	rm -f ${configuration_name}_scaling.png
	rm -rf function_csv
	rm -f functions_summary.txt
	rm -f most_expensive_function_summary.csv
	rm -f L3_vs_IPC.png
	rm -f dimemas.csv
	rm -rf tracking
################ REPORT ADD SCALALBILITY
report_add_scalability: .info_report.done
	python ${latex_folder}/ReportGenerator.py -O ${report_file} \
                                          -S "Scalability" \
                                          --add-img ${configuration_name}_scaling.png \
                                          --add-img-caption cfg/latex/text/captions/Scalability.txt\
                                          --add-csv ${configuration_name}_scaling.csv \
                                          -T cfg/latex/text/Scalability.txt

################ REPORT ADD FUNCTION INFO
functions=$(wildcard function_csv/* tracking/MPI/*)
report_add_function_detail: .info_report.done
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -T cfg/latex/text/Function.txt
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-csv most_expensive_function_summary.csv
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" --add-img L3_vs_IPC.png
	for func in ${functions} ; do \
                file_name=$${func##function_csv/} ;\
                file_name=$${file_name##tracking/MPI/} ;\
                func_name=$${file_name%.csv} ;\
                echo $${func_name} ;\
                echo $${file_name} ;\
                python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -s  $${func_name} --add-csv  function_csv/$${file_name}  --silent;\
                python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -s  $${func_name} --add-csv  tracking/MPI/$${file_name} -p  --silent ;\
                python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Functions detailed report" -s  $${func_name} --add-csv  tracking/counters/$${file_name} -p --silent ;\
        done

##########################

MULTIEXP_CSV=$(foreach exp, $(multiexperiment), $(exp).csv)
multiexp_csv: $(MULTIEXP_CSV)
${configuration_name}_weakscaling.csv: run_dir/MultiExperimentRuns/weakscaling/${configuration_name}
	python cfg/parser/comparator.py --json-files $</*/*.json -w --file-out $@

${configuration_name}_compilation_efficiency.csv: run_dir/MultiExperimentRuns/compilation_efficiency/${configuration_name}
	python cfg/parser/comparator.py --json-files $</*/*.json -s --file-out $@
	touch $@

clean_multiexp_csv:
	for experiment in ${exp}; do rm -rf ${experiment}.csv; done
report_add_Multi_%: %.csv
	python cfg/latex/ReportGenerator.py -O ${report_file} -S "Multi Experiment" -s $* --add-csv $*.csv

%_postproc: .%_postproc.done
	@echo $@ "done"

#################### BENCHMARKS
### STREAM
STREAM/stream:
	git clone https://github.com/jeffhammond/STREAM.git
	cd $(@D); gcc -fopenmp -D_OPENMP stream.c -o $(@F)

STREAM_RUN/stream.slurm: STREAM/stream
	mkdir -p $(@D)
	cp $< $(@D)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time 5 \
                                     --set-core 1 \
                                     --job-name $(@D) \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name  $@ --set-workload cfg/target/stream.target
	sbatch --wait --chdir $(@D) $@

STREAM_RUN/STREAM_${model}.png: STREAM_RUN/stream.slurm
	python ${cfg}/benchmarks/STREAM/STREAM_data_parser.py -i $(@D)  --png --png-output-name $@

clean_STREAM_${model}.png:
	rm -rf STREAM_RUN/STREAM_${model}.png
# Add stream data to the report
report_add_stream: STREAM_RUN/STREAM_${model}.png
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Hardware Benchmarks" -s "STREAM Benchmark" --add-img  $< -T cfg/latex/text/STREAM.txt
### OSU
osu-micro-benchmarks-%:
	${cfg}/target/osu_install.target $@

OSU_RUN=$(foreach var, $(number_of_processes), OSU_RUN/$(var)/osu.slurm)
osu_run: osu-micro-benchmarks-5.6.3
	 $(MAKE) -j${cores} $(OSU_RUN)
osu_binaries=$(foreach test, $(osu_tests), osu-micro-benchmarks-5.6.3/mpi/$(test))
OSU_RUN/%/osu.slurm: osu-micro-benchmarks-5.6.3
	mkdir -p $(@D)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time 15 \
                                     --set-core $* \
                                     --job-name OSU_RUN_$* \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name  $@ --set-workload ${cfg}/target/osu.target ${osu_binaries}  
	sbatch --wait --chdir $(@D) $@

OSU_RUN/IMAGE: $(OSU_RUN)
	mkdir -p $@
	for test in ${osu_tests} ; do \
		test_name=$${test##*/} ;\
		python cfg/benchmarks/OSU/OSU_test_plots.py -i OSU_RUN/DATA/$${test_name}* -o $@;\
	done
clean_OSU_RUN_IMAGE:
	rm -rf OSU_RUN/IMAGE
# Add results to report
report_add_osu: OSU_RUN/IMAGE
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Hardware Benchmarks" -s "OSU Benchmark" --add-img  $< -T cfg/latex/text/OSU.txt

hardware_benchmarks:  STREAM_RUN/stream.slurm osu_run

# Add benchmarks to report
report_add_benchmarks: report_add_osu report_add_stream
	python ${latex_folder}/ReportGenerator.py -O ${report_file} -S "Hardware Benchmarks" -T cfg/latex/text/HardwareBenchmarks.txt
################## REPORT
report_add_strong_scaling: report_add_scalability report_add_modelfactors report_add_paraver report_add_dimemas report_add_function_detail
#report_add_multi: report_add_Multi_${configuration_name}_compilation_efficiency report_add_Multi_${configuration_name}_weakscaling
report_add_multi: report_add_Multi_${configuration_name}_compilation_efficiency

report:
	# Creates the report, dumping all the info to a tex file, and adding authors and title
	mkdir $@
	cfg/target/$@.target ${report_file} ${parameters_file} ${report_cfg}
clean_report:
	rm -rf ${report_file} report
############### TARGET FOR PARALLEL MAKE
strong_scaling:
	${MAKE} scalability
	${MAKE} trace_cut
	${MAKE} modelfactors paraver_images dimemas_experiments
	${MAKE} paradim_experiments

paraver_images: trace_experiments
dimemas_experiments: trace_experiments
paradim_experiments: dimemas_experiments


REPORT_PREPROC = .info_report.done modelfactors dimemas_images OSU_RUN/IMAGE STREAM_RUN/STREAM_${model}.png multiexp_csv
report_preproc: $(REPORT_PREPROC)

clean_report_preproc: clean_info_report clean_modelfactors clean_paraver_images clean_dimemas_images clean_OSU_RUN_IMAGE clean_STREAM_${model}.png clean_multiexp_csv
# Intermediate files that won't be removed automatically
binaries= bin/nemo_trace.exe bin/nemo_vanilla.exe
.PRECIOUS: ${nemo}_source $(binaries)  %.dim *.env_loaded

.DELETE_ON_ERROR: $(PARAMEDIR_EXPERIMENTS) $(DIMEMAS_EXPERIMENTS) $(PARADIM_EXPERIMENTS)
