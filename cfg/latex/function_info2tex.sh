#!/bin/bash
latex_report=$1
csv_folder=$2
table_per_page=6
if [[ ! -d ${csv_folder} ]]
then
    echo -e "csv folder "${csv_folder} " not found.\nAbort"
    exit 1
fi

if [[ ! -e ${latex_report} ]]
then
    echo -e "Latex file "${latex_report} " not found.\nAbort"
    exit 1
fi

start_line=`grep -rin CSV_INFO_FUNCTION_PLACEHOLDER ${latex_report} | awk -F : '{print $1}'`
clear_page_count=${table_per_page}
for csv_file in ${csv_folder}/*
do
    file_name=${csv_file#${csv_folder}/}
    #Latex need the underscores to be escaped and sed also ...
    function_name=`echo ${file_name%.csv} | sed 's@\_@\\\\\\\_@g'`
    sed -i  ''${start_line}'i \\\begin{table}\n\\centering\n\\csvautobooktabular{'${csv_file}'}\n\\caption{'${function_name}'}\n\\end{table}'     ${latex_report} 
    clear_page_count=$((clear_page_count-1))
    echo $function_name ${clear_page_count} "Q" >> prova
    if [[ ${clear_page_count} -eq 0 ]]
    then
      clear_page_count=${table_per_page}
      sed -i  ''${start_line}'i \\\clearpage' ${latex_report}
      start_line=$((start_line + 6)) 
    else
      start_line=$((start_line + 5))
    fi
done
sed -i 's/CSV_INFO_FUNCTION_PLACEHOLDER//g' ${latex_report}
