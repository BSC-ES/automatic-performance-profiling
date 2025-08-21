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