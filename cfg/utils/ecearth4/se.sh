#!/bin/bash
# This file defines se enviroment activation for different platforms, used by ece4

#####################################################################################################################
# Brief: Load the enviroment to run SE in MN5 
# Param: 
#   - $1: SE version 
#####################################################################################################################
function se_env_mn5()
{
    module purge
    module load miniconda/24.1.2
    source /apps/GPP/MINICONDA/24.1.2/etc/profile.d/conda.sh
    if echo $arch_name | grep impi; then
        conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/ece4env-${1}
    else
        conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/ece4env-main_openmpi
    fi
}

#####################################################################################################################
# Brief: Load the enviroment to run SE in HPC2020 
# Param: 
#   - $1: SE version 
#####################################################################################################################
function se_env_hpc2020()
{
    . /hpcperm/c3gm/repository/libs/micromamba/etc/profile.d/micromamba.sh
    micromamba activate ece4env-${1}
}
