# Autosubmit stuff
EXP_ROOT=%CURRENT_ROOTDIR%

project=nemo_performance_profile
# Go to experiment folder
cd ${EXP_ROOT}

# Clone repository
git clone --single-branch --branch autosubmit https://earth.bsc.es/gitlab/ces/nemo_performance_profile.git ${project}

# Enter to repo folder
cd ${project}

# 


# Launch the two commands that might require internet connection
# Prepare nemo sources
make nemo_source 
# Prepare inidata (Requires interet only if downloading zenodo data)
make inidata
