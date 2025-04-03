#!/bin/bash
# ExtraF v0.1
# Date 21/02/2014
# This tool creates a function list as Extrae demands, it should be used after gthrottling tool
# Usage: ./extraf.sh path/to/executable/ extrae_functions.txt
# Output file: extrae_functions_for_xml.txt


# List all the objects from the binary, select only the ones from the functions list and create a function file as Extrae demands
functions_list="${@: -1}"
i=1
echo -n > extrae_functions_for_xml.txt
for binary in "$@"; do
    if [ $i -eq $# ]; then
        continue
    fi
    nm -C $binary | grep -f $functions_list | awk '{print $3" # "$1}' >> extrae_functions_for_xml.txt
    i=$((i+1))
done

echo "See the function names in the file extrae_functions_for_xml.txt"
