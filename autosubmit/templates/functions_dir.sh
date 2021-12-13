source %ENV_SOURCES%
source %INIDATA_ROOT%/strong_scaling/param_bash.cfg
#Solo 1 vez

mkdir -p %RUN_ROOT%/strong_scaling/functions_dir
cd %RUN_ROOT%/strong_scaling/functions_dir
cp %BINARIES_ROOT%/%MODEL%*trace.exe %RUN_ROOT%/strong_scaling/functions_dir/%MODEL%
model_exec=%RUN_ROOT%/strong_scaling/functions_dir/%MODEL% #?

# Copy function and extrae configuration
cp -r %PROJECT_ROOT%/cfg/generate_func_list/* %RUN_ROOT%/strong_scaling/functions_dir/

n_functions=%TRACE_N_FUNCTIONS%

# Load EXTRAE module and create wrapper
module load gcc/8.1.0
module load EXTRAE/3.7.1

trace=./trace.sh
cat << EOF > $trace
  #!/bin/bash

  export EXTRAE_CONFIG_FILE=%RUN_ROOT%/strong_scaling/functions_dir/extrae.xml
  source \$EXTRAE_HOME/etc/extrae.sh

  export LD_PRELOAD=\${EXTRAE_HOME}/lib/libmpitracecf.so
  export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

  \$*
EOF

chmod +x ${trace}

# List of function not to trace
function_to_avoid=%PROJECT_ROOT%/cfg/generate_func_list/model/%MODEL%/list_of_func_notto_trace.txt

# Generate function list for xml
function_file=extrae_functions.txt
function_avg_dur_file=function_avg_dur.txt
cat /dev/null > ${function_file}
cat /dev/null > ${function_avg_dur_file}

executable=${model_exec}
# Spinup run
time mpirun -genv I_MPI_DEBUG=4 -n %NUMPROC% ${trace} ${executable}
%PROJECT_ROOT%/cfg/trace_analysis/paramedir ${executable}.prv sampling_user_function.cfg
# Create list extrae_functions.txt
set +xuve
histo_file=sampling_user_function

# Take function names
read -a func_name < <(head -1 ${histo_file} | sed 's/\w*[..]\w*//g'| sed 's/\]//g' | sed 's/\[//g')
# Take function average duration
read -a func_avg_dur < <(grep Average ${histo_file} | awk '{$1=""; print $0}')

# Save info to a file
for i_func_name in `seq 0 $((${#func_name[@]}-1))`
do
    echo  ${func_name[${i_func_name}]} ${func_avg_dur[$i_func_name]} >> ${function_avg_dur_file}
done

# Order data in decreasing order of average time
cat ${function_avg_dur_file} > ${function_avg_dur_file}_tmp
cat ${function_avg_dur_file}_tmp | sort -k 2 -nr  | column -t >  ${function_avg_dur_file}

# Output first $n_function names
awk '{print $1}' ${function_avg_dur_file} | grep '_mp_' | grep -v -f ${function_to_avoid} | head -${n_functions}> ${function_file}

#rm ${function_avg_dur_file}_tmp
#rm -rf *nc