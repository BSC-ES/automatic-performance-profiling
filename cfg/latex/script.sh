#!/bin/bash
python ReportGenerator.py -O ../prova.pkl --section-title Introduction --section-number 1 -T Introduction.txt
python ReportGenerator.py -O ../prova.pkl --section-title "Hardware Benchmarks" --section-number 2 
python ReportGenerator.py -O ../prova.pkl -S "Hardware Benchmarks" -s "OSU Benchmark" --add-img images/OSU
python ReportGenerator.py -O ../prova.pkl -S "Hardware Benchmarks" -s "STREAM Benchmark" --add-csv images/STREAM/stream_48_fmt.csv
python ReportGenerator.py -O ../prova.pkl -S "Functions detailed report" --add-csv /home/Earth/sparonuz/DATA/json/function_dir
python ReportGenerator.py -O ../prova.pkl -S "MPI Profile" --add-csv  ./48_MPI_call_profile.pm --c
python ReportGenerator.py -O ../prova.pkl --report-title "Report Nemo version Piriri"
python ReportGenerator.py -O ../prova.pkl --report-authors "O. Tinto Primis"
python ReportGenerator.py -O ../prova.pkl --report-authors "Stella V. Paronuzzi Ticco"
python ReportGenerator.py -O ../prova.pkl -I
mkdir prova 
cp ../prova.pkl prova/riprova.pkl
python ReportGenerator.py -O  ./prova/riprova.pkl -d
#mv ../prova.pkl /home/Earth/sparonuz/DATA/report_trunk@12952
#python ReportGenerator.py -O /home/Earth/sparonuz/DATA/report_trunk@12952/prova.pkl --dump-to-file 
