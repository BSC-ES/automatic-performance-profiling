Configure HPCW
==============

In order to configure HPCW NEMO and the tests the workflow will run, you have to update the configuration file ``proj/auto-performance-profiling/autosubmit/configuration/user/model/hpcw/proj.yml`` located in your experiment root.

Configure the model
-------------------

Main variables to update in the proj.yml:

* MODEL.NAME: model identifier (hpcw).
* MODEL.COMPONENTS: list of components required by this model (e.g. ``nemo``).
* MODEL.REPORT_COMPONENTS: subset of components to include in reports.
* MODEL.ORIGIN: repository URL to clone the model from.
* MODEL.BRANCH: branch or tag to use.
* MODEL.ARCH_NAMES: list of architecture build presets (used to pick arch files in ``cfg/arch/PLATFORM/MODEL/COMPONENT/``).
* MODEL.STORE: shared CMake ``ExternalData`` object cache (see `Model inputs`_).
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

Model inputs
------------

HPCW stages the model inputs with CMake's ``ExternalData`` module. HPCW appends its own store
(``${CMAKE_SOURCE_DIR}/hpcw-store``) to the module, so the ``ExternalData_OBJECT_STORES``
environment variable is ignored and the inputs would be downloaded again by every compilation job
of every arch (several tens of GB from the DKRZ Swift store, individual files up to 25 GB).

To avoid this, set ``MODEL.STORE`` in
``proj/auto-performance-profiling/autosubmit/configuration/user/model/hpcw/proj.yml`` to a directory that
survives across experiments. The compilation job then links the store of the compilation directory
to it and reuses the cached inputs:

.. code-block:: yaml

  MODEL:
    # ...
    STORE: /gpfs/scratch/<group>/<user>/hpcw-store

The first compilation still has to download the inputs. To do it outside the workflow (recommended,
several GB of downloads are slow on login nodes), pre-populate the cache with:

.. code-block:: bash

  cfg/utils/hpcw/populate_store.sh -s /gpfs/scratch/<group>/<user>/hpcw-store \
      <experiment>/compilation/<ARCH>

Leave ``MODEL.STORE`` empty to keep the inputs inside each compilation directory.

Model environment
-----------------

The environment used to build and run HPCW on each platform lives in
``proj/auto-performance-profiling/cfg/arch/PLATFORM/MODEL/<COMPONENT>/<ARCH>.env``, with one folder
per ``MODEL.COMPONENTS`` entry (``nemo`` and ``icon``). It mirrors the default
environment of the model (``toolchains/<PLATFORM>/bsc-intel.env.sh``) and adds the deviations the
tool needs, marked with ``[APP]`` comments:

* the MPI compiler wrappers (``CC=mpicc``, ``CXX=mpicxx``, ``FC=mpif90``), so that the
  ``netcdf-fortran`` built from the model and ICON itself use the same Fortran MPI bindings;
* ``szip/2.1.1``, needed by the HDF5 libraries of the modules at run time;
* the compiler flags accepted by the version of the compiler installed on the platform.

The model takes its compilation flags from ``FCFLAGS`` (it ignores the ``CMAKE_Fortran_FLAGS`` of
``<ARCH>.cmake``), so the optimization level that distinguishes the arch presets has to be in this
file: ``O1_prod`` builds with ``-O1`` and ``O3_prod``/``O3_trace`` with ``-O3``. Without it every
arch builds the model with the same flags and the compilation efficiency test compares two
identical builds.

Only the ISA flag, the optimization/debug flags and the tracing flags go in ``FCFLAGS``. The rest
of the ``<ARCH>.cmake`` preset (``-i4 -r8 -align array64byte -fp-model precise -fno-alias``) is for
the CMake built components and cannot be used to build the model: with ``-r8`` the ``REAL4`` and
``REAL8`` kinds are the same and the ``REAL2STRING`` generic interface of the model becomes
ambiguous (``error #5286``).

Keep this file in sync with the model environment when the model is updated.

Compilation
-----------

The compilation job builds the arch configurations listed in ``MODEL.ARCH_NAMES``. Because the model
inputs are already in the shared ``ExternalData`` cache (see `Model inputs`_), the job runs on a
compute node using all the cores of a node (``PROCESSORS`` in
``core/jobs/model/hpcw/jobs.yml``), instead of the login node.

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

The test names of the Compilation Efficiency test define which arch each test should be run with:

The following list variables have to be the same length:

* TEST_NAMES: List of the arch configs to run for each test; they have to be defined in MODEL.ARCH_NAMES.
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
