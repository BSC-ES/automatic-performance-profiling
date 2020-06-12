# Autosubmit stuff
EXP_ROOT=%CURRENT_ROOTDIR%
MEMBER=%MEMBER%

project=nemo_performance_profile
# Go to experiment folder
cd ${EXP_ROOT}

# Enter to repo folder
cd ${project}

# Load environment
source cfg/environment.env

# Launch trace recipe for this member
# Put any make command i.e. make trace_${MEMBER}
