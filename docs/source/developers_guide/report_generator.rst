
ReportGenerator usage
=====================

Short guide on how to use the class:


* To create a report object just call the class with the name you want and start adding a section
  .. code-block:: python

      python ReportGenerator.py -O ../report.pkl --section-title Introduction --section-number 1 -T Introduction.txt
  You can give a number for the section which for the moment is being ignored. And add some text you've stored somewhere.
  .. code-block:: bash

     python ReportGenerator.py -O ../report.pkl --section-title "Hardware Benchmarks" --section-number 2
  This will add another section to the same object. To add a subsection just give the -s option
* 
  To add images or csv files use the appropriate flag, you can pass either a single file or a folder, the script will loop inside it and search for files with the .png or .csv extension respectively.

  .. code-block:: bash

       python ReportGenerator.py -O ../report.pkl -S "Hardware Benchmarks" -s "OSU Benchmark" --add-img images/OSU
       python ReportGenerator.py -O ../report.pkl -S "Hardware Benchmarks" -s "STREAM Benchmark" --add-csv images/STREAM/stream_48_fmt.csv

  If the file is a paramedir csv there is a small utility to format it (I don't assure in any way it works with files different from the one I tried). 
  Passing --c option will do the trick

  .. code-block:: bash

       python ReportGenerator.py -O ../report.pkl -S "MPI Profile" --add-csv  ./48_MPI_call_profile.pm --c

  For the images there is also the option to add a caption 

  .. code-block:: bash

        python ${latex_folder}/ReportGenerator.py -O report.pkl \
                                            -S "Scalability" \
                                            --add-img ${configuration_name}_scaling.png \
                                            --add-img-caption cfg/latex/text/captions/Scalability.txt\
                                            --add-csv ${configuration_name}_scaling.csv \
                                            -T cfg/latex/text/Scalability.txt

  ###### The new command 
  In the caption you can use the same variable defined in the param.cfg file. For example, let's say you want to put as a caption

  ..

     Scalability of ${model} model with ${configuration_name}.


  You can do this adding the param file as a newcommand:

  .. code-block:: python

        python ${latex_folder}/ReportGenerator.py -O report.pkl --add-newcommand param.cfg

  This ofc works also with custom variables files different from the param file.

* 
  When you're done adding sections and data you can specify title and authors

  .. code-block:: bash

     python ReportGenerator.py -O ../report.pkl --report-title "Report Nemo version 666"
     python ReportGenerator.py -O ../report.pkl --report-authors "O. Tinto Primis"
     python ReportGenerator.py -O ../report.pkl --report-authors "Stella V. Paronuzzi Ticco"

  Authors can be added at once, but also as above.

* There is a small utility to printout what we have added so far to the report:
  .. code-block:: bash

      python ReportGenerator.py -O ../report.pkl -I
  This will print to screen a sort of map of section/subsection and data added.
* Now if you want to generate the .tex file just dump the object to file with -d option:
  .. code-block:: bash

     python ReportGenerator.py -O  ./report.pkl -d
  If everything went fine, which I seriously doubt you should now have a .tex file, and 
  .. code-block:: bash

     pdflatex file.tex && evince file.pdf
  should open your report.

P.S.: In case you are using the script on MN4 facility, you have to 

.. code-block:: bash

   module load LATEX/20150523

in order to compile.
