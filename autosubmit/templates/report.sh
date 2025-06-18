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
members="%EXPERIMENT.MEMBERS%"
configuration_name=%STRONGSCALING.TEST_CONFIG%
root_dir=%CURRENT_ROOTDIR%

# shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
. ${cfg}/utils/bash/utils.sh

components=($(bashify_array "%MODEL.REPORT_COMPONENTS%" true))

#####################################################################################################################
# Brief: Adds STREAM and OSU images to the report
# Global:
#   - Paths: run_root, report_full_path, latex_folder, cfg
#   - Other: None
# Param: None
#####################################################################################################################
function add_HardwareBenchmarks() {
    local hardware_benchmarks_root=$run_root/hardware_benchmarks
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
function add_StrongScaling() {
    local member="strong_scaling"
    local tests="%STRONGSCALING.TEST_NAMES%"
    tests=${tests//[\[,\]]/}
    tests=$(for v in $tests; do echo "$v"; done | sort | uniq | xargs)

    for test in $tests; do
        test_name=${member}/$(basename $test)
        test_root=$run_root/$test_name

        cd ${test_root} || exit

        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Scalability" \
            --add-csv cases_info.csv \
            --add-caption "Cases processors configuration" \
            -T ${cfg}/latex/text/Scalability.txt

        # Add full model scaling only if there is more than one component
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

        # Coupling info (ECE4 only)
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
    # Add whole model info only if it has more than 2 components
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
        # Add component most time consuming functions table
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} Functions detailed report" \
            -ss "Most expensive function summary" \
            --add-csv ${component}_most_expensive_function_summary.csv \
            --add-caption "Most time-consuming functions for ${component^^}." -f

        # Add papi counters plots plots
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

        # Add user functions time/PAPI/MPI scalability
        functions=$(find ${test_root}/function_csv/* | grep ${component})
        for func in ${functions}; do
            file_name=${func##*function_csv/}
            file_name=${file_name##tracking/MPI/}
            func_name=${file_name%.csv}
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "${func_name}" \
                --add-csv "function_csv/${file_name}" \
                --add-caption "$func_name scalability." --silent
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "${func_name}" \
                --add-csv "tracking/MPI/${file_name}" \
                --add-caption "$func_name MPI scalability." -p --silent
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
        # Create and add case comparison Paraver views
        for case_comparison_cfg in ${case_comparison_cfgs}; do
            local img_caption="${case_comparison_cfg} for the fastest timestep of the cases (top to bottom): "
            local case_comparison_imgs=""
            for case in paraver_images/*; do 
                img_caption+="$(basename $case) "
                case_comparison_img="$case/${case_comparison_cfg}@${component}.best_cut.png"
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
        
        # Add other Paraver views
        for case in ${test_root}/paraver_images/*; do                    
            for paraver_cfg in $paraver_cfgs; do
                echo $case_comparison_cfgs | grep -w $paraver_cfg &> /dev/null && continue
                local paraver_image="$case/$paraver_cfg@${component}.best_cut.png"
                ! [ -f $paraver_image ] && echo $paraver_image was not generated, skipping... && continue

                local paraver_caption=${paraver_image##*/}
                paraver_caption="${paraver_caption//@*} configuration for the fastest timestep in ${component^^} trace"
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Tracing" \
                    -s "${component^^} Paraver" \
                    -ss "$(basename ${case})" \
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
function add_Tracing() {
    local member="tracing"
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
        test_name=${member}/$(basename $test)
        test_root=$run_root/$test_name

        cd ${test_root} || exit

        # Create and add test configuration
        {   
            echo "Configuration,Value";
            echo "START DATE,%TRACING.START_DATE%";
            echo "END DATE,%TRACING.END_DATE%"; 
            echo "TIMESTEPS,%TRACING.TRACE_STEPS%";
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
# Brief: Adds compilation efficiency experiments comparisson to the report
# Global: None
# Param: None
#####################################################################################################################
function add_CompilationEfficiency() {
    local member="compilation_efficiency"
    local flag=-s

    # Generate tests comparisson csv
    python3 ${cfg}/parser/comparator.py \
        --json-files $run_root/$member/*/*.json \
        ${flag} \
        --file-out ${run_root}/${member}/${member}.csv

    member_title=${member//_/ }
    member_title=${member^}

    # Add cases info table
    test_folders=($run_root/$member/*/)
    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s $member_title \
        --add-csv ${test_folders[0]}/cases_info.csv \
        --add-caption "${member_title} cases info." 

    # Add model's case comparisson table and section's text
    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s $member_title \
        --add-csv ${run_root}/${member}/${member}.csv \
        --add-caption "${member_title} case comparison scalability." \
        -T ${cfg}/latex/text/${current_member}.txt
}

#####################################################################################################################
# Brief: Adds weakscaling experiments comparisson to the report
# Global: None
# Param: None
#####################################################################################################################
function add_WeakScaling() {
    local member="weakscaling"
    local flag=-w

    # Generate tests comparisson csv
    python3 ${cfg}/parser/comparator.py \
        --json-files $run_root/$member/*/*.json \
        ${flag} \
        --file-out ${run_root}/${member}/${member}.csv

    member_title=${member//_/ }
    member_title=${member^}

    # Add model's case comparisson table and section's text
    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s $member_title \
        --add-csv ${run_root}/${member}/${member}.csv \
        --add-caption "${member_title} case comparison scalability." \
        -T ${cfg}/latex/text/${current_member}.txt

    # Add models case comparisson table
    for component in "${components[@]}"; do
        python3 ${cfg}/latex/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Multi Experiment" \
            -s $member_title \
            -ss "${component^^} ${member_title}" \
            --add-csv ${run_root}/${member}/${component}_${member}.csv \
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

# Add the introduction to the report
python3 ${cfg}/latex/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    --section-title "Introduction" \
    --section-number 1 \
    -T ${cfg}/latex/Introduction.txt

# Create and add test configuration info
{   
    echo "Configuration,Value";
    echo "Resolution, %EXPERIMENT.RESOLUTION%";
    [ ${model} = "ecearth4" ] && echo "NEMO resolution,%EXPERIMENT.NEMO_RESOLUTION%";
    [ ${model} = "ecearth4" ] && echo "OIFS resolution,%EXPERIMENT.OIFS_RESOLUTION%";
    [ ${model} = "ecearth4" ] && echo "START DATE,%EXPERIMENT.START_DATE%";
    [ ${model} = "ecearth4" ] && echo "END DATE,%EXPERIMENT.END_DATE%";
    echo "TIMESTEPS,%EXPERIMENT.TEST_STEPS%";
    echo "OUTPUT,%EXPERIMENT.OUTPUT%";
    echo "PLATFORM,%DEFAULT.HPCARCH%";
} > test_info.csv

python3 ${latex_folder}/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    -S "Experiment configuration" \
    --add-caption "Experiment configuration" \
    --add-csv test_info.csv \
    -T ${cfg}/latex/text/ExperimentConfiguration.txt

# Add all members
for current_member in ${members}; do
    add_${current_member}
done

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

# Create the tex file
python3 ${cfg}/latex/ReportGenerator.py -O ${report_full_path} --dump-to-file

if ! command -v pdflatex &> /dev/null; then 
    echo pdflatex cmd not available, you can find the tex file ${report_full_path}.tex;
else
    # Compile the report
    pdflatex report.tex && pdflatex report.tex
fi