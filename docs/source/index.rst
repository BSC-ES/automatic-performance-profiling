:html_theme.sidebar_secondary.remove:

Automatic Performance Profiling
===============================

.. toctree::
   :maxdepth: 2
   :hidden:

   users_guide/users_guide
   developers_guide/developers_guide
   examples
   troubleshooting

.. container:: app-hero

   **Automatic Performance Profiling** runs the performance tests of your climate model
   and turns the raw output into a performance report, automatically.

   .. button-ref:: users_guide/users_guide
      :ref-type: doc
      :color: primary

      Get started

   .. button-ref:: developers_guide/developers_guide
      :ref-type: doc
      :color: primary
      :outline:

      Developer's Guide

.. container:: as-lead

   APP wraps the model runs and the analysis tools in an
   `Autosubmit <https://autosubmit.readthedocs.io/>`_ workflow. You choose the model and
   the platform, launch the experiment, and the workflow runs the tests, collects the
   timings and renders the PDF report.

   It is developed by the Earth Sciences Department of the Barcelona Supercomputing
   Center to characterise the performance of EC-Earth 4, NEMO 4.2.1, HPCW 3.0 and
   AUTO-MONARCH on MareNostrum 5 and ECMWF's HPC2020.

What the tool does
------------------

.. grid:: 1 2 2 3
   :gutter: 3
   :class-container: app-cards

   .. grid-item-card:: :octicon:`pulse;1.1em` Strong Scaling

      Reports how the model scales when the processor count grows while the problem
      size stays fixed.

   .. grid-item-card:: :octicon:`graph;1.1em` Weak Scaling

      Reports how the model speed and efficiency evolve when the problem size and the
      processor count grow together.

   .. grid-item-card:: :octicon:`gear;1.1em` Compilation Efficiency

      Compares the scalability of different build types: compilers, libraries and
      optimisation flags.

   .. grid-item-card:: :octicon:`telescope;1.1em` Model Tracing

      Adds PAPI counters, MPI profiles and user functions to the picture, with Extrae,
      Paraver and Dimemas.

   .. grid-item-card:: :octicon:`cpu;1.1em` Hardware Benchmarks

      Runs OSU and STREAM on the platform, so hardware issues are ruled out before
      blaming the model.

   .. grid-item-card:: :octicon:`file;1.1em` Performance Report

      Collects every test into a single PDF, with tables and plots ready to share.

Supported models and platforms
------------------------------

.. list-table::
   :header-rows: 1

   * - Platform / Model
     - EC-Earth 4
     - NEMO 4.2.1
     - HPCW 3.0
     - AUTO-MONARCH
   * - MareNostrum 5
     - Yes
     - Yes
     - Yes
     - Yes
   * - HPC2020
     - Yes
     - Yes
     - No
     - No

Get in touch
------------

.. grid:: 1 2 2 3
   :gutter: 3
   :class-container: app-cards

   .. grid-item-card:: :octicon:`mark-github;1.1em` Source code
      :link: https://github.com/BSC-ES/automatic-performance-profiling

      Browse the code, read the changelog, or open a pull request on GitHub.

   .. grid-item-card:: :octicon:`issue-opened;1.1em` Report a problem
      :link: https://github.com/BSC-ES/automatic-performance-profiling/issues

      Found a bug, or want a new feature or model? Open an issue on the tracker.

   .. grid-item-card:: :octicon:`mail;1.1em` Ask the team
      :link: mailto:roc.salvador@bsc.es

      Questions about running the workflow on your platform, or anything the docs do
      not answer.
