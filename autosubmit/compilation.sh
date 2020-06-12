# Autosubmit stuff
EXP_ROOT=%CURRENT_ROOTDIR%
project=nemo_performance_profile
# Go to experiment folder
cd ${EXP_ROOT}

# Enter to repo folder
cd ${project}

#Load environment
source cfg/environment.env

# Compile the binaries
for flavour in vanilla trace ; do
   make bin/nemo_${flavour}.exe -j 48
done
