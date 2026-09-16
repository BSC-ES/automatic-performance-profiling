# ------------------------------------------------------------------------------------------------- #
# auto-monarch settings (marenostrum5)
# ------------------------------------------------------------------------------------------------- #

# specify the compiler to be used for this platform (gcc, intel)
COMPILER=intel

module purge

case "${TASKTYPE}" in
"REMOTE_COMPILE")
  module load intel/2023.2.0
  module load impi/2021.10.0
  module load mkl/2023.2.0

  module load hdf4/4.2.16-2-gcc #For NPS
  module load hdf5/1.14.1-2
  module load pnetcdf/1.12.3
  module load netcdf/2023-06-14
  module load esmf/8.0.1

  if [[ ${COMPILE_LIBS} -eq 1 ]]; then
    export PATH=$PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/wgrib-1.8.1.2
    module load jasper/1.900.1-gcc
  else
    export PATH=$PATH:/gpfs/projects/bsc32/share/libs/MN5/utils/wgrib/v1.8.1.0b
  fi

  if [[ ${DO_CAMP} -eq 1 ]]; then
    module load gsl/2.7.1
    if [[ ${COMPILE_LIBS} -eq 1 ]]; then
      module load metis/5.1.0
      module load cmake/3.25.1
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/json-fortran-6.1.0/install/jsonfortran-intel-6.1.0/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/SuiteSparse/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/cvode/install/lib
    else
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/jsonfortran-intel-6.1.0/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/SuiteSparse/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/cvode/lib
    fi
  fi
  ;;
"PREPROCFIX")
  module load intel/2023.2.0
  module load impi/2021.10.0
  module load mkl/2023.2.0

  #specific for geos2wrf package
  module load zlib/1.3.1
  module load szip/2.1.1

  module load hdf5/1.14.1-2
  module load pnetcdf/1.12.3
  module load netcdf/2023-06-14
  ;;
"PREPROCVAR")
  module load intel/2023.2.0
  module load impi/2021.10.0
  module load mkl/2023.2.0

  #specific for geos2wrf package
  module load zlib/1.3.1
  module load szip/2.1.1

  module load hdf5/1.14.1-2
  module load pnetcdf/1.12.3
  module load netcdf/2023-06-14
  module load libexpat/2.6.2 
  module load udunits/2.2.28
  module load nco/5.2.2

  if [[ ${COMPILE_LIBS} -eq 1 ]]; then
    export PATH=$PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/wgrib-1.8.1.2
  else
    export PATH=$PATH:/gpfs/projects/bsc32/share/libs/MN5/utils/wgrib/v1.8.1.0b
  fi

  #Temporal until issue 51 is solved
  export PATH=$PATH:/gpfs/projects/bsc32/share/libs/MN5/utils/cnvgrib/1.4.0/
  module load cdo/1.8.2

  run_call="mpirun -np"
  ;;
"SIM")
  module load intel/2023.2.0
  module load ucx/1.15.0
  module load impi/2021.10.0
  module load mkl/2023.2.0

  module load hdf5/1.14.1-2
  module load pnetcdf/1.12.3
  module load netcdf/2023-06-14
  module load esmf/8.0.1

  module load cdo/1.8.2

  if [[ ${DO_CAMP} -eq 1 ]]; then
    module load gsl/2.7.1
    if [[ ${COMPILE_LIBS} -eq 1 ]]; then
      module load metis/5.1.0
      module load cmake/3.25.1
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/json-fortran-6.1.0/install/jsonfortran-intel-6.1.0/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/SuiteSparse/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/cvode/install/lib
    else
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/jsonfortran-intel-6.1.0/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/SuiteSparse/lib
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/cvode/lib
    fi
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${EXP_ROOT}/nmmb-monarch/MODEL/SRC_LIBS/camp/build/lib
  fi

  export PSM2_MQ_RNDV_HFI_THRESH=1024000
#  module load fabric

  export SLURM_CPU_BIND=none
  run_call="mpirun -np"
  ;;
"OBS_PREPROC" | "COMPILE_OBSPREPROC")
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module unuse /apps/modules/modulefiles/applications /apps/modules/modulefiles/compilers /apps/modules/modulefiles/tools /apps/modules/modulefiles/libraries /apps/modules/modulefiles/environment

  module load SciPy-bundle/2023.11-gfbf-2023b
  module load GLib/2.78.1-GCCcore-13.2.0
  module load dask/2024.5.1-gfbf-2023b-Python-3.11.5
  module load xarray/2024.5.0-gfbf-2023b-Python-3.11.5
  module load netcdf4-python/1.6.5-foss-2023b
  module load geopandas/0.14.4-foss-2023b-Python-3.11.5
  module load OpenMPI/4.1.6-GCC-13.2.0
  ;;
"COMPILE_DA" | "DA")
  module load intel/2023.2.0
  module load impi/2021.10.0
  module load mkl/2023.2.0

  #specific for geos2wrf package
  module load zlib/1.3.1

  module load hdf5/1.14.1-2
  module load pnetcdf/1.12.3
  module load netcdf/2023-06-14
  
  if [[ ${REDUCED_ORIGINAL_FILES} -eq 1 ]]; then
    module use /apps/GPP/EASYBUILD/modules/all
    module load netCDF-Fortran/4.6.1-iimpi-2023a
  fi

  export SLURM_CPU_BIND=none
  run_call="mpirun -np"
  ;;
"HERMES_GR"*)
  set +ue
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module load Mamba/23.11.0-0
  source activate base
  conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/HERMES_GR_v2.1.6
  set -ue

  exec_cmd='mpirun -np'
  hermes_command='hermes_gr'
  ;;
"HERMES_BU"*)
  set +ue
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module load Mamba/23.11.0-0
  source activate base
  conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/HERMESv3_BU_v1.1.1b
  set -ue

  exec_cmd='mpirun -np'
  hermes_command='hermes_bu'
  ;;
"HERMES_SUM")
  set +ue
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module load Mamba/23.11.0-0
  source activate base
  conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/HERMESv3_GR_v3.0.0_beta
  set -ue

  hermes_command='hermes_sum'
  ;;
"HERMES_DELTA"*)
  set +ue
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module load Mamba/23.11.0-0
  source activate base
  conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/HERMESv3_D_v0.2.8
  set -ue

  exec_cmd='mpirun -np'
  hermes_command="hermes_delta"
  ;;
"HERMES_DELTA"*)
  set +ue
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module load Mamba/23.11.0-0
  source activate base
  conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/HERMESv3_D_v0.2.8
  set -ue
  exec_cmd='mpirun -np'
  ;;
"POSTPROC_SDS")
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module load Python/3.11.5-GCCcore-13.2.0
  module load xarray/2025.1.2-gfbf-2023b-Python-3.11.5
  module load CDO/2.4.4-gompi-2023b
  module load NCO/5.2.4-foss-2023b
  ;;
"POSTPROC"* | "PERTURB_HERMES" | "CALC_STATS")
  set +ue
  module use /gpfs/projects/bsc32/software/rhel/9.2/modules/all
  module load Mamba/23.11.0-0
  source activate base
  conda activate /gpfs/projects/bsc32/repository/apps/conda_envs/SNES_v1.1.8
  set -ue

  run_command="mpirun -np"
  snes_command='snes_monarch'
  ;;
"DA_PREPROC")
  module load intel/2023.2.0
  module load impi/2021.10.0
  module load hdf5/1.14.1-2
  module load pnetcdf/1.12.3
  module load netcdf/2023-06-14

  module load libexpat/2.6.2 udunits/2.2.28 nco/5.2.2
  ;;
*)
  echo "[ERROR] The ${TASKTYPE} job cannot be run on this platform!"
  exit 1
  ;;
esac
# ------------------------------------------------------------------------------------------------- #
# End of auto-monarch settings
# ------------------------------------------------------------------------------------------------- #
