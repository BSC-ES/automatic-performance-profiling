#!/bin/bash
#####################################################################################################################
# report.sh
# Brief: This script generates the different members sections of the report and generates the pdf 
#####################################################################################################################

###################
# AS variables
###################
model=%MODEL.NAME%
env_sources=%PARAMETERS_ENV_CONFIG.ENV_SOURCES%
run_root=%COMMON_PATH_LOCATIONS.RUN_ROOT%
cfg=%COMMON_PATH_LOCATIONS.CFG%
latex_folder=${cfg}/latex/
report_folder=%REPORT.FOLDER%
report_conffile=%REPORT.CONFIG%
report_name=%REPORT.NAME%
report_full_path=${report_folder}/%REPORT.NAME%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%
members="%EXPERIMENT.MEMBERS%"
components="%MODEL.COMPONENTS%"
configuration_name=%STRONGSCALING.TEST_CONFIG%

components=${components//[\[,\]]/}
components=($(for v in $components; do echo "$v"; done | sort | uniq | xargs))

#####################################################################################################################
# Brief: Adds STREAM and OSU images to the report
# Global:
#   - Paths: run_root, report_full_path, latex_folder, cfg
#   - Other: None
# Param: None
#####################################################################################################################
function add_HardwareBenchmarks() {
    local hardware_benchmarks_root=$run_root/hardware_benchmarks

    for osu_img in ${hardware_benchmarks_root}/OSU_RUN/IMAGE/*.png; do
        local osu_caption=${osu_img//-/ }
        osu_caption=${osu_caption//.png}
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Hardware Benchmarks" \
            -s "OSU Benchmark" \
            --add-img ${osu_img} \
            --add-caption "${osu_caption}" \
            -T ${cfg}/latex/text/OSU.txt
    done
    python3 ${latex_folder}/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Hardware Benchmarks" \
        -s "STREAM Benchmark" \
        --add-img ${hardware_benchmarks_root}/OSU_RUN/IMAGE
}

#####################################################################################################################
# Brief: Adds scalability plots and coupling info to the report
# Global:
#   - Paths: latex_folder, report_full_path, cfg, run_root
#   - Other: components
# Param: None
#####################################################################################################################
function add_StrongScaling() {
    local member="strong_scaling"
    local tests="%STRONGSCALING.TEST_NAMES%"
    tests=${tests//[\[,\]]/}
    tests=$(for v in $tests; do echo "$v"; done | sort | uniq | xargs)

    for test in $tests; do
        test_name=${member}/$(basename $test)
        test_root=$run_root/$test_name

        cd ${test_root} || exit

        # Scalability
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Scalability" \
            --add-csv cases_info.csv \
            --add-caption "Cases processors configuration" \
            -T ${cfg}/latex/text/Scalability.txt

        # Add general model results only if there is more than one component
        if [ ${#components[@]} -gt 1 ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                --add-img ${test}_scaling.png \
                --add-caption "Scalability plot for ${model^^}" \
                --add-csv ${test}_scaling.csv
        fi

        for component in "${components[@]}"; do
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "${component^^} Scalability" \
                --add-img ${component}_${test}_scaling.png \
                --add-caption "Scalability plot for ${component^^}" \
                --add-csv ${component}_${test}_scaling.csv
        done

        # Coupling info (ECE4 only)
        if [ -d coupling ]; then
            for case in coupling/*; do
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Coupling" \
                    -s "$(basename ${case})" \
                    --add-csv ${case}/summary.csv \
                    --add-caption "Lucia results summary"
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Coupling" \
                    -s "$(basename ${case})" \
                    --add-img ${case}/stacked_events.png \
                    --add-caption "Components stacked events"
            done
        fi
    done
}

#####################################################################################################################
# Brief: Adds function info, papi counters plots, mpi info, Paraver and Dimemas images and modelfactors to the report
# Global:
#   - Paths: latex_folder, report_full_path, cfg, run_root
#   - Other: components
# Param: None
#####################################################################################################################
function add_Tracing() {
    local member="tracing"
    local papi_counters_plots="%TRACING.PAPI_COUNTERS_PLOTS%"
    local tests="%TRACING.TEST_NAMES%"
    local case_comparison_cfgs="%TRACING.PV_CASE_COMPARISSON_CFGS%"
    tests=${tests//[\[,\]]/}
    tests=$(for v in $tests; do echo "$v"; done | sort | uniq | xargs)

    # dimemas_configurations=$(find ${analysis_tools}/dimemas_configurations/platform/${platform}/*)

    for test in $tests; do
        test_name=${member}/$(basename $test)
        test_root=$run_root/$test_name

        cd ${test_root} || exit

        # Modelfactors
        for component in "${components[@]}"; do
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl\
                -S "${component^^} Model Factors" \
                --add-img modelfactors/$component \
                -T ${cfg}/latex/text/ModelFactors.txt
        done

        # Paramedir
        for trace_folder in trace_*; do
            trace_id=$(echo $trace_folder | sed 's/trace_//')
            for component in "${components[@]}"; do
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "${component^^} MPI Call Profile" \
                    --add-csv ${test_root}/paramedir/${component}-${trace_id}-MPIcallprofile.csv  --csv-convert -p -r
            done
        done

        # Function detail

        # Add general model results only if there is more than one component
        if [ ${#components[@]} -gt 1 ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Functions detailed report" \
                --add-csv cases_info.csv \
                --add-caption "Cases processors configuration"  
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Functions detailed report" \
                -T ${cfg}/latex/text/Function.txt
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Functions detailed report" \
                -s "Most expensive function summary" \
                --add-csv most_expensive_function_summary.csv \
                --add-caption "Most time-consuming functions for the whole model"
        fi

        for component in "${components[@]}"; do
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "${component^^} Functions detailed report" \
                --add-csv cases_info.csv \
                --add-caption "Cases processors configuration"
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "${component^^} Functions detailed report" \
                -s "Most expensive function summary" \
                --add-csv ${component}_most_expensive_function_summary.csv \
                --add-caption "Most time-consuming functions for ${component^^}"
            for scatter_plot in ${papi_counters_plots}; do
                local img_file=${component}-${scatter_plot}.png
                local papi_caption=${img_file//.png}
                papi_caption=${papi_caption#*-}
                papi_caption="${papi_caption//-/ vs } counters plot for ${component}"
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "${component^^} Functions detailed report" \
                    -s "PAPI counters plots" \
                    --add-img ${img_file} \
                    --add-caption "${papi_caption}"
            done
        done

        for component in "${components[@]}"; do
            functions=$(find function_csv/* | grep ${component})
            for func in ${functions}; do
                file_name=${func##function_csv/}
                file_name=${file_name##tracking/MPI/}
                func_name=${file_name%.csv}
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "${component^^} Functions detailed report" \
                    -s "${func_name}" \
                    --add-csv "function_csv/${file_name}" \
                    --add-caption "$func_name scalability" --silent
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "${component^^} Functions detailed report" \
                    -s "${func_name}" \
                    --add-csv "tracking/MPI/${file_name}" \
                    --add-caption "$func_name MPI scalability" -p --silent
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "${component^^} Functions detailed report" \
                    -s "${func_name}" \
                    --add-csv "tracking/counters/${file_name}" \
                    --add-caption "$func_name counters scalability" -p --silent 
            done
        done

        # Paraver
        if [ -d paraver_images ]; then
            for component in "${components[@]}"; do
                for case_comparison_cfg in ${case_comparison_cfgs}; do
                    local img_caption="Cases: "
                    local case_comparison_imgs=""
                    for case in paraver_images/*; do 
                        img_caption+="$(basename $case) "
                        case_comparison_imgs+="$case/${case_comparison_cfg}@${component}.best_cut.png "
                    done
                    local img_name=${component}_${case_comparison_cfg}.png
                    convert $case_comparison_imgs -append $img_name
                    python3 ${latex_folder}/ReportGenerator.py \
                        -O ${report_full_path}.pkl \
                        -S "${component^^} Paraver" \
                        -s "Case comparison" \
                        --add-img $img_name \
                        --add-caption "$img_caption"
                done
                
                for case in paraver_images/*; do                    
                    for paraver_image in $(find $case | grep -E ".*@${component}.*png" | grep -v ${case_comparison_cfg}); do
                        local paraver_caption=${paraver_image##*/}
                        paraver_caption="${paraver_caption//@*} configuration for the fastest timestep in ${component^^} trace"
                        python3 ${latex_folder}/ReportGenerator.py \
                            -O ${report_full_path}.pkl \
                            -S "${component^^} Paraver" \
                            -s "$(basename ${case})" \
                            --add-img ${paraver_image} \
                            --add-caption "${paraver_caption}"
                    done
                done
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "${component^^} Paraver" \
                    -T ${cfg}/latex/text/ParaverViews.txt
            done
        fi
    done
}

#####################################################################################################################
# Brief: Adds multi experiments comparisson to the report
# Global:
#   - Paths: cfg, run_root, report_full_path
#   - Other: None
# Param: 
#   $1 - member
#   $2 - flag to use in the multiexperiment
#####################################################################################################################
function add_multiexperiment() {
    local member=$1
    local flag=$2
    python3 ${cfg}/parser/comparator.py \
        --json-files $run_root/$member/*/*.json \
        ${flag} \
        --file-out ${member}.csv
    
    member_title=${member//_/ }
    member_title=${member^^}
    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s $member_title \
        --add-csv ${member}.csv \
        --add-caption "${member_title} case comparison scalability" 
}

#####################################################################################################################
# Brief: Adds compilation efficiency experiments comparisson to the report
# Global: None
# Param: None
#####################################################################################################################
function add_CompilationEfficiency() {
    local member="compilation_efficiency"
    local flag=-s
    add_multiexperiment $member $flag
}

#####################################################################################################################
# Brief: Adds weakscaling experiments comparisson to the report
# Global: None
# Param: None
#####################################################################################################################
function add_WeakScaling() {
    local member="weakscaling"
    local flag=-w
    add_multiexperiment $member $flag
}

###################
# Start script
###################

source ${env_sources}
set +u
export PYTHONPATH=$PYTHONPATH:${project}
set -u

rm -rf ${report_folder}
mkdir -p ${report_folder}

# Add the introduction to the report
python3 ${cfg}/latex/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    --section-title "Introduction" \
    --section-number 1 \
    -T ${cfg}/latex/Introduction.txt

# Add all members
for current_member in ${members}; do
    add_${current_member}
done

cd ${report_folder}
source ${report_conffile}
echo model=${model^^} > param.cfg
echo configuration_name=${configuration_name} >> param.cfg
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --add-newcommand param.cfg
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --report-title "${title}"
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path}.pkl --report-authors "${authors}"

# Create the tex file
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path} --dump-to-file
# Compile the report
pdflatex ${report_name}.tex && pdflatex ${report_name}.tex