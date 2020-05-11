#!/bin/bash
###############################################################################
#                             VERY BASIC NEMO RUN
###############################################################################
#SBATCH --ntasks 48
#SBATCH -J nemo-spinup
#SBATCH --output log_%j.out
#SBATCH --error  log_%j.err
#SBATCH --time 02:00:00
#SBATCH --qos=debug

# Load environment
source modules.env

set -xuve
nemo_bin=nemo_reference.exe
# Spinup run
time mpirun \
            -n 20 ./${nemo_bin} : -n 4 ./xios_server.exe \
          : -n 20 ./${nemo_bin} : -n 4 ./xios_server.exe

# Make rebuild
./rebuild_nemo ORCA2_00058400_restart 40

mv ORCA2_00058400_restart.nc ../InitialConditions.nc

rm ORCA2_00058400_restart_????.nc

set +xuve
