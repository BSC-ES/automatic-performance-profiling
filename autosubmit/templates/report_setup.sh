#!/bin/bash
#####################################################################################################################
# report_setup.sh
# Brief: This script allows to start the workflow from here if a experiment path is provided, if not it just
#           clones magiccut
#####################################################################################################################
# traces_path
# |- tracing
# |  |- traces_*/*.prv
# |- strong_scaling
# |  |- experiment-1
# |  |  |- scalability_*/*.timing | scalability_*/lucia_*
# |- weakscaling
# |  |- experiment-1
# |  |  |- scalability_*/*.timing | scalability_*/lucia_*
# |- hardware_benchmarks
# |  |- OSU_RUN_*/osu_${experiment}.txt
# |  |- STREAM_RUN/
# |- compilation_efficiency
# |  |- experiment-1
# |  |  |- scalability_*/*.timing | scalability_*/lucia_*

traces_path=%COMMON_PATH_LOCATIONS.PROVIDED_TRACES_PATH%
current_member=%MEMBER%
run_root=%COMMON_PATH_LOCATIONS.COMMON_PATH_LOCATIONS.RUN_ROOT%
root_dir=%CURRENT_ROOTDIR%

case "${current_member}" in
    "CompilationEfficiency")
        member="compilation_efficiency"
        ;;
    "StrongScaling")
        member="strong_scaling"
        ;;
    "WeakScaling")
        member="weakscaling"
        ;;
    "HardwareBenchmarks")
        member="hardware_benchmarks"
        ;;
esac

if [ ! -d $root_dir/magiccut ]; then 
    git clone https://earth.bsc.es/gitlab/ces/magiccut.git --branch numpy_version $root_dir/magiccut
fi

if [ "$traces_path" != "" ]; then 
    if [ -d $traces_path/$member ]; then 
        cp -r $traces_path/$member $run_root
    else 
        echo Provided test traces path ${traces_path}/${member} does not exist >&2
        exit 1
    fi
fi