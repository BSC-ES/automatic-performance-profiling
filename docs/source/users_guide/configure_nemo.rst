Configure NEMO
=============

In order to configure NEMO and the tests the workflow will run, you have to update the configuration file ``proj/auto-performance-profiling/autosubmit/configuration/common/model/nemo/proj.yml`` located in your experiment root.

Configure the model
-------------------

The main variables to update in this config file are:

* ORIGIN: url with the git repository containing NEMO.
* BRANCH_LIST: tag of the version you want to run.
* ARCH_NAMES: list of arch files to compile. This arch files must be located in ``cfg/arch/PLATFORM/MODEL/`` and follow this pattern ``arch-ARCH_NAME.fcm``.
* TEST_STEPS: number of steps to run in the different scalability jobs.
* OUTPUT: enables or disables the output (TRUE/FALSE).
* RESOLUTION: resolution of the model.

.. code-block:: yaml

  # MODEL CONFIG
  MODEL:
    NAME: nemo
    COMPONENTS: [nemo]
    ORIGIN: https://forge.nemo-ocean.eu/nemo/nemo.git
    BRANCH_LIST: 4.2.1

    # Arch files prefixes to compile
    # The arch file has to be located in cfg/arch/PLATFORM/MODEL/
    # - For ecearth4: ARCH_NAME.yml
    # - For nemo: arch-ARCH_NAME.fcm
    ARCH_NAMES: [O1_prod, O3_prod, O3_trace]

  EXPERIMENT:
    RESOLUTION: orca1
    TEST_STEPS: 960
    OUTPUT: false

Configure the members
---------------------

The members configuration only has to be present only if they are activated in ``proj/auto-performance-profiling/autosubmit/configuration/common/expdef.yml``.

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
* PAPI_COUNTERS: Space separated string with the PAPI counters to trace, same id as returned by the command `papi_avail`.

.. code-block:: yaml

  TRACING:
    TIMESTEP_ZERO: false
    TRACE_STEPS: 32

    # CONFIG FOR USER FUNCTIONS SAMPLING
    USER_FUNCTIONS_PROC: 112
    USER_FUNCTIONS_THREADS: 4
    TRACE_N_FUNCTIONS: 40

    TEST_NAMES: [BENCH,   BENCH,   BENCH  ]
    NAMES:      [trace_1, trace_2, trace_3]
    PROCESSORS: [112,     224,     336    ]
    THREADS:    [4,       4,       4      ]
    TEST_CONFIG: BENCH
    ARCH_NAME: O3_trace


StrongScaling
^^^^^^^^^^^^^

The possible variables to configure for Strong Scaling are:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.
* TEST_CONFIG: NEMO test configuration to use.

.. code-block:: yaml

  # STRONG SCALING CONFIG
  STRONGSCALING:
    STRONGSCALING_PARAMETERS_ROOT: '%PROJECT_FLAGS.MODEL_CONFIG_FOLDER%/strongscaling'
    TEST_NAMES: [BENCH,   BENCH,   BENCH  ]
    NAMES:      [bench_1, bench_2, bench_3]
    PROCESSORS: [112,     224,     336    ]
    THREADS:    [1,       1,       1      ]
    TEST_CONFIG: BENCH
    ARCH_NAME: O3_prod

Weakscaling
^^^^^^^^^^^

The Weakscaling configuration differs from the rest, since the test names indicate the resolution and the processors are computed in runtime:

* BASE_PROCS: Processors of the base case.
* BASE_RESOLUTION: Resolution of the base case.

The next list variables have to be the same length:

* TEST_NAMES: List of resolutions to run for each test.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.
* RESOLUTION: List of NEMO supported resolution ran by each test. This is the setting that will be used to compute the number of processors based on the base case resolution.
* ARCH_NAME: Arch to be used to run the tracing model, it has to be defined in MODEL.ARCH_NAMES list.

.. code-block:: yaml

  # WEAKSCALING CONFIG
  WEAKSCALING:
    WEAKSCALING_PARAMETERS_ROOT: '%PROJECT_FLAGS.MODEL_CONFIG_FOLDER%/MultiExperiment/weakscaling'
    BASE_PROCS: 56
    BASE_RESOLUTION: orca1
    NAMES:      [orca1, orca025]
    TEST_NAMES: [orca1, orca025]
    PROCESSORS: [1,     1      ]
    THREADS:    [1,     1      ]
    RESOLUTION: [orca1, orca025]
    TEST_CONFIG: BENCH
    ARCH_NAME: O3_prod

CompilationEfficiency
^^^^^^^^^^^^^^^^^^^^^

The configuration of the compilation efficiency follows the same idea as the Weakscaling, the test names define what arch should each test be run with:

The next list variables have to be the same length:

* TEST_NAMES: List of the arch configs to run for each test, they have to be defined in MODEL.ARCH_NAMES.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.
* MODEL_RESOLUTION: Resolution with the test will run on.

.. code-block:: yaml

  # COMPILATION EFFICIENCY CONFIG
  COMPILATION_EFFICIENCY:
    COMPILATION_EFFICIENCY_PARAMETERS_ROOT: '%PROJECT_FLAGS.MODEL_CONFIG_FOLDER%/MultiExperiment/compilation_efficiency'
    # For compilation efficiency the arch name is taken from the test name
    TEST_NAMES: [O1_prod, O1_prod, O3_prod, O3_prod]
    NAMES:      [O1_112,  O1_224,  O3_112,  O3_224 ]
    PROCESSORS: [112,     224,     112,     224    ]
    THREADS:    [1,       1,       1,       1      ]
    TEST_CONFIG: BENCH
