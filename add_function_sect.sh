#!/bin/bash
function_folder=$1
report_obj=$2
if [[ $# -ne 2 ]]
then
  echo "Usage"
  echo $0 "function_folder report_obj"
  exit 1
fi
cd ${function_folder}
for f in *
do
 f_name=${f%.csv}
 python ../cfg/latex/ReportGenerator.py -O ${report_obj} -S "Functions detailed report" -s ${f_name} --add-csv ${f} 
 python ../cfg/latex/ReportGenerator.py -O ${report_obj} -S "Functions detailed report" -s ${f_name} --add-csv ../dimemas_csv/mpi/${f_name}_mpi.csv 
 python ../cfg/latex/ReportGenerator.py -O ${report_obj} -S "Functions detailed report" -s ${f_name} --add-csv ../dimemas_csv/counter/${f_name}_counter.csv 
 echo ${f}
done
