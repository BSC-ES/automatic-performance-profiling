Configure NEMO
==============

In order to configure NEMO and the tests the workflow will run, you have to update the configuration file ``proj/auto-performance-profiling/autosubmit/configuration/user/model/nemo/proj.yml`` located in your experiment root.

Configure the model
-------------------

The main variables to update in this config file are:

* ORIGIN: URL of the git repository containing NEMO.
* BRANCH: tag of the version you want to run.
* XIOS: configuration of the XIOS source that is cloned and compiled together with NEMO:

    * XIOS.ORIGIN: URL of the git repository containing XIOS.
    * XIOS.BRANCH: branch or tag of XIOS to check out; it must be compatible with the NEMO version selected above.

* ARCH_NAMES: list of arch files to compile. These arch files must be located in ``cfg/arch/PLATFORM/MODEL/`` and follow this pattern ``arch-ARCH_NAME.fcm``.
* TEST_STEPS: number of steps to run in the different scalability jobs.
* OUTPUT: enables or disables the output (TRUE/FALSE).
* RESOLUTION: resolution of the model.

.. code-block:: yaml

  # MODEL CONFIG
  MODEL:
    NAME: nemo
    COMPONENTS: [nemo]
    ORIGIN: https://forge.nemo-ocean.eu/nemo/nemo.git
    BRANCH: 4.2.1

    XIOS:
      ORIGIN: https://gitlab.in2p3.fr/ipsl/projets/xios-projects/xios.git
      BRANCH: xios-2.5.x

    # Arch files prefixes to compile
    # The arch file has to be located in cfg/arch/PLATFORM/MODEL/
    # - For ecearth4: ARCH_NAME.yml
    # - For nemo: arch-ARCH_NAME.fcm
    ARCH_NAMES: [O1_prod, O3_prod, O3_trace]

  EXPERIMENT:
    RESOLUTION: orca1
    TEST_STEPS: 960
    OUTPUT: false

Configure the tests
---------------------

The tests configuration only has to be present if they are activated by commenting/uncommenting the path to their jobs configuration file in the ``proj/auto-performance-profiling/autosubmit/configuration/bootstrap.yml`` file.

Tracing
^^^^^^^

The possible variables to configure for Tracing are:

* TIMESTEP_ZERO: TRUE/FALSE, true if the model runs a timestep 0, false otherwise. Used by MagicCut to cut the trace at the right timestep.
* TRACE_STEPS: Number of steps the model should run when tracing it.
* USER_FUNCTIONS_*: Variables used by the User Functions sampling script.

The following list variables have to be the same length:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.
* MODEL_RESOLUTION: Resolution on which the test will run.
* ARCH_NAME: Arch to be used to run the tracing model; it has to be defined in the MODEL.ARCH_NAMES list.

.. code-block:: yaml

  TRACING:
    TIMESTEP_ZERO: false
    TRACE_STEPS: 32

    # CONFIG FOR USER FUNCTIONS
    USER_FUNCTIONS_PROC: 112
    USER_FUNCTIONS_THREADS: 4

    TEST_NAMES: [BENCH,   BENCH,   BENCH  ]
    NAMES:      [trace_1, trace_2, trace_3]
    PROCESSORS: [112,     224,     336    ]
    THREADS:    [4,       4,       4      ]
    TEST_CONFIG: BENCH
    ARCH_NAME: O3_trace


Strong Scaling
^^^^^^^^^^^^^^

The possible variables to configure for Strong Scaling are:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.
* TEST_CONFIG: NEMO test configuration to use.
* SPLITS: Number of repetitions of the same test to run (defaults to 1).

.. code-block:: yaml

  # STRONG SCALING CONFIG
  STRONGSCALING:
    TEST_NAMES: [BENCH,   BENCH,   BENCH  ]
    NAMES:      [bench_1, bench_2, bench_3]
    PROCESSORS: [112,     224,     336    ]
    THREADS:    [1,       1,       1      ]
    SPLITS: 1
    TEST_CONFIG: BENCH
    ARCH_NAME: O3_prod

Weak Scaling
^^^^^^^^^^^^

The Weak Scaling configuration differs from the rest, since the test names indicate the resolution and the processors are computed at runtime:

* BASE_PROCS: Processors of the base case.
* BASE_RESOLUTION: Resolution of the base case.

The following list variables have to be the same length:

* TEST_NAMES: List of resolutions to run for each test.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.
* RESOLUTION: List of NEMO supported resolutions run by each test. This is the setting that will be used to compute the number of processors based on the base case resolution.
* ARCH_NAME: Arch to be used to run the weak scaling model; it has to be defined in the MODEL.ARCH_NAMES list.
* TEST_CONFIG: NEMO test configuration to use.
* SPLITS: Number of repetitions of the same test to run (defaults to 1).

.. code-block:: yaml

  # WEAKSCALING CONFIG
  WEAKSCALING:
    BASE_PROCS: 56
    BASE_RESOLUTION: orca1
    NAMES:      [orca1, orca025]
    TEST_NAMES: [orca1, orca025]
    PROCESSORS: [1,     1      ]
    THREADS:    [1,     1      ]
    RESOLUTION: [orca1, orca025]
    TEST_CONFIG: BENCH
    ARCH_NAME: O3_prod

Compilation Efficiency
^^^^^^^^^^^^^^^^^^^^^^

The configuration of the Compilation Efficiency test follows the same idea as the Weak Scaling; the arch names define which binary each test should be run with, and the test names group the runs that are compared in the same scalability table:

The following list variables have to be the same length:

* TEST_NAMES: List of the test case names; each value groups its runs in one scalability table, so runs sharing a value are compared against each other.
* ARCH_NAMES: List of the arch configs to run for each test; they have to be defined in MODEL.ARCH_NAMES.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.
* TEST_CONFIG: NEMO test configuration to use.
* SPLITS: Number of repetitions of the same test to run (defaults to 1).

.. code-block:: yaml

  # COMPILATION EFFICIENCY CONFIG
  COMPILATION_EFFICIENCY:
    TEST_NAMES: [O1_prod,   O1_prod,  O3_prod,  O3_prod]
    ARCH_NAMES: [O1_prod,   O1_prod,  O3_prod,  O3_prod]
    NAMES:      [O1_112,    O1_224,   O3_112,   O3_224 ]
    PROCESSORS: [112,       224,      112,      224    ]
    THREADS:    [1,         1,        1,        1      ]
    SPLITS: 1
    TEST_CONFIG: BENCH
