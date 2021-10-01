cd %EXP_ROOT%
# Clone repository
git clone --single-branch --branch autosubmit https://earth.bsc.es/gitlab/ces/nemo_performance_profile.git %PROJECT_ROOT%
# Enter to repo folder
cd %PROJECT_ROOT%
#
# Launch the two commands that might require internet connection
# Prepare nemo sources
make nemo_source 
# Prepare inidata (Requires interet only if downloading zenodo data)
make inidata
