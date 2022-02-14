#!/usr/bin/env bash
# Go to experiment folder
set -xv
source %ENV_SOURCES%
cd %RUN_ROOT%/hardware_benchmarks/STREAM_RUN
./stream > stream_%NUMPROC%.txt
