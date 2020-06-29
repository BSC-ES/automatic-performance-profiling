#!/bin/bash
###############################################################################
#                             VERY BASIC NEMO RUN
###############################################################################
#SBATCH --ntasks %CORES%
#SBATCH -J nemo-test
#SBATCH --output log_%j.out
#SBATCH --error  log_%j.err
#SBATCH --time 02:00:00
#SBATCH --qos=debug


number_of_cores=%CORES%
n_functions=80

# Load EXTRAE module and create wrapper
module load gcc/8.1.0
module load EXTRAE/3.7.1

trace=./trace.sh
cat << EOF > $trace
  #!/bin/bash

  export EXTRAE_CONFIG_FILE=./extrae.xml
  source \$EXTRAE_HOME/etc/extrae.sh

  export LD_PRELOAD=\${EXTRAE_HOME}/lib/libmpitracecf.so
  export LD_LIBRARY_PATH=\${EXTRAE_HOME}/lib/:\$LD_LIBRARY_PATH

  \$*
EOF

chmod +x ${trace}

set -xuve
nemo_bin=nemo

# List of function not to trace
function_to_avoid=list_of_func_notto_trace.txt

# Generate function list for xml
function_file=extrae_functions.txt
function_avg_dur_file=function_avg_dur.txt
cat /dev/null > ${function_file}
cat /dev/null > ${function_avg_dur_file}


# Spinup run
time mpirun -genv I_MPI_DEBUG=4 -n ${number_of_cores} ${trace} ./${nemo_bin} 

# Create list extrae_functions.txt
set +xuve

# Produce istogram of function time duration
../cfg/trace_analysis/paramedir nemo.prv sampling_user_function.cfg

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

rm ${function_avg_dur_file}_tmp

