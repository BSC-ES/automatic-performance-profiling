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

# Load environment
source modules.env

number_of_cores=%CORES%

if [ ! -z ${HALF_FILLED_NODES} ] ; then
   echo "Using half filled nodes"
   number_of_cores=$( echo ${number_of_cores} / 2 | bc )
fi
set -xuve
nemo_bin=nemo
xios_bin=xios_server.exe
# Spinup run
time mpirun -n ${number_of_cores} ./${nemo_bin} 


set +xuve
