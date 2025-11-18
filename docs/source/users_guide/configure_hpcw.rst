Configure HPCW
==============

In order to configure HPCW NEMO and the tests the workflow will run, you have to update the configuration file ``proj/auto-performance-profiling/autosubmit/configuration/common/hpcw/nemo/proj.yml`` located in your experiment root.

Configure the model
-------------------

Main variables to update in the proj.yml:

* MODEL.NAME: model identifier (hpcw).
* MODEL.COMPONENTS: list of components required by this model (e.g. ``nemo``).
* MODEL.REPORT_COMPONENTS: subset of components to include in reports.
* MODEL.ORIGIN: repository URL to clone the model from.
* MODEL.BRANCH: branch or tag to use.
* MODEL.ARCH_NAMES: list of architecture build presets (used to pick arch files in ``cfg/arch/PLATFORM/MODEL/``).
* EXPERIMENT.TEST_CONFIG: predefined test configuration (e.g. orca025-medium).
* EXPERIMENT.TEST_STEPS: number of model steps for short tests.
* EXPERIMENT.OUTPUT: enable or disable model output (true/false).
* EXPERIMENT.RESOLUTION: same as TEST_CONFIG in this model.

.. code-block:: yaml

  # MODEL CONFIG
  MODEL:
    NAME: hpcw
    COMPONENTS: [nemo]
    REPORT_COMPONENTS: [nemo]
    ORIGIN: https://gitlab.dkrz.de/hpcw/hpcw.git
    BRANCH: v3.0
    ARCH_NAMES: [O1_prod, O3_prod, O3_trace]
  
  # EXPERIMENT CONFIG
  EXPERIMENT:
    # Current available HPCW test configurations: 
    #   - orca025-medium
    #   - orca1-like-small
    TEST_CONFIG: orca025-medium
    TEST_STEPS: 32
    OUTPUT: false
    RESOLUTION: "%EXPERIMENT.TEST_CONFIG%"

Configure the members
---------------------

The members configuration only has to be present only if they are activated in the EXPERIMENT.MEMBERS variable at ``proj/auto-performance-profiling/autosubmit/configuration/common/expdef.yml``.

Tracing
^^^^^^^

The possible variables to configure for Tracing are:

* TIMESTEP_ZERO: TRUE/FALSE, true if the model runs a timestep 0, false otherwise. Used by magiccut to cut the timestep trace right.
* TRACE_STEPS: Number of steps the model should run when tracing it.
* USER_FUNCTIONS_*: Variables used by the User Functions sampling script.

The next list variables have to be the same length:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.
* MODEL_RESOLUTION: Resolution with the test will run on.
* ARCH_NAME: Arch to be used to run the tracing model, it has to be defined in MODEL.ARCH_NAMES list.

Example:

.. code-block:: yaml

  # TRACE CONFIG
  TRACING:
    TIMESTEP_ZERO: false
    TRACE_STEPS: 32

    # CONFIG FOR USER FUNCTIONS SAMPLING
    USER_FUNCTIONS_PROC: 112
    USER_FUNCTIONS_THREADS: 4
    TRACE_N_FUNCTIONS: 40

    TEST_NAMES: [BENCH,   BENCH]
    NAMES:      [trace_1, trace_2]
    PROCESSORS: [112,     224]
    THREADS:    [4,       4]
    ARCH_NAME: O3_trace

Strong Scaling
^^^^^^^^^^^^^^

Strong Scaling test lists must have matching lengths.

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.

.. code-block:: yaml

  # STRONG SCALING CONFIG
  STRONGSCALING:
    TEST_NAMES: [BENCH,   BENCH,   BENCH]
    NAMES:      [bench_1, bench_2, bench_3]
    PROCESSORS: [112,     224,     336]
    THREADS:    [1,       1,       1]
    ARCH_NAME: O3_prod

Compilation Efficiency
^^^^^^^^^^^^^^^^^^^^^^

The test names of the Compilation Efficiency member define what arch should each test be run with:

The next list variables have to be the same length:

* TEST_NAMES: List of the arch configs to run for each test, they have to be defined in MODEL.ARCH_NAMES.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.

.. code-block:: yaml

  # COMPILATION EFFICIENCY CONFIG
  COMPILATION_EFFICIENCY:
    TEST_NAMES: [O1_prod, O1_prod, O3_prod, O3_prod]
    NAMES:      [O1_112,  O1_224,  O3_112,  O3_224 ]
    PROCESSORS: [112,     224,     112,     224    ]
    THREADS:    [1,       1,       1,       1      ]
