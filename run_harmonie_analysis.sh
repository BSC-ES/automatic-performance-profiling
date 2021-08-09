#!/bin/bash
model=harmonie
configuration=METCOOP25C

config_folder=configurations
model_config_folder=${config_folder}/model/${model}

cp ${model_config_folder}/strongscaling/${configuration} ./param.cfg
source load_env.sh

if [[ $@ -gt 0 ]]
then
  # You should run with -j16
  queue=$1
else
  queue=debug
fi

make -f Makefile.part2 experiment parameters_file=${model_config_folder}/strongscaling/${configuration} slurm_queue=${queue}

main_folder=`pwd`

cd run_dir/strong_scaling/${configuration}
source load_env.sh
make -f Makefile.part2 report_add_strong_scaling parameters_file=${model_config_folder}/strongscaling/${configuration} report_file=${main_folder}/report.pkl
cd -

source load_env.sh
make -f Makefile.part2 report parameters_file=param.cfg
