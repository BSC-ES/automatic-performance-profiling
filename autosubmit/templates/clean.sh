chmod +w -R %INIDATA_ROOT% || :
chmod +w -R %BINARIES_ROOT% || :
chmod +w -R %RUN_ROOT% || :
chmod +w -R %COMPILATION_ROOT% || :
rm -rf %INIDATA_ROOT%
rm -rf %BINARIES_ROOT%
rm -rf %RUN_ROOT%
rm -rf %COMPILATION_ROOT%