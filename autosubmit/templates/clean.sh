#####################################################################################################################
# clean.sh
# Brief: This script removes all experiment folder before running the workflow
#####################################################################################################################

###################
# AS variables
###################
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
run=%COMMON_PATH_LOCATIONS.RUN_ROOT%
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
report=%REPORT.FOLDER%

chmod +w -R $inidata || :
chmod +w -R $binaries || :
chmod +w -R $compilation || :
chmod +w -R $run || :

rm -rf $inidata || :
rm -rf $binaries || :
rm -rf $compilation || :
rm -rf $run || :
rm -rf $report || :
