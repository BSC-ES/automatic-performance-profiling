#!/bin/bash
###############################################################################
#                             VERY BASIC NEMO RUN
###############################################################################
#SBATCH --ntasks %CORES%
#SBATCH --ntasks-per-node %PROCESSES_PER_NODE%
#SBATCH -J nemo-test
#SBATCH --output log_%j.out
#SBATCH --error  log_%j.err
#SBATCH --time 02:00:00
#SBATCH --qos=debug


number_of_cores=%CORES%

# Load environment
source modules.env

# Load EXTRAE module and create wrapper
module load gcc/8.1.0
module load EXTRAE

trace=trace.sh
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

# Generate function list for xml
./generate_function_list.sh ${nemo_bin} extrae_functions.txt 

# Spinup run
time mpirun -genv I_MPI_DEBUG=4 -n ${number_of_cores} ./${nemo_bin} 


# Create list extrae_functions.txt
set +xuve
