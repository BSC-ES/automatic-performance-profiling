## 1.1.0

### Features

- Added support for new models:

    - AUTO-MONARCH: Support for running and reporting performance tests of the AUTO-MONARCH model.

    - HPCW 3.0: Support for running and reporting performance tests of the HPCW model.

- Added splits functionality to run multiple sets of the same test.

### Improvements

- Restructured the Autosubmit configuration to separate user and tool core configuration.

- Improved the report generation:

    - Added scalability reports for compilation efficiency tests.

    - Improved compilation efficiency comparison plots and tables.

- Improved the Python post-processing scripts.

- Refactored the documentation with a new users guide and developers guide.

- Changed the project license to GPLv3.

## 1.0.0

This is the first entry of the changelog, from now on all bug fixes, enchancments and new features will be reported here. 

### Features


- Supported performance tests:

    - Strong Scaling tests: Reports how the model scales by incrementing processors count while maintaining the same problem size.

    - Compilation Efficiency tests: Compares different build types (e.g. different compilers, libraries...) scalability.

    - Weak Scaling tests: Reports the model speed scaling both the problem size and efficiency.

    - Model Tracing: Reports more complex performance metrics (PAPI counters, MPI profile, User Functions...) by tracing the execution of the model.

    - HW Benchmarks: Tests and reports HW benchmarks of the current HPC platform to discard issues in the platform.

- Supported models:

    - Support for ECE4 coulped and OIFS only runs.

    - Support for NEMO 4.2.1 only.

- Workflow based on AutoSumbmit 4.