# traces_path
# |- strong_scaling
# |  |- traces_*/*.prv
# |  |- scalability_*/*.timing
# |- weakscaling
# |  |- experiment-1
# |  |  |- scalability_*/*.timing
# |  |  |- traces_*/*.prv
# |- hardware_benchmarks
# |  |- OSU_RUN_*/osu_${experiment}.txt
# |  |- STREAM_RUN/
# |- compilation_efficiency
# |  |- experiment-1
# |  |  |- scalability_*/*.timing


traces_path=%COMMON_PATH_LOCATIONS.PROVIDED_TRACES_PATH%
current_member=%MEMBER%
run_root=%COMMON_PATH_LOCATIONS.COMMON_PATH_LOCATIONS.RUN_ROOT%
root_dir=%CURRENT_ROOTDIR%

if [ "$current_member" = "CompilationEfficiency" ]; then
    test_name="compilation_efficiency"
elif [ "$current_member" = "StrongScaling" ]; then
    test_name="strong_scaling"
elif [ "$current_member" = "WeakScaling" ]; then
    test_name="weakscaling"
elif [ "$current_member" = "HardwareBenchmarks" ]; then
    test_name="hardware_benchmarks"
fi

if [ ! -d $root_dir/magiccut ]; then 
    git clone https://earth.bsc.es/gitlab/ces/magiccut.git --branch numpy_version $root_dir/magiccut
fi

if [ "$traces_path" != "" ]; then 
    if [ -d $traces_path/$test_name ]; then 
        cp -r $traces_path/$test_name $run_root
    else 
        echo Provided test traces path ${traces_path}/${test_name} does not exist >&2
        exit 1
    fi
fi