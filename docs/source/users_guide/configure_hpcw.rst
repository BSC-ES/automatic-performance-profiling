Configure HPCW
==============

In order to configure HPCW (NEMO or ICON) and the tests the workflow will run, you have to update the configuration file ``proj/auto-performance-profiling/autosubmit/configuration/user/model/hpcw/proj.yml`` located in your experiment root.

Configure the model
-------------------

Main variables to update in the proj.yml:

* MODEL.NAME: model identifier (hpcw).
* MODEL.COMPONENTS: component to build and run. HPCW ships two, ``icon`` and ``nemo``, and only one can be used at a time, so the list always has a single element.
* MODEL.REPORT_COMPONENTS: subset of components to include in reports (the same single component).
* MODEL.ORIGIN: repository URL to clone the model from.
* MODEL.BRANCH: branch or tag to use.
* MODEL.ARCH_NAMES: list of architecture build presets (used to pick the ``<ARCH_NAME>.env`` and ``<ARCH_NAME>.cmake`` files in ``cfg/arch/PLATFORM/MODEL/COMPONENT/``).
* MODEL.STORE: shared CMake ``ExternalData`` object cache (see `Model inputs`_).

The model test case, the number of steps and the output switch are per-test settings: each test
section defines its own ``TEST_CONFIG``, ``TEST_STEPS`` (``TRACE_STEPS`` while tracing) and
``OUTPUT``. Other models take the number of steps from ``EXPERIMENT.TEST_STEPS`` (model hours for
monarch).

.. code-block:: yaml

  # MODEL CONFIG
  MODEL:
    NAME: hpcw
    COMPONENTS: [icon]
    REPORT_COMPONENTS: [icon]
    ORIGIN: https://gitlab.dkrz.de/hpcw/hpcw.git
    BRANCH: v3.0
    ARCH_NAMES: [O1_prod, O3_prod, O3_trace]
    STORE: /gpfs/scratch/<group>/<user>/hpcw-store

  # STRONG SCALING CONFIG
  STRONGSCALING:
    TEST_NAMES: [BENCH,   BENCH,   BENCH]
    NAMES:      [bench_1, bench_2, bench_3]
    PROCESSORS: [896,     1344,    1792]
    THREADS:    [1,       1,       1]
    SPLITS: 3
    TEST_CONFIG: NextGEMS_R2B8_2020
    TEST_STEPS: 10
    ARCH_NAME: O3_prod
    OUTPUT: false

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
``proj/auto-performance-profiling/cfg/arch/PLATFORM/MODEL/<COMPONENT>/<ARCH_NAME>.env``, next to the
``<ARCH_NAME>.cmake`` preset used for the CMake-built parts, with one folder per
``MODEL.COMPONENTS`` entry (``nemo`` and ``icon``). It mirrors the default
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

The compilation job builds the arch configurations listed in ``MODEL.ARCH_NAMES`` (one job per
arch). Because the model inputs are already in the shared ``ExternalData`` cache (see
`Model inputs`_), the job runs on a compute node using all the cores of a node (``PROCESSORS`` from
``DEFAULT.PROCESSORS_PER_NODE`` in ``core/jobs/jobs-execution.yml``), instead of the login node.

Configure the tests
---------------------

The tests configuration only has to be present if they are activated by commenting/uncommenting the path to their jobs configuration file in the ``proj/auto-performance-profiling/autosubmit/configuration/bootstrap.yml`` file.

Model test cases
^^^^^^^^^^^^^^^^

``TEST_CONFIG`` selects the test case each test runs, and is defined per test. A test case can only
be used by tests that fit its size, e.g. the small ones do not scale to many nodes.

NEMO (``MODEL.COMPONENTS: [nemo]``):

* ``orca025-medium``: ORCA025 setup (``nemo_orca25``, MY_ORCA25 configuration) with the JRA55
  forcing and initial conditions staged by HPCW.
* ``orca1-like-small``: ORCA1-like ``BENCH`` setup (``nemo_bench1``), the cheapest case.

ICON (``MODEL.COMPONENTS: [icon]``), one input package per test case
(``inputs/icon/experiments/<TEST_CONFIG>``):

* ``test_nwp_R02B04N06multi`` (small): NWP test case with nested domains (~160 km); a "health
  check" for the build and the usual choice for short runs.
* ``aes_physics`` (small): technical land and atmosphere setup (~40 km) that fills about one node.
* ``atm_tracer_Hadley`` (small): idealized tracer transport (~60 km).
* ``NextGEMS_R2B8_2020`` (medium): high-resolution NextGEMS setup (~10 km); the default for the
  strong scaling and compilation efficiency tests.
* ``LAM`` (large): operational forecast covering Germany, two nests (1 km and 0.5 km).

The ICON list is the one of the model (``<src>/doc/icon_tests.md``). The compilation job builds ICON
with ``-DCOPY_ICON_INPUTS=ON -DENABLE_icon_large_inputs=ON``, so the medium and large packages are
available and every package can be used as ``TEST_CONFIG`` without workflow changes. The NEMO cases
are the ``case`` branches of ``autosubmit/templates/models/hpcw/run.sh``; a new one has to be added
there.

Tracing
^^^^^^^

The possible variables to configure for Tracing are:

* TIMESTEP_ZERO: TRUE/FALSE, true if the model runs a timestep 0, false otherwise. Used by MagicCut to cut the trace at the right timestep.
* TRACE_STEPS: Number of steps the model should run when tracing it.
* TEST_CONFIG: Test case to run (see `Model test cases`_).
* OUTPUT: TRUE/FALSE, enables or disables the model output (it is not needed when tracing).
* USER_FUNCTIONS_*: Variables used by the User Functions sampling script.

Tracing always runs a single repetition of each test, so its number of splits is fixed in the
tracing job definition instead of being configurable.

The following list variables have to be the same length:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.

ARCH_NAME is not a list: it is the arch used to run the traced model and has to be one of the
MODEL.ARCH_NAMES (normally the ``<ARCH>_trace`` preset).

Example:

.. code-block:: yaml

  # TRACE CONFIG
  TRACING:
    TIMESTEP_ZERO: false
    TRACE_STEPS: 10

    # CONFIG FOR USER FUNCTIONS
    USER_FUNCTIONS_PROC: 112
    USER_FUNCTIONS_THREADS: 4

    TEST_NAMES: [BENCH,   BENCH]
    NAMES:      [trace_1, trace_2]
    PROCESSORS: [112,     224]
    THREADS:    [1,       1]
    TEST_CONFIG: test_nwp_R02B04N06multi
    ARCH_NAME: O3_trace
    OUTPUT: false

Strong Scaling
^^^^^^^^^^^^^^

Strong Scaling test lists must have matching lengths:

* TEST_NAMES: List of test names to run.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used by each test.
* THREADS: List of threads used by each test.

The remaining settings apply to every test of the section:

* SPLITS: Number of repetitions of the same test to run.
* TEST_CONFIG: Test case to run (see `Model test cases`_).
* TEST_STEPS: Number of steps the model should run.
* ARCH_NAME: Arch to be used to run the model; it has to be defined in the MODEL.ARCH_NAMES list.
* OUTPUT: TRUE/FALSE, enables or disables the model output (it is not needed for a scaling run).

.. code-block:: yaml

  # STRONG SCALING CONFIG
  STRONGSCALING:
    TEST_NAMES: [BENCH,   BENCH,   BENCH]
    NAMES:      [bench_1, bench_2, bench_3]
    PROCESSORS: [896,     1344,    1792]
    THREADS:    [1,       1,       1]
    SPLITS: 3
    TEST_CONFIG: NextGEMS_R2B8_2020
    TEST_STEPS: 10
    ARCH_NAME: O3_prod
    OUTPUT: false

Compilation Efficiency
^^^^^^^^^^^^^^^^^^^^^^

The arch names of the Compilation Efficiency test define which binary each test should be run with, and the test names group the runs that are compared in the same scalability table.
The following list variables have to be the same length:

* TEST_NAMES: List of the test case names; each value groups its runs in one scalability table, so runs sharing a value are compared against each other.
* ARCH_NAMES: List of the arch configs to run for each test; they have to be defined in MODEL.ARCH_NAMES.
* NAMES: List of unique names for each test.
* PROCESSORS: List of processors used to run each test (the number of cores requested by the job).
* THREADS: List of threads used by each test.

The remaining settings apply to every test of the section:

* SPLITS: Number of repetitions of the same test to run.
* TEST_CONFIG: Test case to run (see `Model test cases`_).
* TEST_STEPS: Number of steps the model should run.
* OUTPUT: TRUE/FALSE, enables or disables the model output (it is not needed for a compilation run).

.. code-block:: yaml

  # COMPILATION EFFICIENCY CONFIG
  COMPILATION_EFFICIENCY:
    TEST_NAMES: [O1_prod,   O1_prod,  O3_prod,  O3_prod]
    ARCH_NAMES: [O1_prod,   O1_prod,  O3_prod,  O3_prod]
    NAMES:      [O1_896,    O1_1344,  O3_896,   O3_1344]
    PROCESSORS: [896,       1344,     896,      1344   ]
    THREADS:    [1,         1,        1,        1      ]
    SPLITS: 1
    TEST_CONFIG: NextGEMS_R2B8_2020
    TEST_STEPS: 10
    OUTPUT: false
