User Guide
==========

Supported models and platforms ids
----------------------------------

Ids used by the workflow to identify the model and platform.

Models:


* ``nemo``
* ``ecearth4``

Platforms:


* ``mn5``\ : BSC's Marenostrum 5 machine.
* ``hpc2020``\ : ECMWF's ATOS machine.

Dependencies
------------

Autosubmit
~~~~~~~~~~

The Automatic Performance Profiling uses Autosubmit as its workflow manager and therefore is needed to run it.

BSC-ES HUB
^^^^^^^^^^

In the hub you can load the following module:

.. code-block:: bash

  module load autosubmit/4.1.8-foss-2021b-Python-3.9.6

Other machines
^^^^^^^^^^^^^^

If Autosubmit is not installed in the machine you are planning to run the workflow you have to install it, you can check its `installation guide <https://autosubmit.readthedocs.io/en/master/installation/index.html>`_.

Create the experiment
---------------------

Then generate a new experiment id, replacing PLATFORM with one of the supported platforms ids and DESCRIPTION with the description of your experiment:

.. code-block:: bash

  autosubmit expid -min -H "PLATFORM" -d "DESCRIPTION" -repo "https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git" -b "master"

.. warning::
  Replace PLATFORM with one of the supported platform ids

Set the following environment variables to be able to run the following commands:

.. code-block:: bash

  model=MODEL
  expid=EXPID

.. warning::
  Replace MODEL with one of the supported models id and EXPID with the expid printed by the AS command

Once the experiment is created, it's time to configure the workflow. First, you have to navigate to the experiment root directory:

.. code-block:: bash

  cd /esarchive/autosubmit/${expid}

Run the following command to update ``conf/minimal.yml`` to use the AS configuration from the repository:

.. code-block:: bash

  sed -i "s/CUSTOM_CONFIG: .*/MODEL: ${model}\n  CUSTOM_CONFIG:\n    PRE:\n      \# General configuration\n      - \"%PROJDIR%\/autosubmit\/configuration\/common\/model\/%DEFAULT.MODEL%\/proj.yml\"\n      - \"%PROJDIR%\/autosubmit\/configuration\/common\/\"\n      \# Jobs configuration\n      - \"%PROJDIR%\/autosubmit\/configuration\/jobs\/jobs.yml\"\n      - \"%PROJDIR%\/autosubmit\/configuration\/jobs\/\"\n      - \"%PROJDIR%\/autosubmit\/configuration\/jobs\/model\/%DEFAULT.MODEL%\/\"\n      - \"%PROJDIR%\/autosubmit\/configuration\/jobs\/platform\/%DEFAULT.HPCARCH%\/\"\n      \# Member specific configuration\n      - \"%PROJDIR%\/autosubmit\/configuration\/tracing\/\"\n    POST: ~\/platforms_credentials.yml/" conf/minimal.yml

To configure the platform with your user create and edit ``~/platforms_credentials.yml`` with the platform id and your user, example:

.. code-block:: yaml

  hpc2020:
    USER: "HPC2020_USER"
  mn5:
    USER: "MN5_USER"
  mn5-login:
    USER: "MN5_USER"

Then create the experiment:

.. code-block:: bash

  autosubmit create ${expid}

Configure the workflow
----------------------

Members configuration
~~~~~~~~~~~~~~~~~~~~

You can configure what members to run in the ``proj/auto-performance-profiling/autosubmit/configuration/common/expdef.yml`` file by adding or removing the members id from the ``MEMBERS`` variable.

The four supported members ids are:

* ``CompilationEfficiency``\ : Runs the same configuration with different compilation flags and generates a table to compare them.
* ``HardwareBenchmarks``\ : Runs OSU and STREAM hardware benchmarks.
* ``WeakScaling``\ : Runs a weak scaling test and generates a scalability table. 
* ``StrongScaling``\ : Runs a strong scaling test and generates a scalability plot.
* ``Tracing``\: Traces the execution of the model and generates a report for:

  * User functions
  * PAPI counters
  * MPI calls
  * Paraver images
  * Dimemas images

Model specific configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once you decide what members to run, you can configure the jobs that they will run in the ``proj/auto-performance-profiling/autosubmit/configuration/common/model/${model}/proj.yml``.

Now check the specific wiki for each of the models to know how to configure them:


.. toctree::
   :titlesonly:

   Configure-NEMO
   Configure-ECE4


Common configuration
~~~~~~~~~~~~~~~~~~~~


Report configuration
^^^^^^^^^^^^^^^^^^^^

For report configuration (what will be shown and run) and hw benchmarks configuration, check the ``proj/auto-performance-profiling/autosubmit/configuration/common/common.yml`` file.

There you can configure:


* Report:

  * Author: Any string.
  * Title: String.

* HW Benchmarks:

  * OSU:

    * Enable/Disable: "True" or "False".
    * Set list of OSU test to run.
    * Processors configurations: YML integer list.

  * STREAM:

    * Enable/Disable.
    * Processors configurations.

* Tracing:

  * Paraver:

    * Enable/Disable PV views in the report.
    * List of views to report.
    * Subset of views to create a comparisson view.

  * Dimemas:

    * Enable/Disable PV views in the report.
    * List of views to report.

  * User Functions:

    * Enable/Disable User Functions in the report.
    * PAPI Counters:

      * Enable/Disable PAPI Counters in the report.
      * List of plots to show in the report.

    * Sampling:

      * Enable/Disable generating the function list through sampling or taking the list from ``cfg/trace/model/MODEL/extrae_functions.txt``.

  * Modelfactors:

    * Enable/Disable Modelfactors images in the report.

  * MPI:

    * Enable/Disable MPI profiling results in the report.

Extrae configuration
^^^^^^^^^^^^^^^^^^^^

The extrae.xml used by Tracing is configured through ``proj/auto-performance-profiling/autosubmit/configuration/tracing/extrae.yml``. 

The fields are named as in the Extrae XML file, you can check its documentation `here <https://tools.bsc.es/doc/html/extrae/xml.html>`_.

It is important that you replace the HOME variable with the path to the Extrae installation you will use.

Issues with ECE4
""""""""""""""""

For ECE4 you need to use an Extrae custom installation with ``--disable-instrument-io`` and ``--disable-instrument-dynamic-memory`` flags in order for it to work. You can use the following installation paths that are compiled using these flags:

* mn5: 

  - For IntelMPI: ``/gpfs/scratch/bsc32/bsc032333/extrae-4.2.5/build-impi-2021.10.0/install``

  - For OpenMPI: ``/gpfs/scratch/bsc32/bsc032333/extrae-4.2.5/build-ompi-4.1.5/install``

* hpc2020 (OpenMPI): ``/lus/h2resw01/hpcperm/c3rs/extrae-4.2.4/install/hpcx-openmpi-2.9.0``

Run the workflow
----------------

When you finish configuring the workflow, it's time to run it:

.. code-block:: bash

   nohup autosubmit run ${expid} &
  
.. warning::
  If you make any changes to the local configuration files, make sure that you rerun th synchronization job.