# Makefile to prepare all the necessary elements to launch a performance analysis on NEMO

# Reading some parameters from the config file
config_file=param.cfg
include ${config_file}

# Variables that can be overwritten in param.cfg
# and will be taking this value only if are not defined
test_steps?=1200
trace_steps?=40
processes_per_node?=48



# Tools folder
analysis_tools=cfg/trace_analysis/
latex_folder=cfg/latex
trace_folder_prefix=trace

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
                $(MAKE) $${recipe} ; \
        done

####################################################
# Recipes to prepare inidata
inidata:
	# Download data, put it in inidata and remove write permissions to avoid undesired modifications
	mkdir inidata
	./cfg/target/inidata
####################################################
# Model Sources
# The sources are prepared downloading the corresponding branch from the BSC Earth Sciences gitlab mirror
%_source:
	./cfg/target/$*_source
####################################################
# Recipe to compile different model versions
# The subscript indicates the version that we are compiling (vanilla, trace or gprof)

bin/${model}_%.exe: compilation_workdir | bin
	./cfg/target/${model}_exec $* $@

%_workdir: ${model}_source
	mkdir -p $@
	rsync -av --exclude='doc*' --exclude='*.svn*' nemo_source/* $@
	# This sould also be astracted from the model
	cp cfg/arch/arch-* $@/arch/

####################################################
# Recipes to prepare functions file for tracing
# TODO: find a better way of prepare these rundirs without repeating code
functions_dir: inidata bin/${model}_trace.exe bin/xios_server.exe
	mkdir $@
	# Link inidata
	ln -rsf inidata/* $@
	rsync -rv --exclude=.nc inidata/ $@

	# model specific directives
	./cfg/target/functions_dir $@

	# Replace number of cores in the jobscript
	sed -i "s/%CORES%/$(word 1, ${number_of_processes} )/g" $@/jobscript.cmd
	sed -i "s/%PROCESSES_PER_NODE%/${processes_per_node}/g" $@/jobscript.cmd

	sbatch --wait --chdir $@ $@/jobscript.cmd
	# Clean unnecessary netcdf
	rm -rf $@/*nc 

# Recip for preparing the function lists
extrae_functions.txt: functions_dir
	# Copy functions list
	cp $</extrae_functions.txt $@

# Recipe to make traces
.Trace_%.done: extrae_functions.txt bin/${model}_trace.exe
	# Variable which contains traces' folder name
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))
	# Create folder
	mkdir $($@_trace_folder)
	# Link inidata
	ln -rsf inidata/* $($@_trace_folder) 
	rsync -rv --exclude=.nc inidata/ $($@_trace_folder)

	# Model specific directives
	./cfg/target/Trace $($@_trace_folder)

	# Copy jobscript and trace utils
	cp cfg/trace/* $($@_trace_folder)
	# Copy function list to trace.
	cp $< $($@_trace_folder)/extrae_functions.txt
	# Replace number of cores in the jobscript
	sed -i "s/%CORES%/$*/g" $($@_trace_folder)/jobscript.cmd
	sed -i "s/%PROCESSES_PER_NODE%/${processes_per_node}/g" $($@_trace_folder)/jobscript.cmd
	# Launch jobscript
	sbatch --wait --chdir $($@_trace_folder) $($@_trace_folder)/jobscript.cmd
	# Clean a little bit
	rm -rf $($@_trace_folder)/set-* $($@_trace_folder)/*.nc
	touch $@

# Cut the trace
.trace_cut_%.done: .Trace_%.done
	# Variable which contains traces' folder name
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))
	# Magic Cut
	cd $($@_trace_folder); magicCut nemo.prv
	rename nemo.best_cut $($@_trace_folder)  $($@_trace_folder)/nemo.best_cut.*
	touch $@ 

#################### PARAMEDIR
paramedir_configurations=$(wildcard ${analysis_tools}/paramedir_configurations/*)
.paramedir_%.done: .trace_cut_%.done
	# Variable which contains traces' folder name
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))
	# Remove eventual old results
	rm -f $($@_trace_folder)/*.pm
	# Enter directory and process all paramedir configurations
	cd $($@_trace_folder); \
	for cfg in ${paramedir_configurations} ; do \
	        ../${analysis_tools}/paramedir $($@_trace_folder).prv ../$${cfg} ;\
	done
	# Rename files
	cd $($@_trace_folder); for file in *pm ; do \
	   mv $${file} $*_$${file} ;\
	done
	touch $@


report_add_%_paramedir: .paramedir_%.done
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "MPI Call Profile" --add-csv $($@_trace_folder)/$*_MPIcallprofile.pm -c

report_add_paramedir_dep=$(foreach var, $(number_of_processes), report_add_$(var)_paramedir)
report_add_paramedir: $(report_add_paramedir_dep)

####################### PARAVER
paraver_dependencies=$(foreach var, $(number_of_processes), .paraver_$(var).done)
paraver_experiment: $(paraver_dependencies)

paraver_configurations=$(wildcard cfg/trace_analysis/paraver_configurations/*)
.paraver_%.done: .trace_cut_%.done
	# Variable which contains traces' folder name
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))
	# Make paraver images
	mkdir -p paraver_img
	cd $($@_trace_folder); \
	for cfg in ${paraver_configurations} ; do \
		../${analysis_tools}/paraver -i $($@_trace_folder).prv ../$${cfg} ;\
		cfg_name=$${cfg##*/} ;\
		picture_name=$${cfg_name%.cfg} ;\
		rm -f *.code.png ;\
		rm -f *nn_gradient.png ;\
		rm -f *w_legend* ;\
		mv $${picture_name}* $${picture_name}_trace_$*.png ;\
	done
	touch $@

report_add_%_paraver: $(paraver_dependencies)
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Paraver" -s $*' Core' --add-img $($@_trace_folder)
report_add_paraver_dep=$(foreach var, $(number_of_processes), report_add_$(var)_paraver)
report_add_paraver: $(report_add_paraver_dep)

####################### DIMEMAS
dimemas_dependencies=$(foreach var, $(number_of_processes), .dimemas_experiment_$(var).done)
dimemas_experiments: $(dimemas_dependencies)

dimemas_configurations=$(wildcard cfg/dimemas/cfgs/*)
%.dim: .trace_cut_%.done
	echo "${analysis_tools}/prv2dim trace_$*/trace_$*.prv $@"
	${analysis_tools}/prv2dim trace_$*/trace_$*.prv $@


.dimemas_experiment_%.done: %.dim
	mkdir -p dimemas_traces
	for cfg in ${dimemas_configurations} ; do \
	        sufix=$$(basename $${cfg}) ; \
	        sufix=$${sufix//dimemas./} ;\
	        sufix=$${sufix//.cfg/} ;\
		${analysis_tools}/Dimemas -S 32k --dim $< -p dimemas_traces/$*_$${sufix}.prv --config-file $${cfg} ;\
	done
	touch $@	
####################### PARADIM
# Using paramedir configurations with dimemas outputs
paramedir_dependencies=$(foreach var, $(number_of_processes), .paramedir_$(var).done)
paramedir_experiment: $(paramedir_dependencies)

paradim_configurations=$(wildcard cfg/trace_analysis/paradim_configurations/*)
.paradim_%.done: .dimemas_experiment_%.done
	# Run the paramedir configurations stored in paradim_configurations with all the dimemas traces
	cd dimemas_traces; \
	dimemas_traces=$$( ls $**.prv ) ;\
	for trace in $${dimemas_traces}; do \
	   for cfg in ${paradim_configurations} ; do \
	           ../${analysis_tools}/paramedir $${trace} ../$${cfg} ;\
	           output_name=$$(basename $${cfg/.cfg/} ) ;\
	           new_name=$${trace/.prv/}_$${output_name} ;\
	           mv $${output_name} $${new_name} ;\
	   done ;\
	done
	touch $@

paradim_dependencies=$(foreach var, $(number_of_processes), .paradim_$(var).done)
.paradim_experiment.done: $(paradim_dependencies)
	touch $@
paradim_experiment: .paradim_experiment.done
####################################################
# Recipes to launch some basic tests
test_%: inidata bin/${model}_vanilla.exe bin/xios_server.exe
	mkdir $@
	# Link inidata
	ln -rsf inidata/*  $@
	rsync -rv --exclude=.nc inidata/ $@

	# Moldel specific instruction
	./cfg/target/test $@

	cp cfg/test/jobscript.cmd $@
	# Replace number of cores in the jobscript
	sed -i "s/%CORES%/$*/g" $@/jobscript.cmd
	sed -i "s/%PROCESSES_PER_NODE%/${processes_per_node}/g" $@/jobscript.cmd
	# Launch job
	sbatch --wait --chdir $@ $@/jobscript.cmd
	# Rename timing output
	mv $@/timing.output $@/$*_test.timing
####################################################
# Some other recipes

# Xios server
bin/xios_server.exe:
	# TODO: HARDCODED dependency that at some point should be replaced with xios compilation
	cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe bin/xios_server.exe
# REBUILD NEMO tool
bin/rebuild_nemo.exe: bin compilation_workdir
	cd reference_workdir/tools; ./maketools -n REBUILD_NEMO -m ${arch_file_prefix}
	cp reference_workdir/tools/REBUILD_NEMO/rebuild_nemo* bin/

# Binary folder
bin:
	mkdir -p bin


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
hard_clean:
	-chmod +w inidata
	-chmod +w InitialConditions.nc
	rm -rf inidata InitialConditions.nc 


####################################################
# Trace Analysis

# Model factors
modelfactors_dependencies=$(foreach var, $(number_of_processes), .trace_cut_$(var).done)
modelfactors_traces=$(foreach var, $(number_of_processes), ../trace_$(var)/trace_$(var).prv)

modelfactors: .modelfactors.done

.modelfactors.done: ${modelfactors_dependencies}
	mkdir modelfactors
	cd modelfactors  ;\
	../${analysis_tools}/modelfactors $(modelfactors_traces) ;\
	rm *hybrid*
	touch $@

report_add_modelfactors: .modelfactors.done
	# Add produced pictures to latex report
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Model Factors" --add-img  modelfactors 

# Function histograms
histogram_%.txt: .Trace_%.done
	${analysis_tools}/paramedir $<.prv ${analysis_tools}/cfgs/FunctionTimeHistogram.cfg 
	mv FunctionTimeHistogram histogram_$*.txt

histograms_dependencies=$(foreach var, $(number_of_processes), histogram_$(var).txt)
histograms: $(histogram_dependencies)

analysis: histograms modelfactors scalability	

# Collect information and produce a json file with it.
.json.done: .scalability.done paramedir_experiment paradim_experiment
	$(MAKE) process_json
	touch $@
json: .json.done

process_json: ${configuration_name}.json
${configuration_name}.json:
	python cfg/parser/collector.py test_*/*.timing trace_*/*pm dimemas_traces/*dm -n ${configuration_name} -p param.cfg

################ SCALALBILITY
scalability_dependencies=$(foreach var, $(number_of_processes), test_$(var))
scalability: .scalability.done
.scalability.done: $(scalability_dependencies)
	touch $@

############### INFO
.info_report.done: .json.done
	python cfg/parser/reporter.py \
                                    ${configuration_name}.json \
                                    -f function_csv \
                                    --sypd sypd.txt \
                                    --sypd-plot ${configuration_name}.png \
                                    --functions functions_summary.txt \
    	                            --tracking tracking \
		                 		    --dimemas dimemas.csv
	touch $@

functions=$(wildcard function_csv/* tracking/MPI/*)
report_add_function_detail: .info_report.done
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

report_add_scalability: .info_report.done
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Scalability" --add-img ${configuration_name}.png

report_add_dimemas: .info_report.done
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Dimemas" --add-csv dimemas.csv
##########################
#Run multi exp
.MultiExperiment_%.done:
	# The script contains a wait statement, so the target won't complete until the script finishes
	./MultiExperiment/MultiExperiment_launcher.cmd MultiExperiment/configurations/$*
	touch $@

MultiExperiment_%: .MultiExperiment_%.done
	@echo $@ "done"

.%_postproc.done: .MultiExperiment_%.done
	python cfg/parser/comparator.py $*/*/*.json -s -O report.pkl -subsection-title $*
	touch $@

%_postproc: .%_postproc.done
	@echo $@ "done"

#################### BENCHMARKS
.stream_ready: | bin
	git clone https://github.com/jeffhammond/STREAM.git
	cd STREAM; gcc -fopenmp -D_OPENMP stream.c -o stream 
	mkdir bin/STREAM
	cp STREAM/stream bin/STREAM/
	touch $@
.stream_run.done: .stream_ready
	mkdir -p STREAM_RUN/
	mkdir -p STREAM_RUN/DATA
	cp bin/STREAM/* STREAM_RUN/
	cp cfg/benchmarks/STREAM/jobscript.cmd STREAM_RUN/
	sed -i "s/%CORES%/1/g" STREAM_RUN/jobscript.cmd ;\
	sed -i "s/%PROCESSES_PER_NODE%/${processes_per_node}/g" STREAM_RUN/jobscript.cmd ;\
	sbatch  --wait --chdir STREAM_RUN STREAM_RUN/jobscript.cmd ;\
	cp STREAM_RUN/*.txt STREAM_RUN/DATA ;\

	touch $@

.stream_harvest.done: .stream_run.done
	for file_in in STREAM_RUN/DATA/*.txt ; do \
		file_out=$${file_in%.txt}.csv ;\
		python cfg/benchmarks/STREAM/STREAM_data_parser.py -i $${file_in} -o $${file_out} ;\
	done
	touch $@

# Add stream data to the report
report_add_stream: .stream_harvest.done
	$(eval $@_STRAM_DATA := $(shell ls STREAM_RUN/DATA/*.csv | sort -n ))
	for data in  $($@_STRAM_DATA) ; do \
	  python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Hardware Benchmarks" -s "STREAM Benchmark" --add-csv $${data};\
	done
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Hardware Benchmarks" -s "STREAM Benchmark" -T cfg/latex/text/STREAM.txt

.osu_ready: | bin
	wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.3.tar.gz

	osu_folder=osu-micro-benchmarks-5.6.3 ;\
	tar -xvf $${osu_folder}.tar.gz ;\
	rm $${osu_folder}.tar.gz ;\
	cd $${osu_folder} ;\
	./configure CC=`which mpicxx` CXX=`which mpicc` --prefix=`pwd`;\
	make install;\
	make
	# Instrallation finished
	mkdir bin/osu_bench
	for test in ${osu_tests}; do \
	cp ./osu-micro-benchmarks-5.6.3/mpi/$${test} bin/osu_bench ;\
	done
	touch $@

osu_test=$(wildcard bin/osu_bench/*)
.osu_run_%.done: .osu_ready
	mkdir -p OSU_RUN/$*
	mkdir -p OSU_RUN/DATA
	for test in ${osu_test} ; do \
		test_name=$${test##bin/osu_bench/} ;\
		cp $${test} OSU_RUN/$* ;\
		cp cfg/benchmarks/OSU/jobscript.cmd OSU_RUN/$*/$${test_name}_jobscript.cmd ;\
		sed -i "s/%CORES%/$*/g" OSU_RUN/$*/$${test_name}_jobscript.cmd ;\
		sed -i "s/%PROCESSES_PER_NODE%/${processes_per_node}/g" OSU_RUN/$*/$${test_name}_jobscript.cmd ;\
		sed -i "s/%TEST%/$${test_name}/g" OSU_RUN/$*/$${test_name}_jobscript.cmd ;\
		sbatch --wait --chdir OSU_RUN/$* OSU_RUN/$*/$${test_name}_jobscript.cmd ;\
		cp OSU_RUN/$*/*txt OSU_RUN/DATA ;\
	done
	touch $@

osu_harvest_dep=$(foreach var, $(number_of_processes), .osu_run_$(var).done)

.osu_harvest.done: $(osu_harvest_dep)
	for test in ${osu_test} ; do \
		test_name=$${test##bin/osu_bench/} ;\
		python cfg/benchmarks/OSU/OSU_test_plots.py -i OSU_RUN/DATA/$${test_name}* -o OSU_RUN/IMAGE;\
	done
	touch $@

# Add results to report
report_add_osu: .osu_harvest.done
	python ${latex_folder}/ReportGenerator.py -O report.pkl -S "Hardware Benchmarks" -s "OSU Benchmark" --add-img  OSU_RUN/IMAGE -T cfg/latex/text/OSU.txt


hardware_benchmarks: .stream_harvest.done .osu_harvest.done

# Add benchmarks to report
report_add_benchmarks: report_add_osu report_add_stream

################## REPORT
report: .latex_report.done
.latex_report.done: report_add_scalability report_add_modelfactors report_add_paraver report_add_dimemas report_add_function_detail report_add_benchmarks report_add_paramedir
	# Stores the nemo commit tag to a variable
	$(eval $@_NEMO_VERSION := $(shell cd nemo_mirror; git log | grep 'git-svn-id:'| head -1 | awk '{print $$2}'| awk -F / '{print $$NF}' ))
	# Copy latex template to a new one which will be modified
	$(eval $@_LATEX_REPORT := $(shell echo report_$($@_NEMO_VERSION)))
	#python ${latex_folder}/ReportGenerator.py -O report.pkl --section-title "Introduction" --section-number 1 -T Introduction.txt
	python ${latex_folder}/ReportGenerator.py -O report.pkl --report-title "Report Nemo version "$($@_NEMO_VERSION)
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
	cd $($@_LATEX_REPORT); module load LATEX/20150523; pdflatex $($@_LATEX_REPORT).tex && evince $($@_LATEX_REPORT).pdf

	# Generate the target
	touch $@

# Intermediate files #that won't be removed automatically
binaries= bin/nemo_trace.exe bin/nemo_vanilla.exe
.PRECIOUS: $(binaries) $(dimemas_dependencies) %.dim .Trace_%.done .multiexperiment_%.done
