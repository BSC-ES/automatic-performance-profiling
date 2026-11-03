Configure ECE4
==============

In order to configure ECE4 and the tests the workflow will run, you have to update the configuration file ``proj/auto-performance-profiling/autosubmit/configuration/user/model/ecearth4/proj.yml`` located in your experiment root.

Automatic clone
---------------

In order to configure the passwordless git clone, follow this guide: `Auto ECE4 passwordless clone <https://earth.bsc.es/gitlab/es/auto-ecearth4/-/wikis/SMHI%20gitlab>`_.

Configure the model
-------------------

The main variables to update in this config file are:

* ORIGIN: URL of the git repository containing ECE4.
* COMPONENTS: list of all needed components to run your specific configuration. Supported component IDs: ``oifs``, ``nemo``, ``rnfm``, ``xios``, ``oasis`` and ``amipfr``.
* REPORT_COMPONENTS: list of components that you want to get info from in the report. Possible values: a subset of MODEL.COMPONENTS.
* BRANCH_LIST: tag of the version you want to run.
* OUTPUT: enables or disables the output (true/false).
* START_DATE: start date of the scalability experiments (YYYYMMDD date format string).
* END_DATE: end date of the scalability experiments (YYYYMMDD date format string).
* FREQ: frequency of the model stopping (YEARLY/MONTHLY/DAILY).
* INTERVAL: number of model stops.
* TEST_STEPS: number of steps of the scalability jobs, used for the magiccut job.
* ARCH_NAMES: list of arch files to compile. These arch files must be located in ``cfg/arch/PLATFORM/MODEL/`` and follow this pattern ``ARCH_NAME.yml``.
* RESOLUTION: Model resolution, not used.
* OIFS_RESOLUTION: ECE4 supported OIFS resolution.
* NEMO_RESOLUTION: ECE4 supported NEMO resolution.
* INIDATA: Path to the ECE4 inidata directory.

.. code-block:: yaml

  # MODEL CONFIG
  MODEL:
    NAME: ecearth4
    REPORT_COMPONENTS: [nemo, oifs]
    COMPONENTS: [oifs, xios, nemo, rnfm, oasis]
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

  # Inidata path for mn5:     /gpfs/projects/bsc32/models/ecearth/ece4-app/inidata
  # Inidata path for hpc2020: /hpcperm/c3et/models/ecearth/v4-trunk
  INIDATA: /gpfs/projects/bsc32/models/ecearth/ece4-app/inidata

Configure the tests
---------------------

The tests configuration only has to be present if they are activated by commenting/uncommenting the path to their jobs configuration file in the ``proj/auto-performance-profiling/autosubmit/configuration/bootstrap.yml`` file.

Tracing
^^^^^^^

The possible variables to configure for Tracing are:

* OUTPUT: enables or disables the output for Tracing tests (true/false).
* START_DATE: start date of the Tracing experiments to control the trace size (YYYYMMDD date format string).
* END_DATE: end date of the Tracing experiments to control the trace size (YYYYMMDD date format string).
* FREQ: frequency of the model stopping to control the trace size (YEARLY/MONTHLY/DAILY).
* INTERVAL: number of model stops.
* TIMESTEP_ZERO: TRUE/FALSE, true if the model runs a timestep 0, false otherwise. Used by MagicCut to cut the trace at the right timestep.
* TRACE_STEPS: Number of steps the model should run when tracing it.
* USER_FUNCTIONS_*: Variables used by the User Functions sampling script.

The following list variables have to be the same length:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.
* ARCH_NAME: Arch to be used to run the tracing model; it has to be defined in the MODEL.ARCH_NAMES list.

.. code-block:: yaml

  # TRACE CONFIG
  TRACING:
    START_DATE: 19900101
    END_DATE: 19900102
    FREQ: DAILY
    INTERVAL: 1
    TIMESTEP_ZERO: FALSE
    TRACE_STEPS: 32
    OUTPUT: FALSE

    # CONFIG FOR USER FUNCTIONS
    USER_FUNCTIONS_PROC: 112
    USER_FUNCTIONS_THREADS: 4

    TEST_NAMES: [BENCH,   BENCH  , BENCH  ]
    NAMES:      [trace_1, trace_2, trace_3]
    PROCESSORS: [112,     224    , 336    ]
    OIFS_PROCS: [55,      111    , 167    ]
    NEMO_PROCS: [55,      111    , 167    ]
    XIOS_PROCS: [1,       1      , 1      ]
    THREADS:    [1,       1      , 1      ]
    USE_OMP_THREDS: false
    TEST_CONFIG: BENCH
    ARCH_NAME: O3_impi_trace

Strong Scaling
^^^^^^^^^^^^^^

The following list variables have to be the same length:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used in each test.
* [COMPONENT]_PROCS: List of COMPONENT processors used in each test. The workflow will only use the processors of the components set in MODEL.COMPONENTS, but you need to define the list for all of the components because of Autosubmit limitations.
* THREADS: List of threads used by each test.
* ARCH_NAME: Arch to be used to run the strong scaling model; it has to be defined in the MODEL.ARCH_NAMES list.
* COUPLING_REPORT.ENABLED: Enables/disables the coupling report generated by the Lucia tool.
* COUPLING_REPORT.LUCIA.IGNORE_INI_TS: Ignored initial steps for the Lucia coupling report.
* COUPLING_REPORT.LUCIA.IGNORE_END_TS: Ignored end steps for the Lucia coupling report.

  .. code-block:: yaml

    # STRONG SCALING CONFIG
    STRONGSCALING:
      TEST_NAMES: [BENCH,   BENCH  , BENCH  , BENCH  , BENCH  ]
      NAMES:      [bench_1, bench_2, bench_3, bench_4, bench_5]
      PROCESSORS: [112,     224    , 336    , 448    , 560    ]
      OIFS_PROCS: [110,     222    , 334    , 446    , 558    ]
      NEMO_PROCS: [55,      111    , 167    , 223    , 279    ]
      XIOS_PROCS: [1,       1      , 1      , 1      , 1      ]
      AMIP_PROCS: [1,       1      , 1      , 1      , 1      ]
      RNFM_PROCS: [1,       1      , 1      , 1      , 1      ]
      THREADS:    [1,       1      , 1      , 1      , 1      ]
      USE_OMP_THREDS: false
      TEST_CONFIG: BENCH
      ARCH_NAME: O3_impi_prod

      COUPLING_REPORT: 
      ENABLED: true
      LUCIA:
        IGNORE_INI_TS: 1
        IGNORE_END_TS: 1

Weak Scaling
^^^^^^^^^^^^

The Weak Scaling configuration differs from the rest, since the test names indicate the resolution and the processors are computed at runtime:


* [COMPONENT]_BASE_PROCS: COMPONENT processors of the base case.
* [COMPONENT]_BASE_RESOLUTION: ECE4 supported COMPONENT resolution of the base case.

The following list variables have to be the same length:


* TEST_NAMES: List of resolutions to run for each test.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors all equal to 1.
* THREADS: List of threads used by each test.
* [COMPONENT]_RESOLUTION: List of ECE4 supported COMPONENT resolutions run by each test. This is the setting that will be used to compute the number of processors based on the base case resolution.
* [COMPONENT]_PROCS: List of COMPONENT processors used in each test. The workflow will only use the processors of the components set in MODEL.COMPONENTS, but you need to define the list for all of the components because of Autosubmit limitations.
* ARCH_NAME: Arch to be used to run the weak scaling model; it has to be defined in the MODEL.ARCH_NAMES list.

.. code-block:: yaml

  # WEAKSCALING CONFIG
  WEAKSCALING:
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
    AMIP_PROCS:      [1,         1,         1,         1,       ]
    RNFM_PROCS:      [1,         1,         1,         1,       ]
    OIFS_RESOLUTION: [TL159L91,  TL255L91,  TL511L91,  TCO319L91]
    NEMO_RESOLUTION: [eORCA1L75, eORCA1L75, eORCA1L75, eORCA1L75]

    TEST_CONFIG: BENCH
    ARCH_NAME: O3_impi_prod

Compilation Efficiency
^^^^^^^^^^^^^^^^^^^^^^

The configuration of the Compilation Efficiency test follows the same idea as the Weak Scaling; the arch names define which binary each test should be run with, and the test names group the runs that are compared in the same scalability table:

The following list variables have to be the same length:

* TEST_NAMES: List of the test case names; each value groups its runs in one scalability table, so runs sharing a value are compared against each other.
* ARCH_NAMES: List of the arch configs to run for each test; they have to be defined in MODEL.ARCH_NAMES.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used in each test.
* [COMPONENT]_PROCS: List of COMPONENT processors used in each test. The workflow will only use the processors of the components set in MODEL.COMPONENTS, but you need to define the list for all of the components because of Autosubmit limitations.
* THREADS: List of threads used by each test.

.. code-block:: yaml

  # COMPILATION EFFICIENCY CONFIG
  COMPILATION_EFFICIENCY:
    TEST_NAMES: [O3_ompi_prod, O3_ompi_prod, O3_ompi_prod, O3_impi_prod, O3_impi_prod, O3_impi_prod]
    ARCH_NAMES: [O3_ompi_prod, O3_ompi_prod, O3_ompi_prod, O3_impi_prod, O3_impi_prod, O3_impi_prod]
    NAMES:      [ompi_1,       ompi_2,       ompi_3,       impi_1,       impi_2,       impi_3      ]
    PROCESSORS: [112,          224,          336,          112,          224,          336         ]
    OIFS_PROCS: [55,           111,          167,          55,           111,          167         ]
    NEMO_PROCS: [55,           111,          167,          55,           111,          167         ]
    XIOS_PROCS: [1,            1,            1,            1,            1,            1           ]
    AMIP_PROCS: [1,            1,            1,            1,            1,            1           ]
    RNFM_PROCS: [1,            1,            1,            1,            1,            1           ]
    THREADS:    [1,            1,            1,            1,            1,            1           ]
    TEST_CONFIG: BENCH
