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

set -xuve
number_of_cores=%CORES%
nemo_bin=nemo
xios_bin=xios_server.exe
# Spinup run
time mpirun -genv I_MPI_DEBUG=4 -n ${number_of_cores} ./${nemo_bin} 


set +xuve
