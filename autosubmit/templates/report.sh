inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
report_folder=%REPORT.FOLDER%
report_name=%REPORT.NAME%
report_conffile=%REPORT.CONFIG%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
parameters_conffile=$inidata/strong_scaling/BENCH/param_bash.cfg

source ${env_sources}
export PYTHONPATH=$PYTHONPATH:${project}

cd ${report_folder}
source ${report_conffile}
python ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --add-newcommand ${parameters_conffile}
python ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --report-title "${title}"
python ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --report-authors "${authors}"
# Create the tex file
python ${cfg}/latex/ReportGenerator.py -O ${report_name} --dump-to-file
# Compile the report
module purge
module load LATEX
pdflatex ${report_name}.tex && pdflatex ${report_name}.tex
