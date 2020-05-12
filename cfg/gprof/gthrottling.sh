#!/bin/bash
# This tool creates a function list with the computation important functions with reagards some specific rules
# Usage: ./extract_gprof.sh path/to/executable/executable 
# Output file: extrae_functions.txt

rm gprof_functions
rm suspected_functions_names_only
rm suspected_functions
rm extrae_functions.txt

# nm tool lists the symbols from objects and we select the ones with type T|t which the type is in the text section  
nm $1 | grep -i " T " | awk '{print $3}' > function_names.txt
echo "See the function names from the binary in the file function_names.txt"
dir=$(dirname $1)

for i in `ls $dir/gmon*`;
do
    echo -e "Analyzing "$i"\n" 
    gprof $1 $i >gprof_temp
    #We extract from each gprof file only the part about the functions, number of calls and durations, the call-paths ar enot needed
    cat gprof_temp | grep -v ":" | awk 'BEGIN{k=0}{if($1=="%") {k=k+1};if(k>0 && k<2 && $1==$1+0) print $0}' > temp
    #We save the name of the functions
    cat temp | awk '{if($7~/^$/) print $4;else print $7}' > gprof_functions

    #From the initial list we save only the ones that gprof files include    
    cat function_names.txt | grep -w -f gprof_functions > extrae_new_list

    #We apply the throttling rule: 
    # 1) If there is no information about each call of a function is suspected if the total duration is less than 0.1% of the total execution time
    # 2) If a function is called more than 10,000 times:
    #    2.1) If its duration is less or equal to 5% ($1<=5, you can change them according to your application) of the total execution time 
    #    2.2) If the duration of each call is less than 0.001s, then exclude it
    # 3) If the total execution time of this function is 0.0%, then remove it
    cat temp | awk '{if($7~/^$/ && $1<0.1) print $4" "$1; else if(NF==7 && $4>10000 && (($1<=5 || $5<=0.001)) || $1==0.0) print $7" "$4}' >> suspected_functions
    awk '{print $1}' suspected_functions >> suspected_functions_names_only

    # Sort and remove any double functions from the list with suspected functions
    cat suspected_functions_names_only | sort | uniq > temp_file
    mv temp_file suspected_functions_names_only

    # Create a new fucntion list with the non suspected functions
    cat extrae_new_list | grep -w -v -f suspected_functions_names_only >> extrae_functions.txt
done

#Sort and uniw the useful functions because are called from many processors and can by include twice
cat extrae_functions.txt | sort | uniq > temp2
mv temp2 extrae_functions.txt
rm temp
echo -e "Input function list: "function_names.txt" "`wc -l function_names.txt | awk '{print $1}'`" functions"
echo -e "New function list: extrae_functions.txt "`wc -l extrae_functions.txt | awk '{print $1}'`" functions"

exit
