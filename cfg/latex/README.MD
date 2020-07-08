# ReportGenerator usage
Short guide on how to use the class:
 - To create a report object just call the class with the name you want and start adding a section
   ```python
    python ReportGenerator.py -O ../report.pkl --section-title Introduction --section-number 1 -T Introduction.txt
   ```
   You can give a number for the section which for the moment is being ignored. And add some text you've stored somewhere.
   ```bash
   python ReportGenerator.py -O ../report.pkl --section-title "Hardware Benchmarks" --section-number 2 
   ```
   This will add another section to the same object. To add a subsection just give the -s option
 - To add images or csv files use the appropriate flag, you can pass either a single file or a folder, the script will loop inside it and search for files with the .png or .csv extension respectively.
   ```bash
     python ReportGenerator.py -O ../report.pkl -S "Hardware Benchmarks" -s "OSU Benchmark" --add-img images/OSU
     python ReportGenerator.py -O ../report.pkl -S "Hardware Benchmarks" -s "STREAM Benchmark" --add-csv images/STREAM/stream_48_fmt.csv
   ```
   If the file is a paramedir csv there is a small utility to format it (I don't assure in any way it works with files different from the one I tried). 
   Passing --c option will do the trick
   ```bash 
     python ReportGenerator.py -O ../report.pkl -S "MPI Profile" --add-csv  ./48_MPI_call_profile.pm --c
   ```
 - When you're done adding sections and data you can specify title and authors
   ```bash
   python ReportGenerator.py -O ../report.pkl --report-title "Report Nemo version Piriri"
   python ReportGenerator.py -O ../report.pkl --report-authors "O. Tinto Primis"
   python ReportGenerator.py -O ../report.pkl --report-authors "Stella V. Paronuzzi Ticco"
   ```
   Authors can be added at once, but also as above.
 - There is a small utility to printout what we have added so far to the report:
   ```bash
    python ReportGenerator.py -O ../report.pkl -I
   ```
   This will print to screen a sort of map of section/subsection and data added.
 - Now if you whant to generate the .tex file just dump the object to file with -d option:
   ```bash
   python ReportGenerator.py -O  ./report.pkl -d
  ```
If everything went fine, which I seriously doubt you should now have a .tex file, and 
```bash
pdflatex file.tex && evince file.pdf
```
should open your report.
