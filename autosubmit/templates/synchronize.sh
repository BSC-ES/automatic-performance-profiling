#!/bin/bash
#####################################################################################################################
# synchronize.sh
# Brief: This script syncs the local auto profiling repository with the hpc platform
#####################################################################################################################

###################
# AS variables
###################
hpc_proj=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
local_proj=%CURRENT_ROOTDIR%/proj/%PROJECT.PROJECT_DESTINATION%
hpc_type=%HPCTYPE%
hpc_host=%HPCHOST%
hpc_user=%HPCUSER%

function recursive_ecaccess_cp() {
    local current_dir=$1
    local current_remote_dir=$2
    local files=(${current_dir}/*)
    local actual_files=""

    if echo ${ignored_dirs} | grep -E "(^| )${current_dir}($| )";  then
        return 0
    fi

    ecaccess-file-mkdir ${hpc_host}:${current_remote_dir}

    for f in "${files[@]}"; do
        if [ -f $f ]; then
            actual_files+=" $f"
        fi
    done

    if [ "${actual_files}" != "" ]; then
        ecaccess-file-mput -f ${actual_files} ${hpc_host}:${current_remote_dir}/
    fi

    for f in "${files[@]}"; do
        if [ -d $f ]; then
            local next_dir=${current_remote_dir}/$(basename $f)
            recursive_ecaccess_cp $f ${next_dir}
        fi
    done
}

###################
# Start script
###################


case ${hpc_type} in
    "ecaccess")
        ignored_dirs="${local_proj}/docs ${local_proj}/autosubmit ${local_proj}/.git" 
        recursive_ecaccess_cp ${local_proj} ${hpc_proj}
    ;;
    "slurm")
        ignored_dirs=( --exclude={"docs/","autosubmit/",".git/"} )
        rsync -avz "${ignored_dirs[@]}" ${local_proj}/ ${hpc_user}@${hpc_host}:${hpc_proj}
    ;;
esac