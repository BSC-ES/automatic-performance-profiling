#!/bin/bash
model=harmonie
configuration=METCOOP25C

config_folder=configurations
model_config_folder=${config_folder}/model/${model}/

source load_env.sh

if [[ $@ -gt 0 ]]
then
  # You should run with -j16
  queue=$1
else
  queue=debug
fi

make experiment parameters_file=${model_config_folder}/strongscaling/${configuration} slurm_queue=${queue}

#make experiment parameters_file=${model_config_folder}/strongscaling/${configuration} slurm_queue=${queue}  &
#make experiment parameters_file=${config_folder}/hardware_benchmarks slurm_queue=${queue} &
#for config in ${model_config_folder}/MultiExperiment/weakscaling/${configuration}/*
#do
#  make experiment parameters_file=${config} slurm_queue=${queue} &
#done
#for config in ${model_config_folder}/MultiExperiment/compilation_efficiency/${configuration}/*
#do
#  make experiment parameters_file=${config} slurm_queue=${queue} &
#done
# Wait for all the runs to be done and start creating the report
#wait

#main_folder=`pwd`

#cd run_dir/strong_scaling/BENCH/
#  source load_env.sh
#  make report_add_strong_scaling report_file=${main_folder}/report.pkl
#cd - 
#cd run_dir/hardware_benchmarks
#  source load_env.sh
#  make report_add_benchmarks report_file=${main_folder}/report.pkl
#cd -

#source load_env.sh
#make report_add_multi  report_file=${main_folder}/report.pkl
#make report parameters_file=${model_config_folder}/strongscaling/${configuration}
