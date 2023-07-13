root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%CFG%
analysis_tools=${cfg}/trace_analysis/
report_file=%REPORT.NAME%.pkl
report_conffile=%REPORT.CONFIG%

mkdir report

source ${report_conffile}
# Copy the report in the appropriate folder
report_name=${report_file%.*}
cp ${report_file} report/
#python ${latex_folder}/ReportGenerator.py -O ${report_file} --section-title "Introduction" --section-number 1 -T Introduction.txt
python ${cfg}/latex/ReportGenerator.py -O report/${report_file} --add-newcommand ${parameters_conffile}
python ${cfg}latex/ReportGenerator.py -O report/${report_file} --report-title "${title}"
python ${cfg}/latex/ReportGenerator.py -O report/${report_file} --report-authors "${authors}"
# Create the tex file
python ${cfg}/latex/ReportGenerator.py -O report/${report_file} --dump-to-file
# Compile the report
cd report; module load LATEX/20150523; pdflatex ${report_name}.tex && pdflatex ${report_name}.tex && evince ${report_name}.pdf
