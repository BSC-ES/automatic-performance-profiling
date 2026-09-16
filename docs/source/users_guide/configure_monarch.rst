Configure MONARCH
=================

MONARCH is an atmospheric chemistry model. Unlike the other supported models, MONARCH is run through the `Auto-Monarch <https://gitlab.earth.bsc.es/es/auto-monarch.git>`_ workflow, which already provides its own Autosubmit configuration and templates. The Automatic Performance Profiling (APP) workflow integrates with it by copying an existing Auto-Monarch experiment and patching its configuration and templates to run the APP performance tests.

You can change specific Auto-Monarch settings in:

* ``proj/auto-performance-profiling/autosubmit/configuration/user/model/monarch/proj_monarch.yml``: Model configuration.
* ``proj/auto-performance-profiling/autosubmit/configuration/user/platforms_monarch.yml``: Platforms configuration.

Configure the model in the APP workflow
---------------------------------------

The APP MONARCH configuration is located in ``proj/auto-performance-profiling/autosubmit/configuration/user/model/monarch/proj.yml``.

The main variables to update in this config file are:

* MODEL.NAME: model identifier (monarch).
* MODEL.COMPONENTS: list of components required by this model (e.g. ``monarch``).
* MODEL.REPORT_COMPONENTS: subset of components to include in reports.
* MODEL.ORIGIN: repository URL to clone the model from.
* MODEL.BRANCH: branch or tag to use.
* MODEL.ARCH_NAMES: list of architecture build presets (used to pick arch files in ``cfg/arch/PLATFORM/MODEL/``).

.. code-block:: yaml

  # MODEL CONFIG
  MODEL:
    NAME: monarch
    COMPONENTS: [monarch]
    REPORT_COMPONENTS: [monarch]
    ORIGIN: https://gitlab.earth.bsc.es/es/auto-monarch.git
    BRANCH: master

    # Arch files prefixes to compile
    # The arch file has to be located in cfg/arch/PLATFORM/MODEL/
    ARCH_NAMES: [impi_O3_trace, impi_O3_prod, impi_O2_prod]

The arch files for MONARCH are located in ``cfg/arch/PLATFORM/MODEL/ARCH_NAME/`` and each folder contains:

* ``compile.ARCH_NAME.sh``: Script to compile the model with that configuration.
* ``configure.nmmb.ARCH_NAME``: Model configuration file.
* ``remoteconfig.ARCH_NAME.sh``: Script to set up the environment for that configuration.

Configure the tests
---------------------

The tests configuration only has to be present if they are activated by commenting/uncommenting the path to their jobs configuration file in the ``proj/auto-performance-profiling/autosubmit/configuration/bootstrap.yml`` file.

Tracing
^^^^^^^

The possible variables to configure for Tracing are:

* TIMESTEP_ZERO: TRUE/FALSE, true if the model runs a timestep 0, false otherwise. Used by MagicCut to cut the trace at the right timestep.
* NHOURS: Number of model hours the model should run when tracing it. It limits the tracing run to keep the trace size bounded.
* USER_FUNCTIONS_*: Variables used by the User Functions sampling script.

The following list variables have to be the same length:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* JNPES: List of the number of processors in the J (latitude) direction for each test.
* INPES: List of the number of processors in the I (longitude) direction for each test.
* WRITE_TASKS: List of the number of write tasks for each test.
* WRITE_GROUPS: List of the number of write groups for each test.
* THREADS: List of threads used by each test.
* ARCH_NAME: Arch to be used to run the tracing model; it has to be defined in the MODEL.ARCH_NAMES list.

Example:

.. code-block:: yaml

  # TRACE CONFIG
  TRACING:
    TIMESTEP_ZERO: false
    NHOURS: 1

    # CONFIG FOR USER FUNCTIONS SAMPLING
    USER_FUNCTIONS_PROC: 112
    USER_FUNCTIONS_THREADS: 4
    TRACE_N_FUNCTIONS: 40

    TEST_NAMES:   [BENCH,   BENCH  ]
    NAMES:        [trace_1, trace_2]
    PROCESSORS:   [112,     224    ]
    JNPES:        [9,       11     ]
    INPES:        [12,      20     ]
    WRITE_TASKS:  [4,       4      ]
    WRITE_GROUPS: [1,       1      ]
    THREADS:      [1,       1      ]
    TEST_CONFIG: BENCH
    ARCH_NAME: impi_O3_trace

Strong Scaling
^^^^^^^^^^^^^^

Strong Scaling test lists must have matching lengths.

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* JNPES: List of the number of processors in the J (latitude) direction for each test.
* INPES: List of the number of processors in the I (longitude) direction for each test.
* WRITE_TASKS: List of the number of write tasks for each test.
* WRITE_GROUPS: List of the number of write groups for each test.
* THREADS: List of threads used by each test.
* SPLITS: Number of repetitions of the same test to run.
* ARCH_NAME: Arch to be used to run the strong scaling model; it has to be defined in the MODEL.ARCH_NAMES list.

.. code-block:: yaml

  # STRONG SCALING CONFIG
  STRONGSCALING:
    TEST_NAMES:   [BENCH,   BENCH,   BENCH]
    NAMES:        [bench_1, bench_2, bench_3]
    PROCESSORS:   [112,     224,     336  ]
    JNPES:        [9,       11,      11   ]
    INPES:        [12,      20,      30   ]
    WRITE_TASKS:  [4,       4,       6    ]
    WRITE_GROUPS: [1,       1,       1    ]
    THREADS:      [1,       1,       1    ]
    SPLITS: 1
    TEST_CONFIG: BENCH
    ARCH_NAME: impi_O3_prod

Compilation Efficiency
^^^^^^^^^^^^^^^^^^^^^^

The test names of the Compilation Efficiency test define which arch each test should be run with. For MONARCH, the scalability is reported using the simulated days per day (SDPD) instead of the default simulated years per day (SYPD).

The following list variables have to be the same length:

* TEST_NAMES: List of the arch configs to run for each test; they have to be defined in MODEL.ARCH_NAMES.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* JNPES: List of the number of processors in the J (latitude) direction for each test.
* INPES: List of the number of processors in the I (longitude) direction for each test.
* WRITE_TASKS: List of the number of write tasks for each test.
* WRITE_GROUPS: List of the number of write groups for each test.
* THREADS: List of threads used by each test.
* SPLITS: Number of repetitions of the same test to run.

.. code-block:: yaml

  # COMPILATION EFFICIENCY CONFIG
  COMPILATION_EFFICIENCY:
    # For compilation efficiency the arch name is taken from the test name
    TEST_NAMES:   [impi_O2_prod, impi_O2_prod, impi_O3_prod, impi_O3_prod]
    NAMES:        [O2_112,       O2_224,      O3_112,      O3_224     ]
    PROCESSORS:   [112,          224,         112,         224        ]
    JNPES:        [9,            11,          9,           11         ]
    INPES:        [12,           20,          12,          20         ]
    WRITE_TASKS:  [4,            4,           4,           4          ]
    WRITE_GROUPS: [1,            1,           1,           1          ]
    THREADS:      [1,            1,           1,           1          ]
    SPLITS: 3
    TEST_CONFIG: BENCH
