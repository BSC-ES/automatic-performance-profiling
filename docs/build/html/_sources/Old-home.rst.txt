.. role:: raw-html-m2r(raw)
   :format: html


The tool
========

This tools, has been developed by O. Tintó Prims and S.V. Paronuzzi Ticco, as an attempt to give the user a way to profile codes in a systematic way. 
During the development we tried not to depend too much on the model we were profiling (NEMO), nor on the system we were using (Marenostrum 4 HPC facility).
In particular we tried not to use any hardcoded path to sources, unless were our own sources (script which can be found and downloaded in this or other gitlab projects).

The reason
==========

Every time we perform small (or big) changes in our code; every time we change the platform on which we run our simulations; every time we change compilation's flag, we should ask ourselves: which is the impact of these changes on the performance of the model?
A series of test can answer this question.
If the way of running these tests were automatized the answer would be quicker.
The answer would have a smaller probability of containing errors.
The probability that we want to ask ourselves these questions in first place ... would be bigger.

TL;DR
-----

These are the few steps you really need to perform in order to get a report. 
First you ssh into MN4 on login0, then do the following:

.. code-block:: bash

         git clone https://earth.bsc.es/gitlab/ces/nemo_performance_profile.git
         cd nemo_performance_profile
         ./run_analysis.sh

This command will create a folder, ``run_dir``\ , whit tree subfolders in it:


* hardware_benchmarks
* MultiexperimentRuns which in turns will contain:

  * compilation_efficiency
  * weakscaling

* strongscaling

In those folders around 16 jobs will be submitted to the queue system, by default on ``debug`` (where allowed). **You can specify a different queue** for all the jobs running instead:

.. code-block:: bash

      ./run_analysis.sh bsc_es

After running all necessary tests it  will create a report and should directly open it for display. `Here <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/-/wikis/Last-version-of-the-report>`_ an example of how it should look like.

A couple of things that will make your life simpler running the analysis:


* enable passwordless access to your gitlab account
* before running the script, open a wxparaver graphic interface, and uncheck
  -> Preferences->Global->Behaviour->"Allow only one running instance"

**Now if you want really understand what's going on, you need to read the long version ...**

The theory
==========

As said you clone the project on a login node with connection, and enter the nemo_performance_profile folder,
You run the command 

.. code-block::

   ./run_analysis.sh

this produces a pdf with a series of plots and tables in it. You have your analysis.

What really happens
===================

You take a look at the run_analysis script, and see that there are many different ``make`` commands, with a path to a parameter files.
If you open the Makefile you will see what the targets are actually doing. Suppose you want to run one of these targets, for example you give the command ``make scalability``. The first thing that happens is that you get an error

.. code-block::

   Makefile:24: *** Please load the environment sourcing load_env.sh file.  Stop.

The error gives you a hint on what went wrong: you haven't loaded the proper environment through the command:

.. code-block::

   source load_env.sh

This is a bash script which loads some modules, and sets some paths, and is the first thing done in the analysis script.
Let's take a look at it, line by line:

The load_env.sh script
~~~~~~~~~~~~~~~~~~~~~~

The first line loads all the module needed **on the MN4 machine**

.. code-block::

   source cfg/env/MN4/environment.env

If you need some other modules, create another file, and source the new file instead.
The second line just makes all the python scripts work

.. code-block::

   export PYTHONPATH=$PYTHONPATH:$(pwd)

Then there are the line that generated the error you got at the beginning

.. code-block:: bash

   ssh_id=`echo ${SSH_CONNECTION} | awk '{print $2}'`
   touch .${ssh_id}.env_loaded
   trap 'rm .'${ssh_id}'.env_loaded' EXIT

They create a hidden file, with the ID of your ssh connection.
The makefile searches  for it, and if not present it fails. Also the file is removed when you exit the ssh connexion. 
So, if you want to close the ssh shell while running the tool, remove the last line, or the corresponding check in the Makefile

.. code-block:: makefile

   # Check environment is loaded
   ####################################################
   $(eval ssh_id := $(shell echo ${SSH_CONNECTION} | awk '{print $$2}'))
   ifeq ("$(wildcard .$(ssh_id).env_loaded )","")
     $(error Please load the environment sourcing load_env.sh file)
   endif

The last line converts the parameter file to something that can be sourced in a bash script.

.. code-block::

   python cfg/target/ConvertParamFile.py -p param.cfg  -o cfg/target/param_bash.cfg

This bring us to ...

The parameter file
~~~~~~~~~~~~~~~~~~

If you opened the ``run_analysis.sh`` script, you saw that we pass a parameter file to the make command. This file is sourced both in the Makefile, and in the scripts for the target.
So this is the place where to put all the variables the target you specified in the ``experiment_recipes`` variable.
Various example can be found in the folder ``configurations``. If you write you own param file **I warmly invite you to add it there**\ , for the future you to know how you got those beautiful results!

It can contain variables used in the Makefile, that are generic, or variables that are model specific and are used in your custom script.
Taking a look at the `\ ``param.cfg`` <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/snippets/69>`_ file you see that the parameter list  can be splitted in two: the model specific parameters and the ones which are not.

The following are model independent:


* model: used as a name for some output file, and to search for the model specific targets (See later)
* trace_steps: number of steps for the model when extrae is used. 
* test_steps: number of steps used for scalability test.
* number_of_processes: list of numbers that contains the N of cores at which the scalability test is run, and the traces are taken
* processes_per_node: if you want to use full nodes, there is no need to specify this one
* experiment_recipes: list of targets you want to run with this specific analysis
* osu_tests: name of the OSU test one wants in the report. `Here <http://mvapich.cse.ohio-state.edu/benchmarks/>`_ the available list.
* main_folder: path **inside ``run_dir``\ ** where the main folder will be cloned and the experiment target will run

It is clear then, that, for example, the way of enforcing the number of steps on the model has to be hardcoded somewhere.
Let's see how to enforce this kind of information

The target folder
~~~~~~~~~~~~~~~~~

Let's see what happens when we run the command

.. code-block:: bash

   make inidata

This is the command that prepares all the data needed for your model to run.
Of course this can not be general, and depends on the model. Take a look at what the makefile is doing:

.. code-block:: makefile

   # Recipes to prepare inidata
   inidata:
           # Download data, put it in inidata and remove write permissions to avoid undesired modifications
           mkdir $@
           ${cfg}/target/model/${model}/inidata.target

First of all, we see that the variable we defined in the param file is used here to determine the path of the script ``inidata.target``\ , which will set up the data.

This highlights the structure of the makefile: usually a target calls a script, stored in the cfg/target folder which will execute some code to perform a task. 
Inside the ``target`` folder there is the ``model`` folder: all the nemo specific scripts are stored there. **If you want to set up scripts for a new model** just create a new folder with your model's name inside the ``target`` folder, copy all the scripts and modify the code in order to work with your model.

Let's take a look now to a (more) generic target

.. code-block:: makefile

   # Recipes to prepare functions file for tracing
   functions_dir/extrae_functions.txt: bin/${model}_trace.exe bin/xios_server.exe
       ${MAKE} $(@D)/.inidata.done
       ${cfg}/target/model/${model}/functions_dir.target $(@D)
       python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/function.slurm \
                                        --set-time  120 \
                                        --set-core $(word 1, ${number_of_processes}) \
                                        --set-core-per-node ${processes_per_node} \
                                        --job-name $(@D) \
                        --set-queue $(slurm_queue)
       python cfg/slurm/SlurmJobCreator.py --file-name $(@D)/function.slurm \
                                               --set-workload ${cfg}/target/functions_dir.target bin/${model}_trace.exe

       sbatch --wait --chdir $(@D) $(@D)/function.slurm

It creates the list of functions we want to profile with extrae. This target is divided into a custom part and a `part that is model independent <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/-/wikis/Generate-the-extrae_functions.txt-in-a-generic-way>`_.
Plus we see for the first time the `SlurmJobCreator <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/-/wikis/The-SlurmJobCreator-class>`_ class.
Both deserve an explication, especially the second one can be of interest: it is used throughout the whole Makefile to create jobs and submit them to the queue system: we can choose the slurm parameters and the things that have to be run in the job.
For sake of simplicity they are explained on dedicated pages. Here I will just remark that if you run 

.. code-block:: bash

   make target -slurm_queue=bsc_es

All the jobs submitted by this command will be on the ``bsc_es`` queue, because of the interaction with the SlurmJobCreator (ofc it works with all the valid queue's name).

The workflow
~~~~~~~~~~~~

Now that we saw what a target is, and how it can be adapted to a new model, let's explain more in general which is the workflow, starting from the one we run in the run_analysis.sh: ``make experiment``. 

experiment
##########

This target looks inside the param file defined on command line, and runs what it is stored in the ``experiment_recipes`` variable. It loops through its values and builds all the targets inside the main_directory specified.

.. code-block:: makefile

   # Experiment recipes specified in param.cfg file
   experiment:
           for recipe in ${experiment_recipes} ; do \
                   echo $${recipe} ; \
                                   [ ! -d ${main_folder_fullpath} ] && git clone . ${main_folder_fullpath} ;\
                                   cp ${parameters_file} ${main_folder_fullpath}/param.cfg ;\
                                   cd  ${main_folder_fullpath} ;\
                                   source ./load_env.sh ;\
                                   cd - ;\
                                   $(MAKE) -C ./${main_folder_fullpath} parameters_file=param.cfg slurm_queue=${slurm_queue} $${recipe} ; \
           done

We need to copy the parameter file in the new folder and overwrite the original variable ``parameter_file``\ , because due to the change of directory it points to a non valid path.
The ``experiment_recipe`` variable can specify any of the target in the makefile, but usually points to an array of targets, as strongscaling or hardware_benchmarks.
This in turns will depend on other targets. Let's explain the most important.

In the run_analysis.sh script the analysis is divided in 4  part by 4 different parameter files:


* hardware_benchmark
* strongscaling
* Multiexperiment

  * weakscaling
  * compilation efficiency
    They are really array of targets, and if you look into the makefile you will see which are their dependency.

hardware_benchmarks
###################

The `STREAM <https://github.com/jeffhammond/STREAM>`_ benchmark is downloaded and compiled. Then

.. code-block:: bash

   #!/bin/bash
   for number_of_cores in  01 02 04 08 16 32 48
   do
     export OMP_NUM_THREADS=${number_of_cores}
     ./stream > stream_${number_of_cores}.txt
   done

With the `OSU <http://mvapich.cse.ohio-state.edu/benchmarks/>`_ a list of the test run can be put in the  param file, under the ``osu_tests`` variable

strongscaling
#############

With this aim let's take a look at the ``strong_scaling`` target: it consists of a series of make command. The hierarchy here is important, since some of the target are not serial (like scalability and trace_cut) and have the same dependency (inidata). They don't have any explicit or logical interdependence, so if not stated explicitly make would attempt a parallel build, causing a possible race condition when building common target. (ask for info, I know this is confusing).
For more details about parallel makefiles you can also have look at the `official documentation <https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html>`_

.. code-block::

   ############### TARGET FOR PARALLEL MAKE
   strong_scaling:
           ${MAKE} scalability
           ${MAKE} trace_cut
           ${MAKE} modelfactors paraver_images dimemas_experiments
           ${MAKE} paradim_experiments

This targets will, of course depend on an executable of the model, so firs we look at the source target.

sources
#######

In the NEMO case, we download the sources (nemo_source) from the git mirror and copy arch files where they are due.

.. code-block::

   ####################################################
   # The sources are prepared
   %_source:
           ${cfg}/target/model/${model}/$*_source.target ${cfg}

   ####################################################
   # Recipe to compile different model versions
   # The subscript indicates the version that we are compiling (vanilla, trace)
   bin/${model}_%.exe: ${model}_source
           mkdir -p $(@D)
           ${cfg}/target/model/${model}/${model}_exec.target $* $@ $<

Of course this script (nemo_exec.target) is maybe the one that most depend on the model you are using.
Now that we have the sources and the input files (we already explained the ``inidata`` target) we can use them.

scalability
###########

The scalability target is used to get the scalability curve. It will run as many tests as the number of cores specified in the param.cfg file, and for the number of timesteps you specified in the test_steps variable.

.. code-block:: makefile

   SCALABILITY=$(foreach var, $(number_of_processes), test_$(var)/test.slurm)
   scalability:  bin/${model}_vanilla.exe bin/xios_server.exe inidata
           make -j${cores} $(SCALABILITY)

That's how we enforce the parallelism inside the target.

trace_experiments
#################

Run the ${model}_trace.exe with Extrae to generate the traces. Again it will produce contemporary as many traces as the N of cores specified for the number of timesteps you specified in the trace_timestep variables.

paraver_images
##############

Runs all the Paraver configurations stored in ``${analysis_tools}/paraver_configurations`` folder. It produces the images and does a little postproc to rename them in a readable way and paste the proper legend. Take a look at `this Issue <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/-/issues/40>`_ to know how the function legend is created.

dimemas_experiments
###################

The traces generated in the previous step  are cut with the `magiCut <https://earth.bsc.es/gitlab/ces/magiccut>`_ script: please note that the numpy branch is used here, since the version in the master branch is slow, and when traces are taken on some thousand of cores, fails.
When the trace is cut, and converted into .dim, dimemas is run with all the configurations stored in ``${analysis_tools}/dimemas_configurations``\ , then the results will be analyzed looking at how the Userfunction view changes, with the different configurations.
To change view change the line 

.. code-block:: sh

   # Check how the function view changes with the different dimemas traces
   paraver_cfg=` readlink -f cfg/trace_analysis/cfgs/UserFunctions.cfg`

inside the dimemas_images.target

paramedir_experiments
#####################

The paramedir configurations stored in\ ``${analysis_tools}/paramedir_configurations`` are run on the cutted trace: they are histograms which store data for each and every function in the extrae list.

paradim_experiments
###################

Once the dimemas traces are generated we use paramedir to get some more info.
**NB** For the moment this info are not used in the report

MultiExperiments Folder
^^^^^^^^^^^^^^^^^^^^^^^

Looking at the run_analysis we see that there are parameters file stored in a folder named MultiExperiment. In this folder are stored configuration files for experiment that need to clone the project more than once.

Suppose for example that we want to change the default compilation flags, and see what is the impact in the performance. We decide that looking at the SYPD is enough to have a clue on what's going on.
We will have to:


* Create **\ *N*\ ** different parameter files, which enforce different compilation flags 
* Having the ``source`` target to know how to enforce the different compilation flags
* Specify a different ``main_folder`` in different parameter file
* Specify the same target inside all the different parameters files

  * scalability 
  * process_json.slurm

* Have a mean to analyze the data (use the ``comparator.py``\ )

The same will be with a weakscaling, the only difference being that instead of changing the compilation flags, we are changing the size of the domain. So probably we will need to put a parameter in the configuration file that specifies which is the desired domain, and in turn the ``inidata`` will have to know how to enforce this specification when running the scalability test.

The data analysis targets
~~~~~~~~~~~~~~~~~~~~~~~~~

In the second part of the ``run_analysis`` script, we give the Makefile commands to produce a report. In order to do so we need to analize the data collected. After we produced the scaling, take the traces, analize it with dimemas and paramedir, we need to process these data, and put them in a format accessible to the user. For this to happen there are two target, one that produces a json, with all the info from the tests, and another one that analizes the json.

${configuration_name}.json
##########################

This target can be executed once all the traces and test have finished.

.. code-block:: makefile

   python cfg/parser/collector.py --input-files test_*/*.timing trace_*/*pm dimemas_traces/*dm \
                                          --output-file ${configuration_name} \
                                          --param-file param.cfg

It is a python script, which takes as input timing files from the scaling tests, paramedir and dimemas traces, plus the param file, so it knows some variables without the need of giving too much input parameters.
None of these inputs are mandatory, but at least one should be present for the script to work.
The script basically issues an objinstance, of class TimingInformation,  defined in the file ``parser.py`` and with the following structure:

.. code-block:: python

   class TimingInformation:
       """
       Class to store the information of one experiment in a nested dictionary
       The dictionary stored at .data includes the following information (the values between '' are the actual keys).

       case (number of processes used)
       |---'Communication':
       |   |---'collective_pct'
       |   |---'collective_time'
       |   |---'computing_time'
       |   |---'p2p_pct'
       |   |---'p2p_time'
       |   |---'sypd'
       |   |---'total_time'
       |
       |---'FunctionInfo'
       |   |--- function_name (the name of the function)
       |       |--- 'CPU Time(%)'
       |       |--- 'CPU Time(s)'
       |       |--- 'CPU/Elap'
       |       |--- 'Elap. Time(%)'
       |       |--- 'Elap. Time(s)'
       |       |--- 'Freq'
       |       |--- 'Max elap(%)'
       |       |--- 'Min elap(%)'
       |
       |---'ProcessInfo'
       |   |--- process_id (the number of the process 0 or 45 for example)
       |       |--- 'CPU Time(s)'
       |       |--- 'Elapsed Time(s)'
       |       |--- 'Ratio CPU / Elapsed'
       |---'TimeStepTime'
       |   |--- (average, standard deviation) # (a tuple with the actual values)

Depending on the input given, the class will call a series of functions (parse_paramedir_files, parse_dimemas_files, parse_timing_files, load_param) to load and store the info recollected during the runs. Then all the info are saved to a json file, with the name of the configuration.

.info_report.done
#################

The reporter.py is the script that produces the actual images and csv files that eventually appears in the report. It takes as input the json file name and the names for the outputs that will be produced:

.. code-block:: python

   .info_report.done: ${configuration_name}.json
           python cfg/parser/reporter.py \
                                       -j ${configuration_name}.json \
                                       --sypd-plot ${configuration_name}_scaling.png \
                                       --sypd-file ${configuration_name}_scaling.csv \
                                       --csv-folder function_csv \
                                       --most_expensive_function_summary most_expensive_function_summary.csv \
                                       --L3_IPC_scatterplot L3_vs_IPC.png \
                                       --dimemas-file dimemas.csv \
                                       --tracking-folder tracking

Let's go through to output one by one:


* spyd-plot: is the scaling plot
* spyd-file: reports the numbers used to create the plot
* 
  csv-folder: inside this folder a csv file per function is created with

   | resources | speedup | efficiency |
   | --------- | ------- | ---------- |
   | Original * N\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>`   | speedup\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>`   |       efficiency\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>`    |
   | Original * N\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>`   | speedup\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>`   |       efficiency\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>`    |

* 
  most_expensive_function_summary: the list of the 10 most expensive function for each test run

* L3_IPC_scatterplot: for the most expensive functions, a plot of L3 total cache misses vs the total useful Instruction per Cycle. The N of cores decreases increasing the cache misses

  .. image:: uploads/5a789b56a776609d46dea079ce380adb/L3_vs_IPC.png
     :target: uploads/5a789b56a776609d46dea079ce380adb/L3_vs_IPC.png
     :alt: L3_vs_IPC

* 
  dimemas-file: csv files 

   | Cores | Bandwidth | Coupling | Latency | Original |
   | ----- | --------- | -------- | ------- | -------  |
   | N\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>` | Bdw\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>` | Coupling\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>` | lat\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>` | orig\ :raw-html-m2r:`<sub>`\ 1\ :raw-html-m2r:`<sub>`\ |
   | N\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>` | Bdw\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>` | Coupling\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>` | lat\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>` | orig\ :raw-html-m2r:`<sub>`\ 2\ :raw-html-m2r:`<sub>`\ | 

* 
  tracking-folder: the function ``function_information_from_paramedir_outputs`` (curation.py) is called, and all the info are stored in two separated folder: 


  * 
    MPI: all the MPI function used called inside the function

    | Cores | Outside_MPI | MPI_Recv | MPI_Isend | MPI_Wait | ... |
    | ----- | ---------   | -------- | ------- | -------  | ---|
    | ... | ... | ... | ... | ... |

  * 
    counters: the counters stored for this function

    | Processes | Instructions | Cycles | IPC | Time(ms) |
    | --------- | ------------ | ------ | --- | -------- | 
    | ... | ... | ... | ... | ... |

After the data analysis
~~~~~~~~~~~~~~~~~~~~~~~

As you understood, the only format suitable for storing the results are pictures and csv. In facts these are the only formats accepted from the ReportGenerator python class.
For more details check the `detailed description <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/-/wikis/The-ReportGenerator>`_\ , here we will just take a look at the  report target

.. code-block:: bash

   report_file=$1
   parameters_conffile=$2
   report_conffile=$3

   source ${report_conffile}
   # Copy the report in the appropriate folder
   report_name=${report_file%.*}
   cp ${report_file} report/
   #python ${latex_folder}/ReportGenerator.py -O ${report_file} --section-title "Introduction" --section-number 1 -T Introduction.txt
   python cfg/latex/ReportGenerator.py -O report/${report_file} --add-newcommand ${parameters_conffile}
   python cfg/latex/ReportGenerator.py -O report/${report_file} --report-title "${title}"
   python cfg/latex/ReportGenerator.py -O report/${report_file} --report-authors "${authors}"
   # Create the tex file
   python cfg/latex/ReportGenerator.py -O report/${report_file} --dump-to-file
   # Compile the report
   cd report; module load LATEX/20150523; pdflatex ${report_name}.tex && pdflatex ${report_name}.tex && evince ${report_name}.pdf

Trying to be brief takes the folder name, authors  and the title as input, generates the .tex file, and compiles it (twice, since there is the bibliography).
This brings this documentation to its last chapter

Notice to mariners
------------------

This tool has been developed for a specific model on a specific platform (almost entirely from a specific person), with the aim of being general. This of course does not mean that you can use it with a model that is not Nemo without modifying the code. This is a list
of things that, in my opinion, need to be changed / taken care of before being able to use the tool. (They are not listed in any specific order)

Recursive make
##############

Inside the makefile many of the target call a make command, it should be changed into a $(MAKE) command.It is straightforward but I have not had the time to check if brakes something.  

The dependency from the timing files
####################################

These files are specific of Nemo, nevertheless we use them for producing the JSON file, and in turn we analyze them for producing pictures or statistics.
The easiest thing would be to remove the analysis of the files in the reporter class, or at least make it optional.
Another thing you can do is take a look at what info it gives, and check if you can extract the same from your code.

The magicCut
############

This tool has been tested just with NEMO, and I don't know (nor Oriol, the author of the tool, does) how it would behave with other models.
Is based on the idea of having a timestep structure in the code. The tool will guess which is the first function called, and using this as a marker for the timesteps length, determines the best of them and cuts it using paramedir.
This implies a lot of conditions: 


* your code is supposed to have even steps
* the function called are more or less always the same
* ... other things that do not occur to me right now.

The only thing here is: try to use it, and when it fails contact me or Oriol if you can't/don't have the time to figure out yourself what went wrong. Plus I don't think this tool has a manual.

Paraver images (see `Issue#41 <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/-/issues/41>`_\ )
###########################################################################################################

I have a `branch <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/-/tree/x11>`_ where the changes to the paraver files are already implemented. Once support resolves my problem they can be put in the trunk

The parameter file conversion
#############################

When we source the load_env.sh script the param.cfg file gets converted from a python script. **The converted file is the one sourced from the targets!**. This means that, if you change something in the param file, you should also regenerate the converted one, i.e. source again the load_env.sh bash script.
I know this is manual and, by its nature, very error prone.

Since I was often forgetting this, I added the converted files among the files deleted every time a ``make clean`` is issued. 
But if you delete the file and then forget to recreate it, strange errors may appear ...
Long story short: add a check in your targets for this file to exist. I did not, my bad.

The folder in cfg
#################

There is a bit of a mess in the folders ordering: probably the folder ``trace``\ , ``trace_analysis``\ , ``generate_func_list`` should be merged into a single one, with a better name. You have to take into account that before taking the traces, we need to copy the content of ``cfg/trace`` folder inside the trace folder. So, **be careful** when merging.

Remove the XIOS dependency
##########################

Somewhere along the makefile there is an hardcoded dependency to XIOS,like for example in the ``function_dir`` target: this should be removed.
Right now we are doing with this dependency a very nasty thing: we put the path to a folder in Oriol's home, where he has the exec instead of actual compilation instructions. It is dire, I know.
