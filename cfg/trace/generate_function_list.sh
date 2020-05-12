#!/bin/bash
# ExtraF v0.1
# Date 21/02/2014
# This tool creates a function list as Extrae demands, it should be used after gthrottling tool
# Usage: ./extraf.sh path/to/executable/ extrae_functions.txt
# Output file: extrae_functions_for_xml.txt


# List all the objects from the binary, select only the ones from the functions list and create a function file as Extrae demands
nm $1 | grep -i " T " | grep -w -f $2 | awk '{print $1" # "$3}' > extrae_functions_for_xml.txt

echo "See the function names in the file extrae_functions_for_xml.txt"
