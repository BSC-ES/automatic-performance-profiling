# Makefile to prepare all the necessary elements to launch a performance analysis on NEMO

# Reading some parameters from the config file
config_file=param.cfg
include ${config_file}

# Variables that can be overwritten in param.cfg
# and will be taking this value only if are not defined
processes_per_node?=48
# If no queue has been specified it will use debug where possible
slurm_queue?=debug
# Tools folder
cfg=$(CURDIR)/cfg
analysis_tools=${cfg}/trace_analysis/
latex_folder=${cfg}/latex
trace_folder_prefix=$(CURDIR)/trace

# Check environment is loaded
####################################################
$(eval ssh_id := $(shell echo ${SSH_CONNECTION} | awk '{print $$2}'))
ifeq ("$(wildcard .$(ssh_id).env_loaded )","")
  $(error Please load the environment sourcing load_env.sh file)
endif
# Help
####################################################
help:
	@echo ""
	@echo "Recipes to prepare all the necessary elements to launch a performance analysis on NEMO (4.0, 4.0.1)"
	@echo ""
	@echo "Modify the file param.cfg to select the branch inside the nemo mirror that you would like to profile."
	@echo ""
	@echo 
###################################################
# Experiment recipes specified in param.cfg file
experiment:
	for recipe in ${experiment_recipes} ; do \
                echo $${recipe} ; \
                $(MAKE) $${recipe} slurm_queue=${slurm_queue}; \
        done

####################################################
# Recipes to prepare inidata
inidata:
	# Download data, put it in inidata and remove write permissions to avoid undesired modifications
	mkdir inidata
	./cfg/target/model/${model}/inidata
%/.inidata.done: inidata
	mkdir -p $(@D)
	# Link inidata
	ln -rsf inidata/* $(@D)
	rsync -rv --exclude=.nc inidata/ $(@D)
	touch $@

####################################################
# Model Sources
# The sources are prepared downloading the corresponding branch from the BSC Earth Sciences gitlab mirror
%_source:
	./cfg/target/model/${model}/$*_source
####################################################
# Recipe to compile different model versions
# The subscript indicates the version that we are compiling (vanilla, trace or gprof)

bin/${model}_%.exe: compilation_workdir 
	mkdir -p $(@D)
	./cfg/target/model/${model}/${model}_exec $* $@

%_workdir: ${model}_source
	mkdir -p $@
	rsync -av --exclude='doc*' --exclude='*.svn*' nemo_source/* $@
	# This sould also be astracted from the model
	cp cfg/arch/arch-* $@/arch/

####################################################
# Recipes to prepare functions file for tracing
# TODO: find a better way of prepare these rundirs without repeating code
functions_dir/extrae_functions.txt: bin/${model}_trace.exe bin/xios_server.exe
	${MAKE} $(@D)/.inidata.done

	python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/function.slurm \
                                     --set-time  120 \
                                     --set-core $(word 1, ${number_of_processes}) \
                                     --set-core-per-node ${processes_per_node} \
                                     --job-name $(@D) \
				     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/function.slurm \
                                            --set-workload ${cfg}/target/model/${model}/functions_dir

	sbatch --wait --chdir $(@D) $(@D)/function.slurm


#################### TRACE
TRACE_EXPERIMENTS=$(foreach var, $(number_of_processes), ${trace_folder_prefix}_$(var)/trace.slurm)
trace_experiments: $(TRACE_EXPERIMENTS)

# Recipe to make traces
${trace_folder_prefix}_%/trace.slurm: functions_dir/extrae_functions.txt bin/${model}_trace.exe
	mkdir -p $(@D)
	cp $< $(@D)
	${MAKE} $(@D)/.inidata.done

	# Copy jobscript and trace utils
	cp cfg/trace/* $(@D)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time  120 \
                                     --set-core $* \
                                     --set-core-per-node ${processes_per_node} \
                                     --job-name $(@D) \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name  $@ \
                                            --set-workload cfg/target/model/${model}/Trace $*
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
TRACE_CUT=$(foreach var, $(number_of_processes), ${trace_folder_prefix}_$(var)/${model}.best_cut.prv)
${trace_folder_prefix}_%/${model}.best_cut.prv: ${trace_folder_prefix}_%/trace.slurm | magiccut
	# Magic Cut
	cd $(@D); magicCut ${model}.prv

#################### PARAMEDIR
PARAMEDIR_EXPERIMENTS=$(foreach var, $(number_of_processes), ${trace_folder_prefix}_$(var)/paramedir.slurm)
paramedir_experiments: $(PARAMEDIR_EXPERIMENTS) $(TRACE_CUT)

paramedir_configurations=$(wildcard ${analysis_tools}/paramedir_configurations/*)
${trace_folder_prefix}_%/paramedir.slurm: ${trace_folder_prefix}_%/${model}.best_cut.prv
	 python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time-second  $$((10 * $*)) \
                                     --set-core 48 \
                                     --set-core-per-node ${processes_per_node} \
                                     --job-name paramedir_$* \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name  $@ \
                                            --set-workload ${cfg}/target/paramedir.target  ${analysis_tools} $(<F) $* ${paramedir_configurations}
        # Launch jobscript
	sbatch --wait --chdir $(@D) $@

${trace_folder_prefix}_%/report_add_paramedir: ${trace_folder_prefix}_%/paramedir.slurm
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "MPI Call Profile" --add-csv $(@D)/$*_MPIcallprofile.csv --csv-convert -p

REPORT_ADD_PARAMEDIR=$(foreach var, $(number_of_processes), ${trace_folder_prefix}_$(var)/report_add_paramedir)
report_add_paramedir: $(REPORT_ADD_PARAMEDIR)

####################### PARAVER
PARAVER_IMAGES=$(foreach var, $(number_of_processes), paraver_images/$(var))
paraver_images: $(PARAVER_IMAGES)

paraver_configurations=$(wildcard ${analysis_tools}/paraver_configurations/*)
paraver_images/%: ${trace_folder_prefix}_%/${model}.best_cut.prv .info_report.done
	# Make paraver images
	mkdir -p  $@
	${cfg}/target/paraver.target ${analysis_tools} $< $@ ${paraver_configurations}
	${cfg}/target/create_paraver_function_legend.target most_expensive_function_summary.csv $< $*
	${cfg}/target/create_paraver_legend.target $< $* ${paraver_configurations}

### Add paraver to the report
report_add_%_paraver: paraver_images/%
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Paraver" -s $*' Core' --add-img $<

REPORT_ADD_PARAVER=$(foreach var, $(number_of_processes), report_add_$(var)_paraver)
report_add_paraver: $(REPORT_ADD_PARAVER) 
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Paraver" -T cfg/latex/text/ParaverViews.txt

####################### DIMEMAS
dimemas_traces:
	mkdir $@

dimemas_configurations=$(wildcard ${analysis_tools}/dimemas_configurations/*)

DIMEMAS_TRC=$(foreach var, $(number_of_processes), dimemas_traces/$(var).dim)
dimemas_trc: $(DIMEMAS_TRC) $(TRACE_CUT)
dimemas_traces/%.dim: ${trace_folder_prefix}_%/${model}.best_cut.prv | dimemas_traces
	 python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/prv2dim.slurm \
                                     --set-time-seconds $$(( $* )) \
                                     --job-name $(@F) \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/prv2dim.slurm --set-workload ${analysis_tools}/prv2dim $< $(@F)
	sbatch --wait --chdir dimemas_traces $(@D)/prv2dim.slurm

DIMEMAS_EXPERIMENTS=$(foreach var, $(number_of_processes), dimemas_traces/dimemas_$(var).slurm)
dimemas_experiments: $(DIMEMAS_EXPERIMENTS) dimemas_trc
dimemas_traces/dimemas_%.slurm: dimemas_traces/%.dim
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time-seconds $$(( $* * 7 )) \
                                     --job-name dimemas_$* \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ --set-workload cfg/target/dimemas.target ${analysis_tools} $< ${dimemas_configurations}
	sbatch --wait --chdir dimemas_traces $@

### Process images
DIMEMAS_IMAGES=$(foreach var, $(number_of_processes), dimemas_images/.dimemas_images_$(var).done)
dimemas_images: $(DIMEMAS_IMAGES) $(DIMEMAS_EXPERIMENTS)
dimemas_images/.dimemas_images_%.done: dimemas_traces/dimemas_%.slurm
	mkdir -p $(@D)
	@${cfg}/target/dimemas_images.target ${analysis_tools} $* ${dimemas_configurations}
	touch $@

report_add_dimemas_images: $(DIMEMAS_IMAGES)
	for config in ${dimemas_configurations}; do \
		config_type=$${config##*/} ;\
		config_type=$${config_type%.*} ;\
		for cores in ${number_of_processes}; do \
			image_name=$${cores}_$${config_type}.png ;\
			python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Dimemas" -s $${config_type} --add-img dimemas_images/$${image_name} ;\
		done ;\
	done

report_add_dimemas: .info_report.done
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Dimemas" --add-csv dimemas.csv -T cfg/latex/text/Dimemas.txt
	$(MAKE) report_add_dimemas_images

####################### PARADIM
# Run the paramedir configurations with all the dimemas traces
PARADIM_EXPERIMENTS=$(foreach var, $(number_of_processes), dimemas_traces/paradim_$(var).slurm)
paradim_experiments: $(PARADIM_EXPERIMENTS) 

paradim_configurations=$(wildcard cfg/trace_analysis/paradim_configurations/*)

dimemas_traces/paradim_%.slurm: dimemas_traces/dimemas_%.slurm
	python cfg/slurm/SlurmJobCreator.py --file-name $@ \
                                     --set-time-seconds $$(( $* * 8 )) \
                                     --job-name paradim_$* \
                                     --set-queue $(slurm_queue)
	python cfg/slurm/SlurmJobCreator.py --file-name $@ --set-workload cfg/target/paradim.target ${analysis_tools} $* ${paradim_configurations}
	sbatch --wait --chdir dimemas_traces dimemas_traces/paradim_$*.slurm

###################### TEST
SCALABILITY=$(foreach var, $(number_of_processes), test_$(var)/test.slurm)
scalability: $(SCALABILITY)

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
	python cfg/slurm/SlurmJobCreator.py --file-name $@ --set-workload ${cfg}/target/model/${model}/test $*
	# Launch job
	sbatch --wait --chdir $(@D)  $@
####################################################

# Some other recipes

# Xios server
bin/xios_server.exe:
	mkdir -p $(@D)
	# TODO: HARDCODED dependency that at some point should be replaced with xios compilation
	cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe bin/xios_server.exe
# REBUILD NEMO tool
bin/rebuild_nemo.exe: compilation_workdir
	mkdir -p $(@D)
	cd reference_workdir/tools; ./maketools -n REBUILD_NEMO -m ${arch_file_prefix}
	cp reference_workdir/tools/REBUILD_NEMO/rebuild_nemo* bin/


####################################################
# Clean recipes
# Delete (almost)-everything
clean:
	rm -rf reference_workdir nemo_source nemo_mirror *.prv *.row *.pcf modelfactors* histogram_* trace_* functions_dir extrae_functions.txt *_workdir bin test_*
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
modelfactors: $(TRACE_CUT)
	mkdir $@
	cd $@  ;\
	${analysis_tools}/modelfactors $^ ;\
	rm -rf *hybrid*
report_add_modelfactors: modelfactors
	# Add produced pictures to latex report
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Model Factors" --add-img $^ -T cfg/latex/text/ModelFactors.txt

# Function histograms
histogram_%.txt: ${trace_folder_prefix}_%/${model}.best_cut.prv
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
	python cfg/parser/collector.py test_*/*.timing trace_*/*pm dimemas_traces/*dm -n ${configuration_name} -p param.cfg


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
	python ${latex_folder}/ReportGenerator.py -O report.pkl \
                                          -S "Scalability" \
                                          --add-img ${configuration_name}_scaling.png \
                                          --add-img-caption cfg/latex/captions/Scalability.txt\
                                          --add-csv ${configuration_name}_scaling.csv \
                                          -T cfg/latex/text/Scalability.txt

################ REPORT ADD FUNCTION INFO
functions=$(wildcard function_csv/* tracking/MPI/*)
report_add_function_detail: .info_report.done
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Functions detailed report" -T cfg/latex/text/Function.txt
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Functions detailed report" --add-csv most_expensive_function_summary.csv
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Functions detailed report" --add-img L3_vs_IPC.png
	for func in ${functions} ; do \
                file_name=$${func##function_csv/} ;\
                file_name=$${file_name##tracking/MPI/} ;\
                func_name=$${file_name%.csv} ;\
                echo $${func_name} ;\
                echo $${file_name} ;\
                python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Functions detailed report" -s  $${func_name} --add-csv  function_csv/$${file_name}  --silent;\
                python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Functions detailed report" -s  $${func_name} --add-csv  tracking/MPI/$${file_name} -p  --silent ;\
                python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Functions detailed report" -s  $${func_name} --add-csv  tracking/counters/$${file_name} -p --silent ;\
        done

##########################
MULTIEXPERIMENT_RUN=$(foreach experiment, $(multiexperiment),MultiExperimentRuns/$(experiment))
multiexperiments_run: $(MULTIEXPERIMENT_RUN)
#Run multi exp
MultiExperimentRuns/%:
	# The script contains a wait statement, so the target won't complete until the script finishes
	./MultiExperiment/MultiExperiment_launcher.cmd MultiExperiment/configurations/$* $@


MULTIEXP_CSV=$(foreach exp, $(multiexperiment), $(exp).csv)
multiexp_csv: $(MULTIEXP_CSV)
weakscaling.csv: MultiExperimentRuns/weakscaling
	python cfg/parser/comparator.py --json-files $</*/*.json -w --file-out $@

${model}_compilation_efficiency.csv: MultiExperimentRuns/${model}_compilation_efficiency
	python cfg/parser/comparator.py --json-files $</*/*.json -s --file-out $@
	touch $@

clean_multiexp_csv:
	for experiment in ${exp}; do rm -rf ${experiment}.csv; done
report_add_Multi_%: %.csv
	python cfg/latex/ReportGenerator.py -O report.pkl -S "Multi Experiment" -s $* --add-csv $*.csv

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
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Hardware Benchmarks" -s "STREAM Benchmark" --add-img  $< -T cfg/latex/text/STREAM.txt
### OSU
osu-micro-benchmarks-%:
	wget http://mvapich.cse.ohio-state.edu/download/mvapich/$@.tar.gz

	tar -xvf $@.tar.gz
	rm $@.tar.gz
	cd $@ ;\
	./configure CC=`which mpicxx` CXX=`which mpicc` --prefix=`pwd`;\
	make install;\
	make

OSU_RUN=$(foreach var, $(number_of_processes), OSU_RUN/$(var)/osu.slurm)
osu_run: $(OSU_RUN)

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
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Hardware Benchmarks" -s "OSU Benchmark" --add-img  $< -T cfg/latex/text/OSU.txt

HARDWARE_BENCHMARKS= STREAM_RUN/stream.slurm osu_run
hardware_benchmarks: $(HARDWARE_BENCHMARKS)

# Add benchmarks to report
report_add_benchmarks: report_add_osu report_add_stream
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Hardware Benchmarks" -T cfg/latex/text/HardwareBenchmarks.txt
################## REPORT
report: .latex_report.done
.latex_report.done: report_add_scalability report_add_modelfactors report_add_paraver report_add_dimemas report_add_function_detail report_add_benchmarks  report_add_Multi_${model}_compilation_efficiency
	# Stores the nemo commit tag to a variable
	$(eval $@_NEMO_VERSION := $(shell cd nemo_mirror; git log | grep 'git-svn-id:'| head -1 | awk '{print $$2}'| awk -F / '{print $$NF}' ))
	# Copy latex template to a new one which will be modified
	$(eval $@_LATEX_REPORT := $(shell echo report_$($@_NEMO_VERSION)))
	#python ${latex_folder}/ReportGenerator.py -O report.pkl --section-title "Introduction" --section-number 1 -T Introduction.txt
	python ${latex_folder}/ReportGenerator.py -O report.pkl --add-newcommand ${config_file}
	python ${latex_folder}/ReportGenerator.py -O report.pkl --report-title "Report Nemo version "${model}
	python ${latex_folder}/ReportGenerator.py -O report.pkl --report-authors "O. Tinto Primis"
	python ${latex_folder}/ReportGenerator.py -O report.pkl --report-authors "Stella V. Paronuzzi Ticco"
	# Remove old report folders
	rm -rf $($@_LATEX_REPORT)
	# Create a new one
	mkdir $($@_LATEX_REPORT)
	# Copy the report in the appropriate folder
	cp report.pkl $($@_LATEX_REPORT)/$($@_LATEX_REPORT).pkl
	# Create the tex file
	python ${latex_folder}/ReportGenerator.py -O ./$($@_LATEX_REPORT)/$($@_LATEX_REPORT).pkl --dump-to-file
	# Compile the report
	cd $($@_LATEX_REPORT); module load LATEX/20150523; pdflatex $($@_LATEX_REPORT).tex && pdflatex $($@_LATEX_REPORT).tex && evince $($@_LATEX_REPORT).pdf

	# Generate the target
	touch $@

############### TARGET FOR PARALLEL MAKE
REPORT_DEPENDENCIES = scalability trace_experiments paraver_images dimemas_experiments paramedir_experiments paradim_experiments hardware_benchmarks multiexperiments_run

report_dependencies: $(REPORT_DEPENDENCIES)

paraver_images: trace_experiments
dimemas_experiments: trace_experiments
paradim_experiments: dimemas_experiments


REPORT_PREPROC = .info_report.done modelfactors paraver_images dimemas_images OSU_RUN/IMAGE STREAM_RUN/STREAM_${model}.png multiexp_csv
report_preproc: $(REPORT_PREPROC)

clean_report_preproc: clean_info_report clean_modelfactors clean_paraver_images clean_dimemas_images clean_OSU_RUN_IMAGE clean_STREAM_${model}.png clean_multiexp_csv
# Intermediate files that won't be removed automatically
binaries= bin/nemo_trace.exe bin/nemo_vanilla.exe
.PRECIOUS: $(binaries)  %.dim nemo_source *.env_loaded

.DELETE_ON_ERROR: $(PARAMEDIR_EXPERIMENTS) $(DIMEMAS_EXPERIMENTS) $(PARADIM_EXPERIMENTS)
