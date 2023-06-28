inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
binaries=%COMMON_PATH_LOCATIONS.BINARIES_ROOT%
run=%COMMON_PATH_LOCATIONS.RUN_ROOT%
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
chmod +w -R $inidata || :
chmod +w -R $binaries || :
chmod +w -R $compilation || :
chmod +w -R $run || :
rm -rf $inidata || :
rm -rf $binaries || :
rm -rf $compilation || :
rm -rf $run || :
