
In order to configure ECE4 and the tests the workflow will run, you have to update the configuration file ``proj/auto-performance-profiling/autosubmit/configuration/common/model/ecearth4/proj.yml`` located in your experiment root.

.. contents:: Table of Contents

Automatic clone
---------------

In order to configure the passwordless git clone follow this guide: `Auto ECE4 passwordles clone <https://earth.bsc.es/gitlab/es/auto-ecearth4/-/wikis/SMHI%20gitlab>`_.

Configure the model
-------------------

The main variables to update in this config file are:


* ORIGIN: url with the git repository containing ECE4.
* REPORT_COMPONENTS: list of components that you want to get info in the report.
* BRANCH_LIST: tag of the version you want to run.
* OUTPUT: enables or disables the output (TRUE/FALSE).
* START_DATE: start date of the scalability experiments
* END_DATE: end date of the scalability experiments
* FREQ: frequency of the model stopping MONTHLY/DAILY.
* INTERVAL: number of model stops.
* TEST_STEPS: number of steps of the scalability jobs, used for the magiccut job.
* ARCH_NAMES: list of arch files to compile. This arch files must be located in ``cfg/arch/PLATFORM/MODEL/`` and follow this pattern ``ARCH_NAME.yml``.
* RESOLUTION: Model resolution, not used.
* OIFS_RESOLUTION: Oifs grid.
* NEMO_RESOLUTION: NEMO grid.

.. code-block:: yml

   # MODEL CONFIG
   MODEL:
     NAME: ecearth4
     REPORT_COMPONENTS: [nemo, oifs]
     ORIGIN: https://git.smhi.se/ec-earth/ecearth4.git
     BRANCH_LIST: main

     # Arch files prefixes to compile
     # The arch file has to be located in cfg/arch/PLATFORM/MODEL/
     # - For ecearth4: ARCH_NAME.yml
     # - For nemo: arch-ARCH_NAME.fcm
     ARCH_NAMES: [O3_impi_trace, O3_impi_prod, O1_prod]

   # EXPERIMENT CONFIG
   EXPERIMENT:
     RESOLUTION: "TCO95L91+eORCA1L75"
     OIFS_RESOLUTION: "TCO95L91"
     NEMO_RESOLUTION: "eORCA1L75"

     START_DATE: 19900101
     END_DATE: 19900102
     FREQ: DAILY
     INTERVAL: 1
     TEST_STEPS: 32
     OUTPUT: FALSE

Configure the members
---------------------

The members configuration only has to be present only if they are activated in ``proj/auto-performance-profiling/autosubmit/configuration/common/expdef.yml``.

Tracing
^^^^^^^

The possible variables to configure for Tracing are:


* TIMESTEP_ZERO: TRUE/FALSE, true if the model runs a timestep 0, false otherwise. Used by magiccut to cut the timestep trace right.
* TRACE_STEPS: Number of steps the model should run when tracing it.
* USER\ *FUNCTIONS*\ *: Variables used by the User Functions sampling script.

The next list variables have to be the same length:


* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.
* ARCH_NAME: Arch to be used to run the tracing model, it has to be defined in MODEL.ARCH_NAMES list.
* PAPI_COUNTERS: Space separated string with the PAPI counters to trace, same id as returned by the command ``papi_avail``.

.. code-block:: yml

   # TRACE CONFIG
   TRACING:
     START_DATE: 19900101
     END_DATE: 19900102
     FREQ: DAILY
     INTERVAL: 1
     TIMESTEP_ZERO: FALSE
     TRACE_STEPS: 32
     OUTPUT: FALSE

     # CONFIG FOR USER FUNCTIONS SAMPLING
     USER_FUNCTIONS_PROC: 112
     USER_FUNCTIONS_THREADS: 4
     TRACE_N_FUNCTIONS: 40

     TEST_NAMES: [BENCH,   BENCH  , BENCH  ]
     NAMES:      [trace_1, trace_2, trace_3]
     PROCESSORS: [112,     224    , 336    ]
     OIFS_PROCS: [55,      111    , 167    ]
     NEMO_PROCS: [55,      111    , 167    ]
     XIOS_PROCS: [1,       1      , 1      ]
     THREADS:    [1,       1      , 1      ]
     USE_OMP_THREDS: false
     MODEL_RESOLUTION: orca1
     TEST_CONFIG: BENCH
     ARCH_NAME: O3_impi_trace

StrongScaling
^^^^^^^^^^^^^

The next list variables have to be the same length:


* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.
* MODEL_RESOLUTION: Resolution with the test will run on.
* ARCH_NAME: Arch to be used to run the tracing model, it has to be defined in MODEL.ARCH_NAMES list.
* 
  COUPLING: Enables/disables coupling report (Lucia).

  .. code-block:: yml

     # STRONG SCALING CONFIG
     STRONGSCALING:
     STRONGSCALING_PARAMETERS_ROOT: "%PROJECT_FLAGS.MODEL_CONFIG_FOLDER%/strongscaling"

     TEST_NAMES: [BENCH,   BENCH  ]
     NAMES:      [bench_1, bench_2]
     PROCESSORS: [112,     224    ]
     OIFS_PROCS: [55,      111    ]
     NEMO_PROCS: [55,      111    ]
     XIOS_PROCS: [1,       1      ]
     THREADS:    [1,       1      ]
     USE_OMP_THREDS: false
     MODEL_RESOLUTION: orca1
     TEST_CONFIG: BENCH
     ARCH_NAME: O3_impi_prod

     COUPLING: 
       ENABLED: true

Weakscaling
^^^^^^^^^^^

The Weakscaling configuration differs from the rest, since the test names indicate the resolution and the processors are computed in runtime:


* [COMPONENT]_BASE_PROCS: Component processors of the base case.
* [COMPONENT]_BASE_RESOLUTION: Component resolution of the base case.

The next list variables have to be the same length:


* TEST_NAMES: List of resolutions to run for each test.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.
* [COMPONENT]_RESOLUTION: List of components ran by each test.
* ARCH_NAME: Arch to be used to run the tracing model, it has to be defined in MODEL.ARCH_NAMES list.

.. code-block:: yml

   # WEAKSCALING CONFIG
   WEAKSCALING:
     WEAKSCALING_PARAMETERS_ROOT: "%PROJECT_FLAGS.MODEL_CONFIG_FOLDER%/MultiExperiment/weakscaling"

     # Base case configuration, meaning the resolution and processors configuration
     NEMO_BASE_PROCS: 111
     OIFS_BASE_PROCS: 333
     NEMO_BASE_RESOLUTION: eORCA1L75
     OIFS_BASE_RESOLUTION: TL159L91

     # Processors must be set to 1, since processors count is computed during runtime
     # based on the base processors and resolution
     TEST_NAMES:      [ws_1_1,    ws_1_2,    ws_1_3,    ws_1_4   ]
     NAMES:           [ws_1_1,    ws_1_2,    ws_1_3,    ws_1_4   ]
     PROCESSORS:      [1,         1,         1,         1,       ]
     XIOS_PROCS:      [1,         1,         1,         1,       ]
     OIFS_RESOLUTION: [TL159L91,  TL255L91,  TL511L91,  TCO319L91]
     NEMO_RESOLUTION: [eORCA1L75, eORCA1L75, eORCA1L75, eORCA1L75]

     TEST_CONFIG: BENCH
     ARCH_NAME: O3_impi_prod

CompilationEfficiency
^^^^^^^^^^^^^^^^^^^^^

The configuration of the compilation efficiency follows the same idea as the Weakscaling, the test names define what arch should each test be run with:

The next list variables have to be the same length:


* TEST_NAMES: List of the arch configs to run for each test, they have to be defined in MODEL.ARCH_NAMES.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.
* MODEL_RESOLUTION: Resolution with the test will run on.

.. code-block:: yml

   # COMPILATION EFFICIENCY CONFIG
   COMPILATION_EFFICIENCY:
     COMPILATION_EFFICIENCY_PARAMETERS_ROOT: "%PROJECT_FLAGS.MODEL_CONFIG_FOLDER%/MultiExperiment/compilation_efficiency"

     # For compilation efficiency the arch name is taken from the test name
     TEST_NAMES: [O3_impi_prod, O3_impi_prod, O3_impi_prod, O1_prod, O1_prod, O1_prod]
     NAMES:      [O3_112,       O3_224,       O3_336,       O1_112,  O1_224,  O1_336 ]
     PROCESSORS: [112,          224,          336,          112,     224,     336    ]
     OIFS_PROCS: [55,           111,          167,          55,      111,     167    ]
     NEMO_PROCS: [55,           111,          167,          55,      111,     167    ]
     XIOS_PROCS: [1,            1,            1,            1,       1,       1      ]
     THREADS:    [1,            1,            1,            1,       1,       1      ]
     MODEL_RESOLUTION: orca1
     TEST_CONFIG: BENCH
