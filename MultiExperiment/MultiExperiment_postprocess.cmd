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
csv_file=${multi_exp_folder}.csv
cat /dev/null > ${csv_file}
for folder in ${multi_exp_folder}/*
do
  if [[ -d ${folder} ]]
  then
    cp ${folder}/*.json ${multi_exp_folder}
  fi
done

python ../cfg/parser/comparator.py ${multi_exp_folder}/*/*.json -s > ${csv_file}
python ../cfg/latex/ReportGenerator.py -O ${report_obj} -S "Multi Experiment" -s ${multi_exp_folder} --add-csv ${csv_file}

