#!/bin/bash
###############################################################################
#                             VERY BASIC NEMO RUN
###############################################################################
#SBATCH --ntasks %CORES%
#SBATCH --ntasks-per-node %PROCESSES_PER_NODE%
#SBATCH -J osu-bench
#SBATCH --output log_%j.out
#SBATCH --error  log_%j.err
#SBATCH --time 00:05:00
#SBATCH --qos=debug

number_of_cores=%CORES%
mpirun -np ${number_of_cores} ./%TEST% > %TEST%_${number_of_cores}.txt
