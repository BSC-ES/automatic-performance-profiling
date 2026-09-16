#!/bin/bash

#------------------------------------------------------------------------------------------------
#
# This script automatically prepares and compiles monarch v2.0 procedures
# The code from PREPROC/FIXED and PREPROC/VARIABLE will be compiled in running time, here
# we prepare the compilation flags

set -eux

#------------------------------------------------------------------------------------------------
# Parts of the system to be compiled or prepared
#------------------------------------------------------------------------------------------------
DO_PREP=1      # Compile utilities to convert preprocessor binaries to netcdf
DO_FIX=1       # Compile FIXED
DO_VAR=1       # Prepare VARIABLE running scripts
DO_MEGAN=1     # Compile PREMEGAN
DO_MODEL=1     # Compile NMMB-MONARCH model
DO_CAMP=0      # Use CAMP library in MONARCH
COMPILE_LIBS=0
#------------------------------------------------------------------------------------------------
# Main NMMB-MONARCH path
#------------------------------------------------------------------------------------------------
MONARCH=`pwd`
#------------------------------------------------------------------------------------------------
# User defined compilers, libraries, flags required
#------------------------------------------------------------------------------------------------
NETCDF=${NETCDF_ROOT}
ESMF=/apps/GPP/ESMF/8.0.1/INTEL/IMPI/lib/libO/Linux.intel.64.intelmpi.default
COMPILER=ifort
MPI_COMPILER=mpiifort
PRE_COMPILER=fpp
######################################
# Do not modify anything below
######################################
NUMPROC=8
if [ ${COMPILE_LIBS} -eq 1 ]; then
  NCEP_LIBS=$MONARCH"/MODEL/SRC_LIBS/nceplibs"
  JSON_LIBS=$MONARCH"/MODEL/SRC_LIBS/json-fortran-6.1.0/install/jsonfortran-intel-6.1.0"
  SUITESPARSE_LIBS=$MONARCH"/MODEL/SRC_LIBS/SuiteSparse"
  SUNDIALS_LIBS=$MONARCH"/MODEL/SRC_LIBS/cvode/install"
else
  NCEP_LIBS="/gpfs/projects/bsc32/share/libs/MN5/monarch/nceplibs"
  JSON_LIBS="/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/json-fortran-6.1.0/install/jsonfortran-intel-6.1.0"
  SUITESPARSE_LIBS="/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/SuiteSparse"
  SUNDIALS_LIBS="/gpfs/projects/bsc32/share/libs/MN5/monarch/camp/cvode/install"
fi
CAMP_LIBS=$MONARCH"/MODEL/SRC_LIBS/camp"
# PREPROC/binary2netcdf
export FC=$COMPILER
export FFLAGS="-free -convert big_endian"
export OPTS="-O3"
export DEBUG= #-O0 -g -traceback -debug extended
export NETCDF_LIB=$NETCDF"/lib -lnetcdf -lnetcdff"
export NETCDF_INC=$NETCDF"/include"
# PREPROC/FIX
export FFLAGS_FIX="-traceback -assume byterecl -O3 -fp-model precise -fp-stack-check -mcmodel=large -shared-intel -convert big_endian"
# PREPROC/VARIABLE
export FFLAGS_VAR="-traceback -assume byterecl -O3 -fp-model precise -fp-stack-check -mcmodel=large -shared-intel -convert big_endian -heap-arrays -extend-source"
export NETCDF_LIB_VAR=$NETCDF_LIB
export NETCDF_INC_VAR=$NETCDF_INC
export W3_LIB_VAR=$NCEP_LIBS"/lib -lw3nco_v2.0.6_4"
export BACIO_LIB_VAR=$NCEP_LIBS"/lib -lbacio_v2.0.1_4"
# PREPROC/megan
export FFLAGS_MEG="-traceback -assume byterecl -O0 -fp-model precise -fp-stack-check -mcmodel=large -shared-intel -convert big_endian"
export NETCDF_LIB_MEG=$NETCDF"/lib -lnetcdf -lnetcdff"
export NETCDF_INC_MEG=$NETCDF"/include"
# MODEL/SRC
export ESMF_PATH_MNR=$ESMF"/esmf.mk"
export NWPROD_LIB_MNR=$NCEP_LIBS
export NETCDF_LIB_MNR=$NETCDF_LIB
export NETCDF_INC_MNR=$NETCDF_INC
export NEMSIO_INC_MNR=$NWPROD_LIB_MNR"/src/nemsio_v2.2.1"
export NEMSIO_LIB_MNR=$NWPROD_LIB_MNR"/lib -lnemsio_v2.2.1"
if [ $DO_CAMP -eq 1 ]; then
  export CAMP_INC_MNR=" -I"$CAMP_LIBS"/build -I"$JSON_LIBS"/lib -I"$SUITESPARSE_LIBS"/include -I"$SUNDIALS_LIBS"/include"
  export CAMP_LIB_MNR=" -L"$CAMP_LIBS"/build -lcamp -L"$JSON_LIBS"/lib -ljsonfortran -L"$SUITESPARSE_LIBS"/lib -lklu -L"$SUNDIALS_LIBS"/lib -lsundials_nvecserial -lsundials_cvode -lsundials_sunlinsolklu -lsundials_sunmatrixsparse"
  export CAMP_FLG_MNR="-DDO_CAMP"
else
  export CAMP_INC_MNR=""
  export CAMP_LIB_MNR=""
  export CAMP_FLG_MNR=""
fi
export W3_LIB_MNR=$W3_LIB_VAR
export BACIO_LIB_MNR=$BACIO_LIB_VAR
export SP_LIB_MNR=$NWPROD_LIB_MNR"/lib -lsp_v2.0.2_4"
export FC_MNR=$MPI_COMPILER
export FPP_MNR="-fpp"
export CPP_FLAGS_MNR=""
export FREE_MNR="-free"
export FIXED_MNR="-fixed -132"
export R8_MNR="-r8"
#export DEBUG_MNR="-O0 -g -traceback -debug extended"
export DEBUG_MNR=""
export FFLAGS_MNR="-convert big_endian -assume byterecl -fp-model precise"
export OPTS_NMM_MNR="-O3"
export OPTS_GFS_MNR="-O3"
# DA
export FFLAGS_DA="-DREAL4 -DES -Dv384 -Dm5"
export MPI_FLAGS_DA="-traceback -assume byterecl -fp-stack-check -mcmodel=large -shared-intel -convert big_endian -check noarg_temp_created -g -finstrument-functions"
export PPFLAGS_DA="-C -CA -CB -CU"
export OPT_F77_DA="-O0"
export OPT_F90_DA="-O3"
export DEBUG_DA="-g"
######################################
# Start compilation and set up
######################################
#PREPROC/megan
if [ $DO_MEGAN -eq 1 ] ; then
  cd $MONARCH/PREPROC/EMISSIONS/megan/src/cmp
  rm -f ../Makefile
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_?$FFLAGS_MEG?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_MEG?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_MEG?" Makefile.cmp > ../Makefile
  cd ..
  make prepmegan
  make prepmegan-meteo
fi
# PREPROC/FIXED
if [ $DO_FIX -eq 1 ] ; then
  cd $MONARCH/PREPROC/FIXED/cmp
  rm -f ../runfixed_rrtm.scr
  sed -e "s?_FC_FIX_?$FC?" \
    -e "s?_FFLAGS_FIX_?$FFLAGS_FIX?" \
    -e "s?_FIXED_?$FIXED_MNR?" \
    -e "s?_NETCDF_LIB_?$NETCDF_LIB?" \
    -e "s?_NETCDF_INC_?$NETCDF_INC?" runfixed_rrtm.cmp > ../runfixed_rrtm.scr
  chmod u+x ../runfixed_rrtm.scr
  rm -f ../runfixed_4_nps.scr
  sed -e "s?_FC_FIX_?$FC?" \
      -e "s?_FFLAGS_FIX_?$FFLAGS_FIX?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC?" runfixed_4_nps.cmp > ../runfixed_4_nps.scr
  chmod u+x ../runfixed_4_nps.scr
  rm -f ../runfixed_pertmap.scr
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" runfixed_pertmap.cmp > ../runfixed_pertmap.scr
  chmod u+x ../runfixed_pertmap.scr
  cd $MONARCH/PREPROC/FIXED/lookup_tables/cmp
  rm -f ../run_aerosol
  sed -e "s/_FC_/$FC/" \
      -e "s?_FIXED_?$FIXED_MNR?" \
      -e "s/_FFLAGS_FIX_/$FFLAGS_FIX/" run_aerosol.cmp > ../run_aerosol
  chmod u+x ../run_aerosol
fi
# PREPROC/VARIABLE
if [ $DO_VAR -eq 1 ] ; then
  cd $MONARCH/PREPROC/VARIABLE/cmp
  rm -f ../compile_read_paul_source
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" compile_read_paul_source.cmp > ../compile_read_paul_source
  chmod u+x ../compile_read_paul_source

  rm -f ../compile_read_paul_source_mdb2.tmp
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" compile_read_paul_source_mdb2.tmp.cmp > ../compile_read_paul_source_mdb2.tmp

  rm -f ../compile_read_paul_source_mdb2_2018.tmp
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" compile_read_paul_source_mdb2_2018.tmp.cmp > ../compile_read_paul_source_mdb2_2018.tmp

  rm -f ../compile_read_source_foo_landuse.tmp
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" compile_read_source_foo_landuse.tmp.cmp > ../compile_read_source_foo_landuse.tmp

  rm -f ../compile_read_roughness_prigent.tmp
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" compile_read_roughness_prigent.tmp.cmp > ../compile_read_roughness_prigent.tmp

  cp degribifs_generic.sh ../.

  cp degribERA_generic.sh ../.

  cp degribgfs_generic_05_grib2.sh ../.

  cp degribgfs_generic_05.sh ../.

  rm -f ../runalbedo
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runalbedo.cmp > ../runalbedo
  chmod u+x ../runalbedo

  rm -f ../runalbedorrtm1deg
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runalbedorrtm1deg.cmp > ../runalbedorrtm1deg
  chmod u+x ../runalbedorrtm1deg

  rm -f ../runcnv_rrtm
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runcnv_rrtm.cmp > ../runcnv_rrtm
  chmod u+x ../runcnv_rrtm

  rm -f ../rundegribsst
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_BACIO_LIB_?$BACIO_LIB_VAR?" \
      -e "s?_W3_LIB_?$W3_LIB_VAR?" rundegribsst.cmp > ../rundegribsst
  chmod u+x ../rundegribsst

  rm -f ../runduststart
  sed -e "s?_FC_?$FC?" \
    -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?"\
    -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
    -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" runduststart.cmp > ../runduststart
  chmod u+x ../runduststart

  rm -f ../runemissivity
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" runemissivity.cmp > ../runemissivity
  chmod u+x ../runemissivity

  rm -f ../runfbare_modis.tmp
  sed -e "s?_FC_?$FC?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runfbare_modis.tmp.cmp > ../runfbare_modis.tmp

  rm -f ../runvegfra_new.tmp
  sed -e "s?_FC_?$FC?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runvegfra_new.tmp.cmp > ../runvegfra_new.tmp

  rm -f ../run_rrtm
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" run_rrtm.cmp > ../run_rrtm
  chmod u+x ../run_rrtm


  rm -f ../run_bcchem_nps
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" run_bcchem_nps.cmp > ../run_bcchem_nps
  chmod u+x ../run_bcchem_nps

  rm -f ../runvegfrac
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runvegfrac.cmp > ../runvegfrac
  chmod u+x ../runvegfrac

  rm -f ../runz0vegustar
  sed -e "s?_FC_?$FC?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runz0vegustar.cmp > ../runz0vegustar
  chmod u+x ../runz0vegustar

  rm -f ../runlai_modis.tmp
  sed -e "s?_FC_?$FC?" \
      -e "s?_NETCDF_LIB_?$NETCDF_LIB_VAR?" \
      -e "s?_NETCDF_INC_?$NETCDF_INC_VAR?" \
      -e "s?_FFLAGS_VAR_?$FFLAGS_VAR?" runlai_modis.tmp.cmp > ../runlai_modis.tmp

fi

# MODEL/SRC
if [ $DO_MODEL -eq 1 ] ; then
  cd $MONARCH/MODEL/SRC/conf
  rm -f configure.nmmb
  if [ ${COMPILE_LIBS} -eq 1 ]; then
    sed -e "s?_ESMF_PATH_MNR_?$ESMF_PATH_MNR?" \
        -e "s?_NWPROD_LIB_MNR_?$NWPROD_LIB_MNR?" \
        -e "s?_NETCDF_LIB_MNR_?$NETCDF_LIB_MNR?" \
        -e "s?_NETCDF_INC_MNR_?$NETCDF_INC_MNR?" \
        -e "s?_NEMSIO_INC_MNR_?$NEMSIO_INC_MNR?" \
        -e "s?_NEMSIO_LIB_MNR_?$NEMSIO_LIB_MNR?" \
        -e "s?_CAMP_INC_MNR_?$CAMP_INC_MNR?" \
        -e "s?_CAMP_LIB_MNR_?$CAMP_LIB_MNR?" \
        -e "s?_CAMP_FLG_MNR_?$CAMP_FLG_MNR?" \
        -e "s?_W3_LIB_MNR_?$W3_LIB_MNR?" \
        -e "s?_BACIO_LIB_MNR_?$BACIO_LIB_MNR?" \
        -e "s?_SP_LIB_MNR_?$SP_LIB_MNR?" \
        -e "s?_FC_MNR_?$FC_MNR?" \
        -e "s?_FPP_MNR_?$FPP_MNR?" \
        -e "s?_CPP_FLAGS_MNR_?$CPP_FLAGS_MNR?" \
        -e "s?_FREE_MNR_?$FREE_MNR?" \
        -e "s?_FIXED_MNR_?$FIXED_MNR?" \
        -e "s?_R8_MNR_?$R8_MNR?" \
        -e "s?_DEBUG_MNR_?$DEBUG_MNR?" \
        -e "s?_FFLAGS_MNR_?$FFLAGS_MNR?" \
        -e "s?_OPTS_NMM_MNR_?$OPTS_NMM_MNR?" \
        -e "s?_OPTS_GFS_MNR_?$OPTS_GFS_MNR?" configure.nmmb.cmp > configure.nmmb
  else
    sed -e "s?_CAMP_INC_MNR_?$CAMP_INC_MNR?" \
        -e "s?_CAMP_LIB_MNR_?$CAMP_LIB_MNR?" \
        -e "s?_CAMP_FLG_MNR_?$CAMP_FLG_MNR?" configure.nmmb.marenostrum5 > configure.nmmb
  fi
  cd $MONARCH/MODEL/SRC
  make clean
  make -j ${NUMPROC}
fi
