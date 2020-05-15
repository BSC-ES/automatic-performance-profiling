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

set -xuve
nemo_bin=nemo
xios_bin=xios_server.exe
# Spinup run
time mpirun -n ${number_of_cores} ./${nemo_bin} 

rm ORCA2_000?????_restart_????.nc

set +xuve
