set -xuve
cd %EXP_ROOT%
source %ENV_SOURCES%
export PYTHONPATH=$PYTHONPATH:$(pwd)
mkdir -p inidata

cd inidata
declare -a run_folder
enabled=(%ENABLED_TESTS%)
if %ENABLE_HW_BENCHMARKS%;
then
  run_folder+=("hardware_benchmarks")
  mkdir -p hardware_benchmarks
  python %CONVERT_PARAM_FILE% -p %HW_BENCHMARKS_PARAMETERS_ROOT%/%CONFIGURATION% -o %INIDATA_ROOT%/hardware_benchmarks/param_bash.cfg
fi
if %ENABLE_COMPILATION_EFFICIENCY%;
then
  run_folder+=("compilation_efficiency")
  mkdir -p compilation_efficiency
  python %CONVERT_PARAM_FILE% -p %COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%CONFIGURATION% -o %INIDATA_ROOT%/compilation_efficiency/param_bash.cfg
fi
if %ENABLE_WEAKSCALING%;
then
  run_folder+=("weakscaling")
  mkdir -p weakscaling
  python %CONVERT_PARAM_FILE% -p %WEAKSCALING_PARAMETERS_ROOT%/%CONFIGURATION% -o %INIDATA_ROOT%/weakscaling/param_bash.cfg
fi
if %ENABLE_STRONGSCALING%;
then
  run_folder+=("strong_scaling")
  mkdir -p strong_scaling
  python %CONVERT_PARAM_FILE% -p %STRONGSCALING_PARAMETERS_ROOT%/%CONFIGURATION% -o %INIDATA_ROOT%/strong_scaling/param_bash.cfg
fi
###
#Data
mkdir -p original
wget https://zenodo.org/record/3386310/files/ORCA2_ICE_v4.0.tar #Revise
tar -xf ORCA2_ICE_v4.0.tar -C original
gunzip original/*
# Remove write permissions to avoid unwilingly manipulate the input files
chmod -w original
# Remove compressed file
rm ORCA2_ICE_v4.0.tar
####
for folder in "${run_folder[@]}"
do
    source %INIDATA_ROOT%/$folder/param_bash.cfg
    if [[ ! -z ${configuration_resolution+x} ]]
    then
        # It is BENCH, copy the namelist into the configuration namelist_cfg
        cp %PROJECT_ROOT%/cfg/utils/%MODEL%/iodef.xml  %INIDATA_ROOT%/$folder
        cp %PROJECT_ROOT%/cfg/utils/%MODEL%/context_%MODEL%.xml  %INIDATA_ROOT%/$folder
    else
        # Link inidata to each model
        ln -rsf original/* %INIDATA_ROOT%/$folder
        rsync -rv --exclude=.nc original/ %INIDATA_ROOT%/$folder
        #touch $@
    fi
done




