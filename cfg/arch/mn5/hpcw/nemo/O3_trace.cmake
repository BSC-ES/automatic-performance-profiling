# Copyright (c) 2019 - 2025 Niclas Schroeter
# Copyright (c) 2019 - 2024 David Guibert
# Copyright (c) 2024 Daniel Beltrán-Mora
# Copyright (c) 2024 Ralf Mueller
# All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

set(CMAKE_Fortran_FLAGS "-g -xHost -align array64byte -traceback -i4 -r8 -O3 -fp-model precise -fno-alias -finstrument-functions -rdynamic")

# ##############################################################################
set(USE_SYSTEM_cdo ON)
set(USE_SYSTEM_blas ON)
set(USE_SYSTEM_fftw ON)
set(USE_SYSTEM_hdf5 ON)
set(USE_SYSTEM_libxml2 OFF)
set(USE_SYSTEM_mpi ON)
set(USE_SYSTEM_netcdf OFF)
set(USE_SYSTEM_zlib ON)
set(USE_SYSTEM_szip OFF)
set(USE_SYSTEM_libfyaml OFF)
set(ENABLE_SVN_CHECKOUT
    ON
    CACHE BOOL "")
# ##############################################################################

# ##############################################################################
# launchers
# ##############################################################################

set(HPCW_JOB_STAGEIN ${CMAKE_SOURCE_DIR}/toolchains/job-stagein.sh)
set(HPCW_JOB_LAUNCHER ${CMAKE_SOURCE_DIR}/toolchains/mareNostrum5/bsc-job-launcher.sbatch)