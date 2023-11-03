###################
# AS variables
###################
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
report_folder=%REPORT.FOLDER%
report_name=%REPORT.NAME%
report_conffile=%REPORT.CONFIG%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
parameters_conffile=$inidata/strong_scaling/BENCH/param_bash.cfg

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

cd ${report_folder}
source ${report_conffile}
python3 ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --add-newcommand ${parameters_conffile}
python3 ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --report-title "${title}"
python3 ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --report-authors "${authors}"
# Create the tex file
python3 ${cfg}/latex/ReportGenerator.py -O ${report_name} --dump-to-file
# Compile the report
pdflatex ${report_name}.tex && pdflatex ${report_name}.tex
