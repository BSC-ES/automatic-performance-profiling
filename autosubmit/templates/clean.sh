# This file cleans up all the directories produced by the previous run, to have a clean start while testing/developing
# There should be added a clean job that actually cleans the part that is not usefull after the traces are produced
# All these %_% placeholders are replaced by autosubmit with the data found in the YAML files.
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
