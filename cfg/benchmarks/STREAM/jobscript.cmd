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


for number_of_cores in  01 02 04 08 16 32 48
do
  export OMP_NUM_THREADS=${number_of_cores}
  ./stream > stream_${number_of_cores}.txt
done
