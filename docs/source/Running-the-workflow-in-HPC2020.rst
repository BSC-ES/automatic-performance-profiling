
Creating the experiment
=======================

For now, AS workflows run in HPC2020 must be created and executed from the bsceshub (\ ``bsceshub02.bsc.es`` only machine available now).

:warning: **The first time you run autosubmit in HPC2020, follow this `guide <https://earth.bsc.es/gitlab/es/auto-ecearth3/-/wikis/Running-on-ECMWF-HPC2020>`_\ **\ , from the "Initial setup" section to the ``ecaccess-certificate-create`` command in the "Running experiment section".

If you have already done the initial setup, run the following:

.. code-block:: bash

   module load ecaccess-webtoolkit/6.3.1
   module load autosubmit/4.0.105-foss-2021b-Python-3.9.6
   module load Graphviz/2.50.0-GCCcore-11.2.0

Then create the experiment:

.. code-block:: bash

   autosubmit expid -min -H "hpc2020" -d "auto-performance-profiling" -repo "https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git" -b "ecearth4"

Go to the experiment root folder and replace the contents of ``conf/minimal.yml`` with:

**:warning: REPLACE a00a WITH YOUR EXPERIMENT ID**

.. code-block:: yml

   CONFIG:
     # Current version of Autosubmit.
     AUTOSUBMIT_VERSION: "4.0.105"
     # Total number of jobs in the workflow.
     TOTALJOBS: 20
     # Maximum number of jobs permitted in the waiting status.
     MAXWAITINGJOBS: 20
   DEFAULT:
     # Job experiment ID.
     EXPID: "a00a"
     # Default HPC platform name.
     HPCARCH: "hpc2020"
     CUSTOM_CONFIG:
       PRE:
         - "%PROJDIR%/autosubmit/configuration/common/proj.yml"
         - "%PROJDIR%/autosubmit/configuration/common/"
         - "%PROJDIR%/autosubmit/configuration/jobs/jobs.yml"
         - "%PROJDIR%/autosubmit/configuration/jobs/"
         - "%PROJDIR%/autosubmit/configuration/jobs/model/ecearth4/"
         - "%PROJDIR%/autosubmit/configuration/jobs/platform/hpc2020/"
       POST: "~/platforms_credentials.yml"
   project:
     PROJECT_TYPE: git
     PROJECT_DESTINATION: auto-performance-profiling
   git:
     PROJECT_ORIGIN: https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git
     PROJECT_BRANCH: ecearth4
     PROJECT_COMMIT: ""

Create the file ``~/platforms_credentials.yml`` to define your user id of the HPC platform. Example for HPC2020:

**:warning: The platform ids must coincide with the ones in the experiment conf file ``conf/platforms.yml``\ **

.. code-block:: yml

   PLATFORMS:
     hpc2020:
       USER: "c3XX"

Then, create the experiment:

**:warning: Replace EXPID with your experiment id**

.. code-block:: bash

   autosubmit create EXPID -v

Known issues
============

Paramedir segmentation fault
----------------------------

If you get a segmentation fault while running the Paramedir cutter, you have to change the tmp default Paraver folder, because by default it is the home directory and it will consume all the home quota. To fix that, you have to access the Paraver GUI and change the tmp directory in the preferences.

.. image:: uploads/e96acb00433df55507a78d955af3c4d4/Screenshot_20240305_095434.png
   :target: uploads/e96acb00433df55507a78d955af3c4d4/Screenshot_20240305_095434.png
   :alt: Screenshot_20240305_095434

