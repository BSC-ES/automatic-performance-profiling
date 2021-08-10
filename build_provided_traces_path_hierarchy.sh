#!/bin/bash

ssh_id=$(echo ${SSH_CONNECTION} | awk '{print $2}')
if [ ! -f .${ssh_id}.env_loaded ]; then
    echo "Please load the environment sourcing load_env.sh file"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: ./build_provided_traces_path_hierarchy.sh <provided_traces_path> <cfg_file_1> [<cfg_file_2> ... <cfg_file_n>]"
    exit 1
fi

provided_path=$1

# Check provided_path exists
[ ! -d $provided_path ] && echo "Provided traces path '$provided_path' does not exist" && exit 1

# Check configuration files exist
for cfg in "${@:2}"
do
    [ ! -f $cfg ] && echo "Configuration file '$cfg' does not exist" && exit 1
done

# Build provided traces path hierarchy
for cfg in "${@:2}"
do
    python cfg/target/ConvertParamFile.py -p $cfg -o ./param_bash.cfg
    source ./param_bash.cfg
    for num_proc in $number_of_processes
    do
        mkdir -p $provided_path/$main_folder/test_$num_proc
        mkdir -p $provided_path/$main_folder/trace_$num_proc
    done
    rm ./param_bash.cfg
done

echo "Provided traces path hierarchy built"
tree $provided_path
