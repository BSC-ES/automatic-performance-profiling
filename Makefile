# Setting some parameters from config file
config_file=param.cfg
nemo_branch=$(shell grep "nemo_branch"  ${config_file} )
$(eval ${nemo_branch})

help:
	@echo ""
	@echo "Recipes to prepare all the necessary elements to launch a performance analysis on NEMO (4.0, 4.0.1)"
	@echo ""

# NEMO Sources
nemo_source: nemo_mirror
	# Download NEMO sources from svn repository
	ln -sf $< $@

nemo_mirror:
	cfg/clone_nemo.sh nemo_mirror $(nemo_branch)

# NEMO binary
bin/nemo_reference.exe: bin reference_workdir
	# Compile NEMO
	reference_workdir/makenemo -n OCE_Reference -r ORCA2_ICE_PISCES -d OCE -m mn4 del_key "key_si3 key_top"
	# Copy binary into bin folder
	cp reference_workdir/cfgs/OCE_Reference/EXP00/nemo bin/nemo_reference.exe
	
reference_inidata: inidata bin/nemo_reference.exe bin/xios_server.exe
	mkdir $@
	# Copy everything from reference folder
	cp reference_workdir/cfgs/OCE_Reference/EXP00/* $@
	# Copy xios server
	cp bin/xios_server.exe $@
	# Link inidata
	ln -rsf inidata/* $@


test: reference_inidata
	mkdir $@
	cp -r reference_inidata/* $@
	cfg/replace_namelist_parameter $@/namelist_cfg nn_itend 120
	cfg/replace_namelist_parameter $@/namelist_cfg ln_icebergs .false.
	cfg/replace_namelist_parameter $@/namelist_ref ln_meshmask = .false.
	cp cfg/test/jobscript.cmd $@
	sbatch --chdir $@ $@/jobscript.cmd

# REBUILD NEMO tool
bin/rebuild_nemo.exe: bin reference_workdir
	cd reference_workdir/tools; ./maketools -n REBUILD_NEMO -m mn4
	cp reference_workdir/tools/REBUILD_NEMO/rebuild_nemo* bin/

# Binary folder
bin:
	mkdir -p bin


# Recipe for the inidata
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

spinup: bin/nemo_reference.exe inidata bin/rebuild_nemo.exe bin/xios_server.exe
	# Prepare folder and link input netcdf, binary, namlists, xmls and xios(dependency) files
	mkdir -p spinup
	ln -rsf inidata/* spinup
	ln -rsf bin/nemo_reference.exe spinup
	ln -rsf cfg/environment.env spinup/modules.env
	ln -rsf cfg/spinup/namelists/${nemo_release}/* spinup
	ln -rsf cfg/spinup/xmls/${nemo_release}/* spinup
	ln -rsf bin/xios_server.exe spinup
	ln -rsf bin/rebuild_nemo* spinup
	cp cfg/spinup/jobscript.cmd spinup
	sbatch --chdir spinup spinup/jobscript.cmd

%_workdir: nemo_source
	mkdir -p $@
	rsync -av --exclude='doc*' --exclude='*.svn*' nemo_source/* $@
	cp cfg/arch/arch-mn4.fcm $@/arch/arch-mn4.fcm

%_rundir: inidata
	mkdir -p $@
	ln -rsf inidata/* $@
	
# Delete (almost)-everything
clean:
	rm -rf reference_workdir nemo_source

hard_clean:
	-chmod +w inidata
	-chmod +w InitialConditions.nc
	rm -rf inidata InitialConditions.nc spinup

bin/xios_server.exe:
	# HARDCODED dependency that at some point should be replaced with xios compilation
	cp /gpfs/projects/bsc32/bsc32870/xios/2.5/mn4-r1650-prod/bin/xios_server.exe bin/xios_server.exe
