# Makefile to prepare all the necessary elements to launch a performance analysis on NEMO

# Reading some parameters from the config file
config_file=param.cfg
nemo_branch=$(shell grep "nemo_branch"  ${config_file} )
$(eval ${nemo_branch})
configuration_name=$(shell grep "configuration_name"  ${config_file} )
$(eval ${configuration_name})
configuration_details=$(shell grep "configuration_details"  ${config_file} )
$(eval ${configuration_details})

# If we want to add some user defined parameter we can do it with the following approach:
# We add in the config file something like:
#
#    var_name=var_value
#
# and then add in this Makefile two lines like:
#
#    var_name=$(shell grep "var_name"  ${config_file} )
#    $(eval ${var_name})
#

# Help
####################################################
help:
	@echo ""
	@echo "Recipes to prepare all the necessary elements to launch a performance analysis on NEMO (4.0, 4.0.1)"
	@echo ""
	@echo "Modify the file param.cfg to select the branch inside the nemo mirror that you would like to profile."
	@echo ""

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
# Recipes to compile different NEMO versions
# Vanilla versions
bin/nemo.exe: bin compilation_workdir
	# Compile NEMO
	compilation_workdir/makenemo -m mn4 -n ${configuration_name} ${configuration_details} -j 16
	# Copy binary into bin folder
	cp compilation_workdir/cfgs/${configuration_name}/EXP00/nemo $@
	
# Tracing versions
bin/nemo_trace.exe: bin compilation_workdir
	# Compile NEMO
	compilation_workdir/makenemo -m mn4_trace -n ${configuration_name}_trace ${configuration_details} -j 16
	# Copy binary into bin folder
	cp compilation_workdir/cfgs/${configuration_name}_trace/EXP00/nemo $@
	
# Gprof versions to find which functions do we want to trace
bin/nemo_gprof.exe: bin compilation_workdir
	# Compile NEMO
	compilation_workdir/makenemo -m mn4_gprof -n ${configuration_name}_gprof ${configuration_details} -j 16
	# Copy binary into bin folder
	cp compilation_workdir/cfgs/${configuration_name}_gprof/EXP00/nemo $@

####################################################
# Recipes to prepare functions file for tracing

# TODO: find a better way of prepare these rundirs without repeating code
functions_dir: inidata bin/nemo_gprof.exe bin/xios_server.exe
	mkdir $@
	# Link inidata
	ln -rsf inidata/* $@
	# Copy everything from reference folder
	cp --remove-destination compilation_workdir/cfgs/${configuration_name}_gprof/EXP00/* $@
	# Copy xios server
	cp --remove-destination bin/xios_server.exe $@
	# Fix namelist parameters
	cfg/replace_namelist_parameter $@/namelist_cfg nn_itend 480
	cfg/replace_namelist_parameter $@/namelist_cfg ln_icebergs .false.
	cfg/replace_namelist_parameter $@/namelist_ref ln_meshmask .false.
	# Copy jobscript
	cp cfg/gprof/jobscript.cmd $@
	cp cfg/gprof/gthrottling.sh $@
	sbatch --wait --chdir $@ $@/jobscript.cmd
	# Clean unnecessary netcdf
	rm -rf $@/*nc 

# Recipe for preparing the function lists
# TODO: Maybe we can generate this list only once with the configuration using ICE.
extrae_functions.txt: functions_dir
	# Copy functions list
	cp $</extrae_functions.txt $@

# Recipe to make traces
trace_%: extrae_functions.txt bin/nemo_trace.exe 
	# Create folder
	mkdir $@
	# Link inidata
	ln -rsf inidata/* $@
	# Copy everything from reference folder
	cp --remove-destination compilation_workdir/cfgs/${configuration_name}_trace/EXP00/* $@
	# Copy xios server
	cp --remove-destination bin/xios_server.exe $@
	# Fix namelist parameters
	cfg/replace_namelist_parameter $@/namelist_cfg nn_itend 20
	cfg/replace_namelist_parameter $@/namelist_cfg ln_icebergs .false.
	cfg/replace_namelist_parameter $@/namelist_ref ln_meshmask .false.
	# Set ice frequency to 1
	cfg/replace_namelist_parameter $@/namelist_ref nn_fsbc 1
	# Copy jobscript and trace utils
	cp cfg/trace/* $@
	# Copy function list to trace.
	cp $< $@/extrae_functions.txt

	# Replace number of cores in the jobscript
	sed -i "s/%CORES%/$*/g" $@/jobscript.cmd
	# Launch jobscript
	sbatch --wait --chdir $@ $@/jobscript.cmd
	# Clean a little bit
	rm -rf $@/set-* $@/*.nc
	# Magic Cut
	cd $@; magicCut nemo.prv
	mv $@/nemo.best_cut.* .
	rename nemo.best_cut trace_$* nemo.best_cut.*


####################################################
# Recipes to prepare inidata
inidata:
	# Download data, put it in inidata and remove write permissions to avoid undesired modifications
	mkdir inidata
	wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar
	tar -xf ORCA2_ICE_v4.0.tar -C inidata
	gunzip inidata/*
	# Remove write permissions to avoid unwilingly manipulate the input files
	chmod -w inidata 
	# Remove compressed file
	rm ORCA2_ICE_v4.0.tar

####################################################
# Recipes to launch some basic tests
test: inidata
	mkdir $@
	# Link inidata
	ln -rsf inidata/* $@
	# Copy everything from reference folder
	cp --remove-destination compilation_workdir/cfgs/${configuration_name}/EXP00/* $@
	# Copy xios server
	cp --remove-destination bin/xios_server.exe $@
	# Change namelist parameters
	cfg/replace_namelist_parameter $@/namelist_cfg nn_itend 120
	cfg/replace_namelist_parameter $@/namelist_cfg ln_icebergs .false.
	cfg/replace_namelist_parameter $@/namelist_ref ln_meshmask .false.
	cp cfg/test/jobscript.cmd $@
	sbatch --chdir $@ $@/jobscript.cmd

####################################################
# Some other recipes

# Xios server
bin/xios_server.exe:
	# HARDCODED dependency that at some point should be replaced with xios compilation
	cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe bin/xios_server.exe
# REBUILD NEMO tool
bin/rebuild_nemo.exe: bin compilation_workdir
	cd reference_workdir/tools; ./maketools -n REBUILD_NEMO -m mn4
	cp reference_workdir/tools/REBUILD_NEMO/rebuild_nemo* bin/

# Binary folder
bin:
	mkdir -p bin

%_workdir: nemo_source
	mkdir -p $@
	rsync -av --exclude='doc*' --exclude='*.svn*' nemo_source/* $@
	cp cfg/arch/arch-* $@/arch/

#%_rundir: inidata
#	mkdir -p $@
#	ln -rsf inidata/* $@
	
####################################################
# Clean recipes
# Delete (almost)-everything
clean:
	rm -rf reference_workdir nemo_source

hard_clean:
	-chmod +w inidata
	-chmod +w InitialConditions.nc
	rm -rf inidata InitialConditions.nc 

modelfactors.csv: trace_24 trace_48 trace_96
	cfg/model_factors/wrapper.sh $? 

# Trace Analysis
histogram_%.txt: trace_%.prv
	paramedir $< cfg/trace_analysis/FunctionTimeHistogram.cfg 
	mv FunctionTimeHistogram histogram_$*.txt

histograms: histogram_24.txt histogram_48.txt histogram_96.txt
	
