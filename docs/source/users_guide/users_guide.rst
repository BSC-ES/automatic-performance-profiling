Users Guide
===========

Welcome to the Automatic Performance Profiling Users Guide. This guide will help you to configure and run the workflow in your HPC platform.

Supported models and platforms IDs
----------------------------------

To be able to run the workflow you will need to use one of the supported models and platforms IDs.

The current supported models IDs are:

* ``nemo``: For the NEMO ocean model.
* ``ecearth4``: For the EC-Earth multicomponent earth system model.
* ``hpcw``: For the HPCW NEMO benchmark.
* ``monarch``: For the MONARCH atmospheric chemistry model.

And the supported platforms IDs are:

* ``mn5``\ : BSC's MareNostrum 5 machine.
* ``hpc2020``\ : ECMWF's ATOS machine.

Dependencies
------------

The Automatic Performance Profiling workflow depends on the following software:

* Autosubmit
* Ecaccess (only for ``hpc2020``\)


How to install Autosubmit
~~~~~~~~~~~~~~~~~~~~~~~~~

The Automatic Performance Profiling uses Autosubmit as its workflow manager and is therefore required to run it.

BSC-ES HUB
^^^^^^^^^^

In the hub you can load the following module:

.. code-block:: bash

  module load autosubmit/4.1.15-conda

Other machines
^^^^^^^^^^^^^^

If Autosubmit is not installed in the machine you are planning to run the workflow, you have to install it, you can check its `installation guide <https://autosubmit.readthedocs.io/en/master/installation/index.html>`_.

How to install Ecaccess
~~~~~~~~~~~~~~~~~~~~~~~

Ecaccess is the ECMWF software to access their HPC systems and is required to run the workflow in HPC2020.

Installation
^^^^^^^^^^^^

BSC-ES HUB
``````````

In the hub you can load the following module:

.. code-block:: bash

  module load ecaccess-webtoolkit/6.3.1

Other machines
``````````````

Follow the install instructions from the `Ecaccess documentation <https://confluence.ecmwf.int/display/ECAC/Releases+-+Web+Toolkit>`_.

Create the certificate
^^^^^^^^^^^^^^^^^^^^^^

Then run the following command to configure the credentials:

.. code-block:: bash

  ecaccess-certificate-create

Create the experiment
---------------------

Then generate a new experiment ID, replacing PLATFORM with one of the supported platforms IDs and DESCRIPTION with the description of your experiment:

.. code-block:: bash

  autosubmit expid \
    -min \
    -H "PLATFORM" \
    -d "DESCRIPTION" \
    --git_as_conf autosubmit/configuration/bootstrap.yml \
    -repo "https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git" \
    -b "master"

.. warning::
  Replace PLATFORM with one of the supported platform ids

Set the following environment variables to run the guide commands:

.. code-block:: bash

  model=MODEL

.. code-block:: bash

  expid=EXPID

.. warning::
  Replace MODEL with one of the supported models IDs and EXPID with the expid printed by the AS command

Once the experiment is created, it's time to configure the workflow. First, you have to navigate to the experiment root directory:

.. code-block:: bash

  cd /esarchive/autosubmit/${expid}

Run the following command to update ``conf/minimal.yml`` to use the AS configuration for the model you want to run:

.. code-block:: bash

   sed -i "/HPCARCH: .*/a \ \ MODEL: ${model}" conf/minimal.yml
   sed -i "s/^  PROJECT_DESTINATION: .*/  PROJECT_DESTINATION: auto-performance-profiling/" conf/minimal.yml

To configure the platform with your user, create and edit ``~/platforms_credentials.yml`` with the platform ID and your user, example:

.. code-block:: yaml

  hpc2020:
    USER: "HPC2020_USER"
  mn5:
    USER: "MN5_USER"
  mn5-login:
    USER: "MN5_USER"

Create EC-Earth4, HPCW, and NEMO experiments
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To create an experiment for EC-Earth4, HPCW, or NEMO run the following command:

.. code-block:: bash

  autosubmit create ${expid}

Create Monarch experiment
~~~~~~~~~~~~~~~~~~~~~~~~~

Monarch requires extra steps to create the experiment; first you need to clone the Automatic Performance Profiling repository by running the following command:

.. code-block:: bash

  autosubmit refresh ${expid}

Once Autosubmit has cloned the repository, copy an existing Auto-Monarch experiment by running the following command, replacing SRC_EXPID with the Auto-Monarch experiment ID you want to copy from:

.. code-block:: bash

  python3 proj/auto-performance-profiling/cfg/utils/monarch/copy_experiments.py \
      --src-expid SRC_EXPID \
      --current-expid ${expid}

.. warning::
  Check that the warnings about unapplied patches are not relevant to your experiment. If they are, please update the patches or create an issue in the `Automatic Performance Profiling <https://gitlab.earth.bsc.es/ces/hpc-for-es-team/automatic_performance_profiling>`_ repository.

The script takes the following parameters:

* ``--src-expid`` (``-s``): The source Auto-Monarch experiment ID to copy from.
* ``--current-expid`` (``-c``): The current experiment ID to copy to.
* ``--no-copy-source``: Copy only the autosubmit templates (to use only when rerunning the script).

Finally, create the experiment by running:

.. code-block:: bash

  autosubmit create ${expid}

Configure the workflow
----------------------

Tests configuration
~~~~~~~~~~~~~~~~~~~

The four supported performance tests IDs are:

* ``CompilationEfficiency``\ : Runs the same configuration with different compilation flags and generates a table to compare them.
* ``HardwareBenchmarks``\ : Runs OSU and STREAM hardware benchmarks.
* ``WeakScaling``\ : Runs a weak scaling test and generates a scalability table.
* ``StrongScaling``\ : Runs a strong scaling test and generates a scalability plot.
* ``Tracing``\ : Traces the execution of the model and generates a report for:

  * User functions
  * PAPI counters
  * MPI calls
  * Paraver images
  * Dimemas images

Each test is enabled/disabled by commenting or uncommenting the path to its jobs configuration file in the ``proj/auto-performance-profiling/autosubmit/configuration/bootstrap.yml`` file. Each test corresponds to one of the ``jobs-*.yml`` files loaded by Autosubmit.

The tests and their corresponding jobs configuration files are:

* ``StrongScaling``\ : ``jobs-strongscaling.yml``
* ``CompilationEfficiency``\ : ``jobs-compilationefficiency.yml``
* ``Tracing``\ : ``jobs-tracing.yml``
* ``WeakScaling``\ : ``jobs-weakscaling.yml``
* ``HardwareBenchmarks``\ : ``jobs-hwbenchmarks.yml``

For example, to disable the WeakScaling test, comment out its line in ``bootstrap.yml``:

.. code-block:: yaml

    # Disable/enable Hardware Benchmarks by commenting/uncommenting the following line
    - '%PROJDIR%/autosubmit/configuration/core/jobs/jobs-hwbenchmarks.yml'
    # Disable/enable Strong Scaling by commenting/uncommenting the following line
    - '%PROJDIR%/autosubmit/configuration/core/jobs/model/%DEFAULT.MODEL%/jobs-strongscaling.yml'
    # Disable/enable Compilation Efficiency by commenting/uncommenting the following line
    - '%PROJDIR%/autosubmit/configuration/core/jobs/model/%DEFAULT.MODEL%/jobs-compilationefficiency.yml'
    # Disable/enable Tracing by commenting/uncommenting the following line
    - '%PROJDIR%/autosubmit/configuration/core/jobs/model/%DEFAULT.MODEL%/jobs-tracing.yml'
    # Disable/enable Weak Scaling by commenting/uncommenting the following line
    # - '%PROJDIR%/autosubmit/configuration/core/jobs/model/%DEFAULT.MODEL%/jobs-weakscaling.yml'

.. note::

  Monarch does not support the WeakScaling test; it is disabled by default.

Model specific configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once you decide what tests to run, you can configure the jobs that the tests will run in the ``proj/auto-performance-profiling/autosubmit/configuration/user/model/${model}/proj.yml``.

Now check the specific wiki for each of the models to know how to configure them:

.. toctree::
   :maxdepth: 1

   configure_nemo
   configure_ece4
   configure_hpcw
   configure_monarch

Common configuration
~~~~~~~~~~~~~~~~~~~~

The common configuration is stored in the ``proj/auto-performance-profiling/autosubmit/configuration/user/common.yml`` file. It includes the configuration shared by all performance tests and models, such as the report configuration, the hardware benchmarks to run, and the tracing configuration.

Hardware benchmarks
^^^^^^^^^^^^^^^^^^^

The ``HW_BENCHMARKS`` section configures the hardware benchmarks to run. Both OSU and STREAM use a ``NAMES`` list and a ``PROCESSORS`` list of the same length; each position defines one benchmark run and the number of processors used for it.

OSU micro-benchmarks:

``HW_BENCHMARKS.OSU.ENABLED``
  Enable/Disable the OSU micro-benchmarks (``true``/``false``).

``HW_BENCHMARKS.OSU.SOURCE``
  URL of the OSU micro-benchmarks source tarball used to compile the benchmarks.

``HW_BENCHMARKS.OSU.TESTS``
  OSU benchmarks to run, as a list of binaries relative to the ``c/mpi/`` directory of the OSU root, e.g. ``pt2pt/standard/osu_multi_lat``.

``HW_BENCHMARKS.OSU.NAMES``
  Unique names for each OSU run, used as labels in the report.

``HW_BENCHMARKS.OSU.PROCESSORS``
  Number of processors used by each OSU run.

STREAM:

``HW_BENCHMARKS.STREAM.ENABLED``
  Enable/Disable the STREAM benchmark (``true``/``false``).

``HW_BENCHMARKS.STREAM.NAMES``
  Unique names for each STREAM run, used as labels in the report.

``HW_BENCHMARKS.STREAM.PROCESSORS``
  Number of processors used by each STREAM run.

Extrae configuration
^^^^^^^^^^^^^^^^^^^^

The extrae.xml used by Tracing is configured through the ``TRACING.EXTRAE`` section of ``proj/auto-performance-profiling/autosubmit/configuration/user/common.yml``.

The fields are named as in the Extrae XML file; you can check its documentation `here <https://tools.bsc.es/doc/html/extrae/xml.html>`_. Each instrumentation block (``MPI``, ``CALLERS``, ``USER_FUNCTIONS``, ``PAPI_COUNTERS`` and ``OPENMP``) has an ``ENABLED`` flag and, where needed, extra sub-options such as ``LEVELS`` or ``LIST``. For example, ``TRACING.EXTRAE.USER_FUNCTIONS.LIST`` points to the file with the list of user functions instrumented by Extrae, by default ``./extrae_functions_for_xml.txt``, which is created by the tracing job template. This is the list used when ``TRACING.AUTOMATIC_USER_FUNCTIONS.ENABLED`` is ``false``.

It is important that you replace the HOME variable with the path to the Extrae installation you will use. You can get the path of your Extrae installation by loading the Extrae module in the HPC platform and then running the following command:

.. code-block:: bash

   echo $EXTRAE_HOME

or if it is empty:

.. code-block:: bash

   echo $EXTRAE_DIR

Report configuration
^^^^^^^^^^^^^^^^^^^^

Report options
``````````````

``REPORT.TITLE``
  Title of the report (any string).

``REPORT.AUTHORS``
  Author(s) of the report (any string).

The remaining ``REPORT`` keys (``CONFIG``, ``NAME``, ``FOLDER`` and ``LOGO_PATH``) point to the LaTeX template and to the folder where the report is written and normally do not need to be changed.

Tracing report options
``````````````````````

The ``TRACING`` section selects which tracing analysis results are included in the report.

``TRACING.PARAVER.ENABLED``
  Enable/Disable Paraver images in the report (``true``/``false``).

``TRACING.PARAVER.CFGS``
  Space-separated list of Paraver views to include in the report, e.g. ``MPI_call p2p_size Average_IPC``. The available views can be checked in ``cfg/trace_analysis/paraver_configurations``.

``TRACING.PARAVER.COMPARE_CFGS``
  Subset of ``CFGS`` used to generate comparison views, e.g. ``MPI_call UserFunctions``.

``TRACING.DIMEMAS.ENABLED``
  Enable/Disable Dimemas images in the report (``true``/``false``).

``TRACING.DIMEMAS.CFGS``
  Space-separated list of Dimemas views to include in the report. The available views can be checked in ``cfg/trace_analysis/dimemas_configurations``.

``TRACING.USER_FUNCTIONS.ENABLED``
  Enable/Disable the user functions analysis in the report (``true``/``false``).

``TRACING.USER_FUNCTIONS.PAPI_COUNTERS.ENABLED``
  Enable/Disable the PAPI counter plots in the report (``true``/``false``).

``TRACING.USER_FUNCTIONS.PAPI_COUNTERS.PLOTS``
  Space-separated list of plots to generate for the user functions. Each element is a pair of PAPI counters separated by ``-``, e.g. ``PAPI_TOT_INS-PAPI_L1_DCM``. You can get the available PAPI counter IDs with the ``papi_avail`` command.

``TRACING.AUTOMATIC_USER_FUNCTIONS.ENABLED``
  Enable/Disable generating the user functions list by sampling the traced run. When disabled, Extrae takes the list from ``TRACING.EXTRAE.USER_FUNCTIONS.LIST`` (see :ref:`Extrae configuration`).

``TRACING.AUTOMATIC_USER_FUNCTIONS.MAX_FUNCTIONS``
  Number of functions kept in the generated list, sorted by average duration.

``TRACING.MODELFACTORS.ENABLED``
  Enable/Disable Modelfactors images in the report (``true``/``false``).

``TRACING.MPI.ENABLED``
  Enable/Disable the MPI profiling results in the report (``true``/``false``). This is independent of ``TRACING.EXTRAE.MPI``, which enables MPI tracing in the Extrae configuration.

Run the workflow
----------------

When you finish configuring the workflow, it's time to run it:

.. code-block:: bash

   nohup autosubmit run ${expid} &
  
.. warning::
   If you make any changes to the local configuration files (excluding Autosubmit YML files), make sure that you rerun th synchronization job.

.. _Known-Issues:
Known Issues
------------

There are not known issues at the moment, but if you find any, please report them at `roc.salvador@bsc.es <roc.salvador@bsc.es>`_.