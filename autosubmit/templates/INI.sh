#!/bin/bash
set -xuve
cd %PROJECT_ROOT%
#source cfg/env/MN4/environment.env
##export PYTHONPATH=$PYTHONPATH:$(pwd)
#touch .${ssh_id}.env_loaded
#trap 'rm .'${ssh_id}'.env_loaded' EXIT

mkdir -p inidata
cd inidata
source cfg/target/param_bash.cfg
run_folders=()
if %ENABLE_HW_BENCHMARKS%
then
  run_folder+=("hardware_benchmarks")
  mkdir hardware_benchmarks
  python %CONVERT_PARAM_FILE% -p %HW_BENCHMARKS_PARAMETERS_ROOT%/param.cfg -o %INIDATA_ROOT%/hardware_benchmarks/param_bash.cfg
fi
if %ENABLE_COMPILATION_EFFICIENCY%
then
  run_folder+=("compilation_efficiency")
  mkdir compilation_efficiency
  python %CONVERT_PARAM_FILE% -p %COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/param.cfg -o %INIDATA_ROOT%/compilation_efficiency/param_bash.cfg
fi
if %ENABLE_WEAKSCALING%
then
  run_folder+=("weakscaling")
  mkdir weakscaling
  python %CONVERT_PARAM_FILE% -p %WEAKSCALING_PARAMETERS_ROOT%/param.cfg -o %INIDATA_ROOT%/weakscaling/param_bash.cfg
fi
if %ENABLE_STRONGSCALING%
then
  run_folder+=("strong_scaling")
  mkdir strong_scaling
  python %CONVERT_PARAM_FILE% -p %STRONGSCALING_PARAMETERS_ROOT%/param.cfg -o %INIDATA_ROOT%/strong_scaling/param_bash.cfg
fi
for i in "${run_folder[@]}"
do
  source %INIDATA_ROOT%/$i/param_bash.cfg
  if [[ ! -z ${configuration_resolution+x} ]]
  then
    # It is BENCH, copy the namelist into the configuration namelist_cfg
    cp %PROJECT_ROOT%/cfg/utils/nemo/iodef.xml  %INIDATA_ROOT%/$i
    cp %PROJECT_ROOT%/cfg/utils/nemo/context_nemo.xml  %INIDATA_ROOT%/$i
  else
    wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar
    tar -xf ORCA2_ICE_v4.0.tar -C %INIDATA_ROOT%/$i
    gunzip %INIDATA_ROOT%/$i/*
    # Remove write permissions to avoid unwilingly manipulate the input files
    chmod -w %INIDATA_ROOT%/$i
    # Remove compressed file
    rm ORCA2_ICE_v4.0.tar
fi
#INIDATA_END must look
#mkdir -p $(@D)
# Link inidata
#ln -rsf inidata/* $(@D)
#rsync -rv --exclude=.nc inidata/ $(@D)
#touch $@
#done

