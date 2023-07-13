root_dir=%CURRENT_ROOTDIR%
current_member=%MEMBER%
model=%COMMON.MODEL%

run_root=%RUN_ROOT%
inidata=%COMMON_PATH_LOCATIONS.INIDATA_ROOT%
cfg=%CFG%
analysis_tools=${cfg}/trace_analysis/

source $inidata/hardare_benchmarks/param_bash.cfg

cd $run_root/hardware_benchmarks
mkdir -p OSU_RUN/IMAGE

for test in ${osu_tests[@]}
do
    test_name=${test##*/}
    python ${cfg}/benchmarks/OSU/OSU_test_plots.py -i OSU_RUN/DATA/${test_name}* -o OSU_RUN/IMAGE/
done

python ${cfg}/benchmarks/STREAM/STREAM_data_parser.py -i STREAM_RUN --png --png-output-name STREAM_RUN/${model}.png
