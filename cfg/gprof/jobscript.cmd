#!/bin/bash
###############################################################################
#                             VERY BASIC NEMO RUN
###############################################################################
#SBATCH --ntasks 48
#SBATCH -J nemo-test
#SBATCH --output log_%j.out
#SBATCH --error  log_%j.err
#SBATCH --time 02:00:00
#SBATCH --qos=debug

# Load environment
source modules.env

set -xuve
nemo_bin=nemo
xios_bin=xios_server.exe
export GMON_OUT_PREFIX='gmon.out-'`/bin/uname -n`
# Spinup run
time mpirun \
            -n 20 ./${nemo_bin} : -n 4 ./${xios_bin} \
          : -n 20 ./${nemo_bin} : -n 4 ./${xios_bin}

rm ORCA2_000?????_restart_????.nc


# Create list extrae_functions.txt
./gthrottling.sh nemo
set +xuve
