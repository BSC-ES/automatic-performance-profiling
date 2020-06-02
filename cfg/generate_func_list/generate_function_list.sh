#!/bin/bash

executable=$1

func_to_avoid=$2
output_file=$3
if [[ ! -f ${executable} ]]
then
  echo "Executable "${executable} "file not found"
  echo "aborting"
  exit 1
fi


if [ "$#" -gt 1 ]; then
  func_to_avoid=$2
  if [[ ! -f ${func_to_avoid} ]]
  then
    echo ${func_to_avoid} "file not found"
    echo "aborting"
    exit 1
  fi
fi

if  [ "$#" -gt 2 ]; then
  output_file=$3
else
  output_file='tmp'
fi

# List all the objects from the binary, select only the ones from the functions list and create a function file as Extrae demands

if [[ -z ${func_to_avoid+x} ]]
then
  nm ${executable} | grep -i ' T ' | grep '_mp_'  > ${output_file}
else
  nm ${executable} | grep -i ' T ' | grep '_mp_'  | grep -v -f ${func_to_avoid}> ${output_file}
fi
sed -i 's/ T / # /g' ${output_file}

