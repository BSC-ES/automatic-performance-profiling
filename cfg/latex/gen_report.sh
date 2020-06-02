#!/bin/bash

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

csv_in=modelfactors.csv
latex_file=report.tex

sed -i 's/#//g'  ${csv_in}
sed -i 's/;/,/g' ${csv_in}
pdflatex ${latex_file}
evince ${latex_file//.tex}.pdf 
