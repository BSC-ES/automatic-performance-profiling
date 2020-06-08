SHELL := /bin/bash
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
latex_folder_img=cfg/latex/images
trace_folder_prefix=trace
# Help
####################################################
help:
	@echo ""
	@echo "Recipes to prepare all the necessary elements to launch a performance analysis on NEMO (4.0, 4.0.1)"
	@echo ""
	@echo "Modify the file param.cfg to select the branch inside the nemo mirror that you would like to profile."
	@echo ""
	@echo 

####################################################
# NEMO Sources
# The sources are prepared downloading the corresponding branch from the BSC Earth Sciences gitlab mirror

nemo_source: nemo_mirror
	# Download NEMO sources from svn repository
	ln -sf $< $@

# Download the sources from the Earth Sciences gitlab mirror using mcastrill script
nemo_mirror:
	cfg/clone_nemo.sh nemo_mirror $(nemo_branch)

####################################################
# Recipe to compile different NEMO versions
# The subscript indicates the version that we are compiling (vanilla, trace or gprof)
bin/nemo_%.exe: compilation_workdir | bin
	# Compile NEMO
	compilation_workdir/makenemo -m ${arch_file_prefix}_$* -n ${configuration_name}_$* ${configuration_details} -j 16
	# Copy binary into bin folder
	cp compilation_workdir/${configuration_folder}/${configuration_name}_$*/EXP00/nemo $@
	
ifdef configuration_resolution
	cp compilation_workdir/${configuration_folder}/${configuration_name}_$*/EXP00/namelist_cfg_${configuration_resolution}_like  compilation_workdir/${configuration_folder}/${configuration_name}_$*/EXP00/namelist_cfg
endif

####################################################
# Recipes to prepare functions file for tracing
# TODO: find a better way of prepare these rundirs without repeating code
functions_dir: inidata bin/nemo_trace.exe bin/xios_server.exe
	mkdir $@
	# Link inidata
	ln -rsf inidata/* $@
	rsync -rv --exclude=.nc inidata/ $@
	# Copy everything from reference folder
	cp --remove-destination compilation_workdir/${configuration_folder}/${configuration_name}_trace/EXP00/* $@
	# Copy xios server
	cp --remove-destination bin/xios_server.exe $@
	# Fix namelist parameters
	cfg/replace_namelist_parameter $@/namelist_cfg nn_itend 400
	cfg/replace_namelist_parameter $@/namelist_cfg ln_icebergs .false.
	cfg/replace_namelist_parameter $@/namelist_ref ln_meshmask .false.
	# Copy jobscript
	cp cfg/generate_func_list/* $@  
        
	# Disable output
	if [ $(output) == FALSE ] ; then \
	   sed -i "s/^.*file_definition.*$$//g" $@/context_nemo.xml ; \
	fi
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
.Trace_%.done: extrae_functions.txt bin/nemo_trace.exe
	# Variable which contains traces' folder name
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))
	# Create folder
	mkdir $($@_trace_folder)
	# Link inidata
	ln -rsf inidata/* $($@_trace_folder) 
	rsync -rv --exclude=.nc inidata/ $($@_trace_folder)
	# Copy everything from reference folder
	cp --remove-destination compilation_workdir/${configuration_folder}/${configuration_name}_trace/EXP00/* $($@_trace_folder)
	# Copy xios server
	cp --remove-destination bin/xios_server.exe $($@_trace_folder)
	# Fix namelist parameters
	cfg/replace_namelist_parameter $($@_trace_folder)/namelist_cfg nn_itend ${trace_steps}
	cfg/replace_namelist_parameter $($@_trace_folder)/namelist_cfg ln_icebergs .false.
	cfg/replace_namelist_parameter $($@_trace_folder)/namelist_ref ln_meshmask .false.
	# Set ice frequency to 1
	cfg/replace_namelist_parameter $($@_trace_folder)/namelist_ref nn_fsbc 1
	# Disable output
	if [ $(output) == FALSE ] ; then \
	   sed -i "s/^.*file_definition.*$$//g" $($@_trace_folder)/context_nemo.xml ; \
	fi
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


paramedir_configurations=$(wildcard cfg/trace_analysis/paramedir_configurations/*)

paramedir_test_%: 	
	$(eval $@_folder := $(shell echo ${trace_folder_prefix}_$*))
	@echo $($@_folder)

.paramedir_%.done: .Trace_%.done

	# Variable which contains traces' folder name
	$(eval $@_trace_folder := $(shell echo ${trace_folder_prefix}_$*))

	# Make paraver image
	cd $($@_trace_folder); ../${analysis_tools}/paraver -i $($@_trace_folder).prv ../${analysis_tools}/cfgs/UserFunctions.cfg
	# Name of generated trace picture
	$(eval $@_picture := $(shell echo $($@_trace_folder)/NEMO_function_x_thread@trace_$*.png))
	# Copy it to latex image folder
	cp $($@_picture) ${latex_folder_img}/trace_userFunctions_$*.png
	# Enter directory and process all paramedir configurations
	cd $($@_trace_folder); \
	for cfg in ${paramedir_configurations} ; do \
	        ../${analysis_tools}/paramedir $($@_trace_folder).prv ../$${cfg} ;\
	done
	touch $@


%.dim: .trace_%.done
	${analysis_tools}/prv2dim $<.prv $@


dimemas_configurations=$(wildcard cfg/dimemas/cfgs/*)
.dimemas_experiment_%.done: %.dim
	mkdir -p dimemas_traces
	for cfg in ${dimemas_configurations} ; do \
	        sufix=$$(basename $${cfg}) ; \
	        sufix=$${sufix//dimemas./} ;\
	        sufix=$${sufix//.cfg/} ;\
		${analysis_tools}/Dimemas -S 32k --dim $< -p dimemas_traces/dimemas_$*_$${sufix}.prv --config-file $${cfg} ;\
	done
	touch $@
####################################################
# Recipes to prepare inidata
inidata:
	# Download data, put it in inidata and remove write permissions to avoid undesired modifications
	mkdir inidata
ifdef configuration_resolution
        # It is BENCH, copy the namelist into the configuration namelist_cfg
	cp cfg/utils/iodef.xml  inidata
	cp cfg/utils/context_nemo.xml  inidata
else
	wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar
	tar -xf ORCA2_ICE_v4.0.tar -C inidata
	gunzip inidata/*
	# Remove write permissions to avoid unwilingly manipulate the input files
	chmod -w inidata 
	# Remove compressed file
	rm ORCA2_ICE_v4.0.tar
endif
####################################################
# Recipes to launch some basic tests
test_%: inidata bin/nemo_vanilla.exe bin/xios_server.exe
	mkdir $@
	# Link inidata
	ln -rsf inidata/*  $@
	rsync -rv --exclude=.nc inidata/ $@
	# Copy everything from reference folder
	cp --remove-destination compilation_workdir/${configuration_folder}/${configuration_name}_vanilla/EXP00/* $@
	# Copy xios server
	cp --remove-destination bin/xios_server.exe $@
	# Change namelist parameters
	cfg/replace_namelist_parameter $@/namelist_cfg nn_itend ${test_steps}
	cfg/replace_namelist_parameter $@/namelist_cfg ln_icebergs .false.
	cfg/replace_namelist_parameter $@/namelist_ref ln_meshmask .false.
	cfg/replace_namelist_parameter $@/namelist_ref ln_timing   .true.
	cfg/replace_namelist_parameter $@/namelist_cfg ln_timing   .true.
	# Disable output
	if [ $(output) == FALSE ] ; then \
	   sed -i "s/^.*file_definition.*$$//g" $@/context_nemo.xml ; \
	fi
	cp cfg/test/jobscript.cmd $@
	# Replace number of cores in the jobscript
	sed -i "s/%CORES%/$*/g" $@/jobscript.cmd
	sed -i "s/%PROCESSES_PER_NODE%/${processes_per_node}/g" $@/jobscript.cmd
	# Launch job
	sbatch --wait --chdir $@ $@/jobscript.cmd

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

%_workdir: nemo_source
	mkdir -p $@
	rsync -av --exclude='doc*' --exclude='*.svn*' nemo_source/* $@
	cp cfg/arch/arch-* $@/arch/

####################################################
# Clean recipes
# Delete (almost)-everything
clean:
	rm -rf reference_workdir nemo_source *.prv *.row *.pcf modelfactors* histogram_* trace_* functions_dir extrae_functions.txt *_workdir bin test_*

hard_clean:
	-chmod +w inidata
	-chmod +w InitialConditions.nc
	rm -rf inidata InitialConditions.nc 


####################################################
# Trace Analysis

# Model factors
modelfactors_dependencies=$(foreach var, $(number_of_processes), .trace_cut_$(var).done)
modelfactors_traces=$(foreach var, $(number_of_processes), trace_$(var)/trace_$(var).prv)

modelfactors: $(modelfactors_dependencies)
	${analysis_tools}/modelfactors $(modelfactors_traces)
	sed -i '2s/^/set terminal png\n/' modelfactors.gp
	sed -i '3s/^/set output "modelfactors.png"\n/' modelfactors.gp
	sed -i 's/dt 2//g' modelfactors.gp
	sed -i 's/pause -1//g' modelfactors.gp
	gnuplot -p modelfactors.gp
	cp ./modelfactors.csv ${latex_folder}
	cp ./modelfactors.png ${latex_folder_img}
# Function histograms
histogram_%.txt: .Trace_%.done
	${analysis_tools}/paramedir $<.prv ${analysis_tools}/cfgs/FunctionTimeHistogram.cfg 
	mv FunctionTimeHistogram histogram_$*.txt

histograms_dependencies=$(foreach var, $(number_of_processes), histogram_$(var).txt)
histograms: $(histogram_dependencies)

scalability_dependencies=$(foreach var, $(number_of_processes), test_$(var))
scalability: $(scalability_dependencies)
	@echo "Scalability tests done"
	python cfg/parser/launcher.py test_*/timing.output  -n ${configuration_name} -s  > scalability_report.txt
	cat scalability_report.txt
dimemas_dependencies=$(foreach var, $(number_of_processes), .dimemas_experiment_$(var).done)
dimemas_experiments: $(dimemas_dependencies)
analysis: histograms modelfactors scalability	

paramedir_dependencies=$(foreach var, $(number_of_processes), .paramedir_$(var).done)
paramedir_experiment: $(paramedir_dependencies)
############
# Create a latex report
report: cfg/latex/report.pdf
cfg/latex/report.pdf: modelfactors paramedir_experiment
	$(eval $@_NEMO_VERSION := $(shell cd nemo_mirror; git log | head -10 | grep 'git-svn-id:' | awk '{print $$2}'| awk -F / '{print $$NF}' ))
	cp ${latex_folder}/variables_orig.tex ${latex_folder}/variables.tex
	sed -i 's/NEMO_VERSION/$($@_NEMO_VERSION)/g' ${latex_folder}/variables.tex
	cd ${latex_folder}; ./gen_report.sh
############         #
# Intermediate files #that won't be removed automatically
binaries= bin/nemo_trace.exe bin/nemo_vanilla.exe
.PRECIOUS: $(binaries) $(dimemas_dependencies) %.dim *.done
