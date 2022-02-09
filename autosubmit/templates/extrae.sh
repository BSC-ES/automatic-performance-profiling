source %ENV_SOURCES%

test_name=""
if [ "%MEMBER%" = "compilation_efficiency" ];
then
  test_name="compilation_efficiency"
  export test_name="compilation_efficiency"
elif [ "%MEMBER%" = "StrongScaling" ];
then
  test_name="strong_scaling"
  export test_name="strong_scaling"
elif [ "%MEMBER%" = "weakscaling" ];
then
  test_name="weakscaling"
  export test_name="weakscaling"
fi
source %INIDATA_ROOT%/$test_name/param_bash.cfg
mkdir -p %RUN_ROOT%/$test_name/trace_%NUMPROC%
cp -r %PROJECT_ROOT%/cfg/generate_func_list/* %RUN_ROOT%/$test_name/trace_%NUMPROC%/

cd %RUN_ROOT%/$test_name/trace_%NUMPROC%/
#Link inidata
cp %INIDATA_ROOT%/$test_name/* %RUN_ROOT%/$test_name/trace_%NUMPROC%/
#Doble check this #TODO not sure if it should be original after the member changes
ln -rsf %INIDATA_ROOT%/original %RUN_ROOT%/$test_name/trace_%NUMPROC%/
rsync -rv --exclude=.nc %INIDATA_ROOT% %RUN_ROOT%/$test_name/trace_%NUMPROC%/
cd %RUN_ROOT%/$test_name/trace_%NUMPROC%/
if [ "%MODEL%" = "nemo" ] || [ "%MODEL%" = "NEMO" ];
then
    run_folder=%RUN_ROOT%/$test_name/trace_%NUMPROC%/
    number_of_cores=%NUMPROC%
    # Copy everything from reference folder
    cp --remove-destination %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_trace/EXP00/* %RUN_ROOT%/$test_name/trace_%NUMPROC%
    # Copy xios server
    cp %BINARIES_ROOT%/xios_server.exe %RUN_ROOT%/$test_name/trace_%NUMPROC%/
    # Fix namelist parameters
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/trace_%NUMPROC%/namelist_cfg nn_itend ${trace_steps}
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/trace_%NUMPROC%/namelist_cfg ln_icebergs .false.
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/trace_%NUMPROC%/namelist_ref ln_meshmask .false.
    # Set ice frequency to 1
    %PROJECT_ROOT%/cfg/replace_namelist_parameter %RUN_ROOT%/$test_name/trace_%NUMPROC%/namelist_ref nn_fsbc 1
    # Disable output
    if [ ${output} = FALSE ] ; then \
        sed -i "s/^.*file_definition.*$$//g" %RUN_ROOT%/$test_name/trace_%NUMPROC%/context_nemo.xml ; \
    fi
fi
### trace.target
# Run extrae
module load gcc/8.1.0
module load EXTRAE/3.7.1

trace=trace.sh
cat << EOF > $trace
  #!/bin/bash

  export EXTRAE_CONFIG_FILE=%RUN_ROOT%/$test_name/trace_%NUMPROC%/extrae.xml
  source \$EXTRAE_HOME/etc/extrae.sh

  export LD_PRELOAD=\${EXTRAE_HOME}/lib/libmpitracecf.so
  export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

  \$*
EOF
chmod +x ${trace}
set -xuve
#Model specific
bin=nemo


# Copy function.txt
cp --remove-destination %COMPILATION_ROOT%/${configuration_folder}/${configuration_name}_trace/EXP00/* ${run_folder}
cp %RUN_ROOT%/$test_name/functions_dir/extrae_functions.txt %RUN_ROOT%/$test_name/trace_%NUMPROC%/extrae_functions.txt

# Generate function list for xml
%PROJECT_ROOT%/cfg/generate_func_list/generate_function_list.sh ${bin} extrae_functions.txt
#./generate_function_list.sh ${bin} extrae_functions.txt

# Spinup run
time mpirun -genv I_MPI_DEBUG=4 -n %NUMPROC% ./${trace} ${bin}

# Create list extrae_functions.txt
set +xuve
# Clean a little bit
#rm -rf set-* *.nc