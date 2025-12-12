# Automatic Performance Profiling

The Automatic Performance Profiling tool generates performance reports of climate models automatically.

## Tool features

The tool is capable of running and reporting the following performance tests:

- Strong Scaling tests: Reports how the model scales by incrementing processors count while maintaining the same problem size.

- Compilation Efficiency tests: Compares different build types (e.g. different compilers, libraries...) scalability.

- Weak Scaling tests: Reports the model speed scaling both the problem size and efficiency.

- Model Tracing: Reports more complex performance metrics (PAPI counters, MPI profile, User Functions...) by tracing the execution of the model.

- HW Benchmarks: Tests and reports HW benchmarks of the current HPC platform to discard issues in the platform.

## Models and platforms support

The tool currently supports the following climate models:

- EC-Earth 4

- NEMO 4.2.1

- HPCW 3.0

And it has been ported and tested in the following HPC platforms:

- Marenostrum 5 (BSC)

- HPC2020 (ECMWF)

##  Documentation

For users and developers documentation, check the [wiki](https://automatic-performance-profiling.readthedocs.io/en/latest/) at Read the Docs.

## Contact

For any new features requests or issues you may find running the workflow, please send an email to [roc.salvador@bsc.es](mailto:roc.salvador@bsc.es).