#!/bin/bash
#####################################################################################################################
# report.sh
# Brief: This script generates the different members sections of the report and generates the pdf 
#####################################################################################################################

###################
# AS variables
###################
model=%MODEL.NAME%
platform=%DEFAULT.HPCARCH%
platform=${platform,,}
cfg=%COMMON_PATH_LOCATIONS.CFG%
env_sources=${cfg}/env/${platform}/environment.env
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
latex_folder=${cfg}/latex/
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
configuration_name=%STRONGSCALING.TEST_CONFIG%
root_dir=%CURRENT_ROOTDIR%

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

scalability_variable=""
if [ "${model}" == "monarch" ]; then
    scalability_variable="sdpd"
elif [ "${model}" == "hpcw" ] && [ "${components[0],,}" == "icon" ]; then
    scalability_variable="time"
fi

#####################################################################################################################
# Brief: Adds STREAM and OSU images to the report
# Global:
#   - Paths: run_root, report_full_path, latex_folder, cfg
#   - Other: None
# Param: None
#####################################################################################################################
function add_hw_benchmarks() {
    local hardware_benchmarks_root=$run_root/hw_benchmarks
    local osu_enabled=%HW_BENCHMARKS.OSU.ENABLED%
    osu_enabled=${osu_enabled,,}
    local stream_enabled=%HW_BENCHMARKS.STREAM.ENABLED%
    stream_enabled=${stream_enabled,,}

    if ${osu_enabled}; then
        for osu_img in ${hardware_benchmarks_root}/OSU_RUN/IMAGE/*.png; do
            local osu_caption=${osu_img//-/ }
            osu_caption=${osu_caption//.png}
            osu_caption=${osu_caption//*\//}
            osu_caption="${osu_caption} OSU test."
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Hardware Benchmarks" \
                -s "OSU Benchmark" \
                --add-img ${osu_img} \
                --add-caption "${osu_caption}" \
                -T ${cfg}/latex/text/OSU.txt
        done
    fi

    if ${stream_enabled}; then
        python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Hardware Benchmarks" \
                -s "STREAM Benchmark" \
                --add-img ${hardware_benchmarks_root}/STREAM_RUN/${model}.png \
                --add-caption "STREAM benchmark" \
                -T ${cfg}/latex/text/STREAM.txt
    fi
}

#####################################################################################################################
# Brief: Adds scalability plots and coupling info to the report
# Global:
#   - Paths: latex_folder, report_full_path, cfg, run_root
#   - Other: components
# Param: None
#####################################################################################################################
function add_strongscaling() {
    local tests="%STRONGSCALING.TEST_NAMES%"
    tests=${tests//[\[,\]]/}
    tests=$(for v in $tests; do echo "$v"; done | sort | uniq | xargs)

    for test in $tests; do
        test_name=${current_member}/$(basename $test)
        test_root=$run_root/$test_name

        cd ${test_root} || exit

        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Scalability" \
            --add-csv cases_info.csv \
            --add-caption "Cases processors configuration" \
            -T ${cfg}/latex/text/Scalability.txt

            if [ ${#components[@]} -gt 1 ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                --add-img ${test}_scaling.png \
                --add-caption "Scalability plot for ${model^^}."
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                --add-caption "Scalability table for ${model^^}." \
                --add-csv ${test}_scaling.csv
        fi

        for component in "${components[@]}"; do
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                -s "${component^^} Scalability" \
                --add-img ${component}_${test}_scaling.png \
                --add-caption "Scalability plot for ${component^^}."
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                -s "${component^^} Scalability" \
                --add-caption "Scalability table for ${component^^}." \
                --add-csv ${component}_${test}_scaling.csv
        done

        coupling_enabled="%STRONGSCALING.COUPLING_REPORT.ENABLED%"
        coupling_enabled=${coupling_enabled,,}
        if ${coupling_enabled} && [ ${model} = "ecearth4" ]; then
            for case in coupling/*; do
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Scalability" \
                    -s "Coupling" \
                    -ss "$(basename ${case})" \
                    --add-csv ${case}/summary.csv \
                    --add-caption "Lucia results summary."
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Scalability" \
                    -s "Coupling" \
                    -ss "$(basename ${case})" \
                    --add-img ${case}/stacked_events.png \
                    --add-caption "Components' coupling stacked events."
            done
        fi
    done
}

function add_user_functions() {
    if [ ${#components[@]} -gt 1 ]; then
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "Functions detailed report" \
            -T ${cfg}/latex/text/Function.txt
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "Functions detailed report" \
            -ss "Most expensive function summary" \
            --add-csv most_expensive_function_summary.csv \
            --add-caption "Most time-consuming functions for the whole model." -f
    fi

    for component in "${components[@]}"; do
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} Functions detailed report" \
            -ss "Most expensive function summary" \
            --add-csv ${component}_most_expensive_function_summary.csv \
            --add-caption "Most time-consuming functions for ${component^^}." -f

        local papi_counters_plots="%TRACING.USER_FUNCTIONS.PAPI_COUNTERS.PLOTS%"
        for papi_counter_plot in ${papi_counters_plots}; do
            local img_file=${component}-${papi_counter_plot}.png
            local papi_caption=${img_file//.png}
            papi_caption=${papi_caption#*-}
            papi_caption="${papi_caption//-/ vs } counters plot for ${component}."
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "PAPI counters plots" \
                --add-img ${img_file} \
                --add-caption "${papi_caption}"
        done

        function_csv_functions=$(find ${test_root}/function_csv/ -type f ! -empty | { grep "${component}" || true; })
        for file_path in ${function_csv_functions}; do
            file_name=$(basename ${file_path})
            func_name=${file_name%.csv}
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "${func_name}" \
                --add-csv "function_csv/${file_name}" \
                --add-caption "$func_name scalability." --silent
        done

        tracking_mpi_functions=$(find ${test_root}/tracking/MPI/ -type f ! -empty | { grep "${component}" || true; })
        for file_path in ${tracking_mpi_functions}; do
            file_name=$(basename ${file_path})
            func_name=${file_name%.csv}
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "${func_name}" \
                --add-csv "tracking/MPI/${file_name}" \
                --add-caption "$func_name MPI scalability." -p --silent
        done

        tracking_counters_functions=$(find ${test_root}/tracking/counters/ -type f ! -empty | { grep "${component}" || true; })
        for file_path in ${tracking_counters_functions}; do
            file_name=$(basename ${file_path})
            func_name=${file_name%.csv}
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "${func_name}" \
                --add-csv "tracking/counters/${file_name}" \
                --add-caption "$func_name counters scalability." -p --silent 
        done
    done
}

function add_paraver() {
    local case_comparison_cfgs="%TRACING.PARAVER.COMPARE_CFGS%"
    local paraver_cfgs="%TRACING.PARAVER.CFGS%"
    for component in "${components[@]}"; do
        for case_comparison_cfg in ${case_comparison_cfgs}; do
            local img_caption="${case_comparison_cfg} for the fastest timestep of the cases (top to bottom): "
            local case_comparison_imgs=""
            for case in "${tracing_names[@]}"; do
                case_paraver_folder=${test_root}/paraver_images/${case}
                img_caption+="${case} "
                case_comparison_img="${case_paraver_folder}/${case_comparison_cfg}@${component}.best_cut.png"
                ! [ -f $case_comparison_img ] && echo $case_comparison_img was not generated, skipping... && continue
                case_comparison_imgs+="$case_comparison_img "
            done
            local img_name=${component}_${case_comparison_cfg}.png
            convert $case_comparison_imgs -append $img_name
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Paraver" \
                -ss "Case comparison" \
                --add-img $img_name \
                --add-caption "$img_caption."
        done
        
        for case in "${tracing_names[@]}"; do                    
            for paraver_cfg in $paraver_cfgs; do
                case_paraver_folder=${test_root}/paraver_images/${case}
                echo $case_comparison_cfgs | grep -w $paraver_cfg &> /dev/null && continue
                local paraver_image="${case_paraver_folder}/$paraver_cfg@${component}.best_cut.png"
                ! [ -f $paraver_image ] && echo $paraver_image was not generated, skipping... && continue

                local paraver_caption=${paraver_image##*/}
                paraver_caption="${paraver_caption//@*} configuration for the fastest timestep in ${component^^} trace for case ${case}."
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Tracing" \
                    -s "${component^^} Paraver" \
                    -ss "${case}" \
                    --add-img ${paraver_image} \
                    --add-caption "${paraver_caption}."
            done
        done
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} Paraver" \
            -T ${cfg}/latex/text/ParaverViews.txt
    done
}

function add_modelfactors() {
    for component in "${components[@]}"; do
        for modelfactors_img in modelfactors/$component/*.png; do
            local modelfactors_caption=$(basename $modelfactors_img)
            modelfactors_caption=${modelfactors_caption//-matplot\.png}
            modelfactors_caption=${modelfactors_caption//-/ }
            if [[ $modelfactors_caption == "modelfactors"* ]]; then
                modelfactors_caption="${component^} $modelfactors_caption"
            else 
                modelfactors_caption="${component^} modelfactors $modelfactors_caption"
            fi

            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl\
                -S "Tracing" \
                -s "${component^^} Model Factors" \
                --add-img ${modelfactors_img} \
                --add-caption "${modelfactors_caption}." \
                -T ${cfg}/latex/text/ModelFactors.txt
        done
    done
}

function add_mpi() {
    for trace_id in "${tracing_names[@]}"; do
        for component in "${components[@]}"; do
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} MPI Call Profile" \
                --add-csv ${test_root}/paramedir/${component}-${trace_id}-MPIcallprofile.csv \
                --add-caption "${trace_id} case MPI Call profile." \
                --csv-convert -p -r -f
        done
    done
}

#####################################################################################################################
# Brief: Adds function info, papi counters plots, mpi info, Paraver and Dimemas images and modelfactors to the report
# Global:
#   - Paths: latex_folder, report_full_path, cfg, run_root
#   - Other: components
# Param: None
#####################################################################################################################
function add_tracing() {
    local tests="%TRACING.TEST_NAMES%"
    tracing_names="%TRACING.NAMES%"
    tracing_names=(${tracing_names//[\[,\]\']/})
    tests=${tests//[\[,\]]/}
    tests=$(for v in $tests; do echo "$v"; done | sort | uniq | xargs)

    local paraver_enabled="%TRACING.PARAVER.ENABLED%"
    paraver_enabled=${paraver_enabled,,}
    local uf_enabled="%TRACING.USER_FUNCTIONS.ENABLED%"
    uf_enabled=${uf_enabled,,}
    local modelfactors_enabled="%TRACING.MODELFACTORS.ENABLED%"
    modelfactors_enabled=${modelfactors_enabled,,}
    local mpi_enabled="%TRACING.MPI.ENABLED%"
    mpi_enabled=${mpi_enabled,,}

    for test in $tests; do
        test_name=${current_member}/$(basename $test)
        test_root=$run_root/$test_name

        cd ${test_root} || exit

        {   
            echo "Configuration,Value";
            if [ ${model} != "monarch" ]; then
                echo "START DATE,%TRACING.START_DATE%";
                echo "END DATE,%TRACING.END_DATE%";
                echo "TIMESTEPS,%TRACING.TRACE_STEPS%";
            else
                echo "NHOURS,%TRACING.NHOURS%";
            fi
        } > test_info.csv
    
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            --add-caption "Test configuration." \
            --add-csv test_info.csv

        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "Functions detailed report" \
            --add-csv cases_info.csv \
            --add-caption "Cases processors configuration."  

        ${modelfactors_enabled} && add_modelfactors

        ${mpi_enabled} && add_mpi

        ${uf_enabled} && add_user_functions

        ${paraver_enabled} && add_paraver
    done

    return 0
}

#####################################################################################################################
# Brief: Adds compilation efficiency experiments comparisons to the report
# Global: None
# Param: None
#####################################################################################################################
function add_compilation_efficiency() {
    local ce_names="%COMPILATION_EFFICIENCY.TEST_NAMES%"
    ce_names=($(bashify_array "${ce_names}" true))
    local flags="-s"

    [ -n "${scalability_variable}" ] && flags+=" --scalability-variable ${scalability_variable}"

    json_files=""
    multiexperiment_id=""
    for ce_name in "${ce_names[@]}"; do
        json_files+="${run_root}/${current_member}/${ce_name}/${ce_name}.json "
        multiexperiment_id+="${ce_name}-"
    done

    python3 ${cfg}/parser/comparator.py \
        --json-files ${json_files}  \
        ${flags} \
        --out-dir ${run_root}/${current_member}/

    member_title=${current_member//_/ }
    member_title=${member_title^}

    test_folders=($run_root/$current_member/*/)
    for test_folder in "${test_folders[@]}"; do
        python3 ${cfg}/latex/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Multi Experiment" \
            -s "${member_title}" \
            --add-csv ${test_folder}/cases_info.csv \
            --add-caption "$(basename ${test_folder}) cases info." 
    done

    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s "${member_title}" \
        --add-csv ${run_root}/${current_member}/${multiexperiment_id}scaling.csv \
        --add-caption "${member_title} case comparison scalability table." \
        -T ${cfg}/latex/text/${current_member,,}.txt

    python3 ${latex_folder}/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s "${member_title}" \
        --add-img ${run_root}/${current_member}/${multiexperiment_id}scaling.png \
        --add-caption "${member_title} case comparison scalability plot."
}

#####################################################################################################################
# Brief: Adds weakscaling experiments comparisson to the report
# Global: None
# Param: None
#####################################################################################################################
function add_weakscaling() {
    local flag=-w

    [ -n "${scalability_variable}" ] && flag+=" --scalability-variable ${scalability_variable}"

    python3 ${cfg}/parser/comparator.py \
        --json-files $run_root/$current_member/*/*.json \
        ${flag} \
        --file-out ${run_root}/${current_member}/${current_member}.csv

    member_title=${current_member//_/ }
    member_title=${member_title^}

    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s $member_title \
        --add-csv ${run_root}/${current_member}/${current_member}.csv \
        --add-caption "${member_title} case comparison scalability." \
        -T ${cfg}/latex/text/${current_member,,}.txt

    for component in "${components[@]}"; do
        python3 ${cfg}/latex/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Multi Experiment" \
            -s $member_title \
            -ss "${component^^} ${member_title}" \
            --add-csv ${run_root}/${current_member}/${component}_${current_member}.csv \
            --add-caption "${component^^} ${member_title} case comparison scalability."
    done
}

###################
# Start script
###################

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

report_folder=${root_dir}/report/
report_full_path=${report_folder}/report
rm -rf ${report_folder}
mkdir -p ${report_folder}

python3 ${cfg}/latex/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    --section-title "Introduction" \
    --section-number 1 \
    -T ${cfg}/latex/Introduction.txt

{   
    echo "Configuration,Value";
    [ "%EXPERIMENT.RESOLUTION%" != "" ] && echo "Resolution, %EXPERIMENT.RESOLUTION%";
    [ "%EXPERIMENT.TEST_STEPS%" != "" ] && echo "TIMESTEPS,%EXPERIMENT.TEST_STEPS%";
    [ "%EXPERIMENT.OUTPUT%" != "" ] && echo "OUTPUT,%EXPERIMENT.OUTPUT%";
    [ ${model} = "ecearth4" ] && echo "NEMO resolution,%EXPERIMENT.NEMO_RESOLUTION%";
    [ ${model} = "ecearth4" ] && echo "OIFS resolution,%EXPERIMENT.OIFS_RESOLUTION%";
    [ ${model} = "ecearth4" ] && echo "START DATE,%EXPERIMENT.START_DATE%";
    [ ${model} = "ecearth4" ] && echo "END DATE,%EXPERIMENT.END_DATE%";
    [ ${model} = "monarch" ] && echo "DATELIST,%EXPERIMENT.DATELIST%";
    [ ${model} = "monarch" ] && echo "START_HOUR,%MONARCH.HOUR%";
    [ ${model} = "monarch" ] && echo "SPINUP_HOURS,%MONARCH.SPINUP%";
    [ ${model} = "monarch" ] && echo "FORECAST_HOURS,%MONARCH.NHOURS%";
    echo "PLATFORM,%DEFAULT.HPCARCH%";
} > test_info.csv

python3 ${latex_folder}/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    -S "Experiment configuration" \
    --add-caption "Experiment configuration" \
    --add-csv test_info.csv \
    -T ${cfg}/latex/text/ExperimentConfiguration.txt


declare -A enabled_members=(
    ["tracing"]="%EXPERIMENT.APP_TESTS.TRACING.ENABLED%"
    ["strongscaling"]="%EXPERIMENT.APP_TESTS.STRONGSCALING.ENABLED%"
    ["weakscaling"]="%EXPERIMENT.APP_TESTS.WEAKSCALING.ENABLED%"
    ["compilation_efficiency"]="%EXPERIMENT.APP_TESTS.COMPILATION_EFFICIENCY.ENABLED%"
)
for current_member in "${!enabled_members[@]}"; do
    if ${enabled_members[$current_member],,}; then
        add_${current_member,,}
    fi
done

python3 ${cfg}/latex/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    --section-title "Glossary" \
    -T ${cfg}/latex/text/Glossary.txt

cd ${report_folder} || exit
echo model=${model^^} > param.cfg
echo configuration_name=${configuration_name} >> param.cfg
title="%REPORT.TITLE%"
authors="%REPORT.AUTHORS%"
logo_path="%REPORT.LOGO_PATH%"
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --add-newcommand param.cfg
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --report-title "${title}"
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --report-authors "${authors}"
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --logo-path "${logo_path}"

python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path} --dump-to-file

if ! command -v pdflatex &> /dev/null; then 
    echo pdflatex cmd not available, you can find the tex file ${report_full_path}.tex;
else
    pdflatex --shell-escape report.tex && pdflatex report.tex
fi