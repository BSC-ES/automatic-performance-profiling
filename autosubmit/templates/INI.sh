set -xuve
cd %EXP_ROOT%
source %ENV_SOURCES%
export PYTHONPATH=$PYTHONPATH:$(pwd)
mkdir -p inidata
cd inidata

if [ "%MEMBER%" = "HardwareBenchmarks" ];
then
  folder="hardware_benchmarks"
  mkdir -p hardware_benchmarks
  python %CONVERT_PARAM_FILE% -p %HW_BENCHMARKS_PARAMETERS_ROOT%/%CONFIGURATION% -o %INIDATA_ROOT%/hardware_benchmarks/param_bash.cfg
fi
if [ "%MEMBER%" = "CompilationEfficiency" ];
then
  folder="compilation_efficiency"
  mkdir -p compilation_efficiency
  for config in %COMPILATION_EFFICIENCY_PARAMETERS_ROOT%/%CONFIGURATION%/*; do
    python %CONVERT_PARAM_FILE% -p $(config) -o %INIDATA_ROOT%/compilation_efficiency/$(config)/param_bash.cfg
  done
fi
if [ "%MEMBER%" = "WeakScaling" ];
then
  folder="weakscaling"
  mkdir -p weakscaling
  for config in %WEAKSCALING_PARAMETERS_ROOT%/%CONFIGURATION%/*; do
    python %CONVERT_PARAM_FILE% -p $(config) -o %INIDATA_ROOT%/weakscaling/$(config)/param_bash.cfg
  done
fi
if [ "%MEMBER%" = "StrongScaling" ];
then
  folder="strong_scaling"
  mkdir -p strong_scaling
  python %CONVERT_PARAM_FILE% -p %STRONGSCALING_PARAMETERS_ROOT%/%CONFIGURATION% -o %INIDATA_ROOT%/strong_scaling/param_bash.cfg
fi
###
#Data
if [ "%MEMBER%" != "HardwareBenchmarks" ];
then
  #Load parameter configuration depending on the test
  source %INIDATA_ROOT%/$folder/param_bash.cfg
  # Clone model
  if [ "%MODEL%" = "nemo" ];
  then
      #nemo_source.target
      # if the mirror has not been cloned yet
      if [[ ! -d nemo_mirror ]]
      then
        %PROJECT_ROOT%/cfg/clone_nemo.sh %COMPILATION_ROOT%/nemo_mirror ${model_branch}
      fi
      ln -sf %COMPILATION_ROOT%/nemo_mirror %COMPILATION_ROOT%/${model}_source
  fi

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
fi




