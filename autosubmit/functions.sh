# Autosubmit stuff
EXP_ROOT=%CURRENT_ROOTDIR%


# Define project name and go to project folder
project=nemo_performance_profile
# Go to experiment folder
cd ${EXP_ROOT}
# Enter to repo folder
cd ${project}

# Load environment
source cfg/environment.env

# Launch functions recipe
make extrae_functions.txt
