
Creating the experiment
=======================

Load the autosubmit module (>= ``4.0.87-foss-2015a-Python-3.7.3``\ ):

.. code-block:: bash

   module load autosubmit/4.0.87-foss-2015a-Python-3.7.3

To create the experiment run the following command in:

.. code-block:: bash

   autosubmit expid -min -H "marenostrum4" -d "auto-performance-profiling" -repo "https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git" -b "master"

Go to the experiment root folder and replace the contents of ``conf/minimal.yml`` with:

**:warning: REPLACE a00a WITH YOUR EXPERIMENT ID**

.. code-block:: yml

   CONFIG:
     # Current version of Autosubmit.
     AUTOSUBMIT_VERSION: "4.0.87"
     # Total number of jobs in the workflow.
     TOTALJOBS: 20
     # Maximum number of jobs permitted in the waiting status.
     MAXWAITINGJOBS: 20
   DEFAULT:
     # Job experiment ID.
     EXPID: a00a
     # Default HPC platform name.
     HPCARCH: "marenostrum4"
     CUSTOM_CONFIG:
       PRE:
         - "%PROJDIR%/autosubmit/configuration/common/proj.yml"
         - "%PROJDIR%/autosubmit/configuration/common/"
         - "%PROJDIR%/autosubmit/configuration/members/"
         - "%PROJDIR%/autosubmit/configuration/model/nemo"
       POST: "~/platforms_credentials.yml"
   project:
     PROJECT_TYPE: git
     PROJECT_DESTINATION: auto-performance-profiling
   git:
     PROJECT_ORIGIN: https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git
     PROJECT_BRANCH: master
     PROJECT_COMMIT: ""

Create the file ``~/platforms_credentials.yml`` to define your user id of the HPC platform. Example for Marenostrum 4:

**:warning: The platform ids must coincide with the ones in the experiment conf file ``conf/platforms.yml``\ **

.. code-block:: yml

   PLATFORMS:
     marenostrum0:
       USER: "bsc32XXX"
     marenostrum4:
       USER: "bsc32XXX"

Then, create the experiment:

**:warning: Replace EXPID with your experiment id**

.. code-block:: bash

   autosubmit create EXPID -v

Configuring the experiments
===========================

TODO

Running the workflow
====================

**:warning: Replace EXPID with your experiment id**

.. code-block:: bash

   nohup autosubmit run EXPID &

If the run has been successful, the report pdf should be in the experiment root folder.

Known issues
============

Paraver and Dimemas images
--------------------------

Because X11 is disabled for sbatch jobs in Marenostrum 4, Autosubmit can not run Paraver, therefore the images can not be generated. See `X11 issue <https://earth.bsc.es/gitlab/es/autosubmit/-/issues/544>`_.

As a temporary fix, I might add a script you will have to run manually.
