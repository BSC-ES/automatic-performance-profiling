root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
analysis_tools=${cfg}/trace_analysis/
report_path=%REPORT.PATH%
report_name=%REPORT.NAME%
report_conffile=%REPORT.CONFIG%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
parameters_conffile=$inidata/strong_scaling/param_bash.cfg

source ${env_sources}
export PYTHONPATH=$PYTHONPATH:${project}

cd ${report_path}
source ${report_conffile}
python ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --add-newcommand ${parameters_conffile}
python ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --report-title "${title}"
python ${cfg}/latex/ReportGenerator.py -O ${report_name}.pkl --report-authors "${authors}"
# Create the tex file
python ${cfg}/latex/ReportGenerator.py -O ${report_name} --dump-to-file
# Compile the report
module load LATEX/20150523; pdflatex ${report_name}.tex && pdflatex ${report_name}.tex
