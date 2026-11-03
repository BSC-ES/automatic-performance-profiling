#!/bin/bash
# This file defines the se environment activation for different platforms, used by ece4

#####################################################################################################################
# Brief: Resolves the SE conda env of an arch from the model config
# Param: 
#   - $1: arch name (e.g. O3_impi_prod)
#   - $2: MODEL.ARCH_NAMES list
#   - $3: MODEL.SE_CONDA_ENVS list, same order as $2
# Return:
#   - the conda env path (or name) on stdout
#####################################################################################################################
function se_conda_env()
{
    local -a arch_names se_envs
    arch_names=($(bashify_array "$2"))
    se_envs=($(bashify_array "$3"))

    local index
    for index in "${!arch_names[@]}"; do
        if [ "${arch_names[index]}" = "${1}" ]; then
            echo "${se_envs[index]}"
            return 0
        fi
    done

    echo "[ERROR] No MODEL.SE_CONDA_ENVS entry for the arch ${1}" >&2
    return 1
}

#####################################################################################################################
# Brief: Load the environment to run SE in MN5 
# Param: 
#   - $1: conda env path
#####################################################################################################################
function se_env_mn5()
{
    module purge
    module load miniconda/24.1.2
    source /apps/GPP/MINICONDA/24.1.2/etc/profile.d/conda.sh
    conda activate "${1}"
}

#####################################################################################################################
# Brief: Load the environment to run SE in HPC2020 
# Param: 
#   - $1: conda env path
#####################################################################################################################
function se_env_hpc2020()
{
    . /hpcperm/c3gm/repository/libs/micromamba/etc/profile.d/micromamba.sh
    micromamba activate "${1}"
}
