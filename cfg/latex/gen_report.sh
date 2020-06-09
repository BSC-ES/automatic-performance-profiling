#!/bin/bash
latex_file=$1

if [[ ! -e ${latex_file} ]]
then
  echo -e "latex report structure '${latex_file}' not found.\nAbort"
  exit 1
fi
module load LATEX/20150523
if [[ ! -e tex_dependencies.txt ]]
then
  echo -e "Dependencies file tex_dependencies.txt not found.\nAbort"
  exit 1
fi
readarray -t files_to_check < tex_dependencies.txt 
for ftc in ${files_to_check[@]}
do
  if [[ ! -f ${ftc} ]]
  then
    echo "File "${ftc} "not found"
    echo "Abort"
    exit 1
  fi
done

pdflatex ${latex_file}
evince ${latex_file//.tex}.pdf 
