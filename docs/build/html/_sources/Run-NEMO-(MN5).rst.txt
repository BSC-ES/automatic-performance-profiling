
From the hub, load the following module and create a new experiment:

.. code-block:: bash

   module load autosubmit/4.1.4-foss-2021b-Python-3.9.6

.. code-block:: bash

   autosubmit expid -H mn5 -d "exp description" -min

Then go to the experiment root directory and set the content of the ``conf/minimal.yml`` file to:

**:warning: REPLACE a000 WITH YOUR EXPERIMENT ID**

.. code-block:: yml

   CONFIG:
     # Current version of Autosubmit.
     AUTOSUBMIT_VERSION: "4.1.4"
     # Total number of jobs in the workflow.
     TOTALJOBS: 20
     # Maximum number of jobs permitted in the waiting status.
     MAXWAITINGJOBS: 20
   DEFAULT:
     # Job experiment ID.
     EXPID: "a000"
     # Default HPC platform name.
     HPCARCH: "mn5"
     CUSTOM_CONFIG:
       PRE:
         - "%PROJDIR%/autosubmit/configuration/common/proj.yml"
         - "%PROJDIR%/autosubmit/configuration/common/"
         - "%PROJDIR%/autosubmit/configuration/jobs/jobs.yml"
         - "%PROJDIR%/autosubmit/configuration/jobs/"
         - "%PROJDIR%/autosubmit/configuration/jobs/model/nemo/"
         - "%PROJDIR%/autosubmit/configuration/jobs/platform/mn5/"
   project:
     PROJECT_TYPE: git
     PROJECT_DESTINATION: auto-performance-profiling
   git:
     PROJECT_ORIGIN: https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git
     PROJECT_BRANCH: ecearth4
     PROJECT_COMMIT: ""

Then you can create the experiment:

.. code-block:: bash

   autosubmit create EXPID
