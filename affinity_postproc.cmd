#!/bin/bash
multi_exp_folder=$1
report_obj=$2
if [[ $# -ne 2 ]]
then
  echo "Expected two agument, got "$#
  echo "Please specify multi_exp_folder and a report object"
  exit 1
fi
if [[ ! -d ${multi_exp_folder}  ]] 
then
  echo -e "folder:" ${multi_exp_folder}" not found\nAbort ..."
  exit 1
fi
for folder in ${multi_exp_folder}/*
do
  if [[ -d ${folder} ]]
  then
    cp ${folder}/*.json ${multi_exp_folder}
  fi
done

python cfg/parser/comparator.py ${multi_exp_folder}/*.json -s > affinity.csv
#python /gpfs/scratch/bsc32/bsc32402/Issue23/nemo_performance_profile/affinity_BENCH/BENCH_O1_46/cfg/parser/comparator.py ${multi_exp_folder}/*.json -s > affinity.csv
python cfg/latex/report_gen.py -O report.pkl -S "Multi Experiment" -s "Affinity" --add-csv affinity.csv 

