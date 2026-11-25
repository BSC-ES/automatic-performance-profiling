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

report_model=${model}
if [ "${model}" == "hpcw" ] && [ ${#components[@]} -eq 1 ]; then
    report_model="hpcw ${components[0]}"
fi

scalability_variable=""
if [ "${model}" == "monarch" ]; then
    scalability_variable="sdpd"
elif [ "${model}" == "hpcw" ] && [ "${components[0],,}" == "icon" ]; then
    scalability_variable="time"
fi

scalability_metric="simulated years per day (SYPD)"
case "${scalability_variable}" in
    sdpd) scalability_metric="simulated days per day (SDPD)";;
    time) scalability_metric="integration time in seconds";;
esac

# Geometry of the cases of a test, in the caption of every table of cases: what each column holds
cases_caption="The cases of the test, with the MPI tasks, the OpenMP threads per task and the total processing units of each case"

#####################################################################################################################
# Brief: Name of a PAPI counter with its unit, as the tables and captions of the report write it
# Param:
#   - 1: PAPI id of the counter, e.g. PAPI_L3_TCM
#####################################################################################################################
function counter_label() {
    local counter=${1#PAPI_}
    local unit=""
    case "${counter}" in
        IPC) unit=" (instructions per cycle)";;
        TOT_CYC) unit=" (cycles)";;
        TOT_INS) unit=" (instructions, scaled in the trace)";;
        L1_DCM|L2_DCM|L3_TCM) unit=" (misses per 1000 instructions)";;
    esac
    echo "${counter}${unit}"
}

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

    if ${osu_enabled} || ${stream_enabled}; then
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Hardware Benchmarks" \
            -T ${cfg}/latex/text/HardwareBenchmarks.txt
    fi

    if ${osu_enabled}; then
        for osu_img in ${hardware_benchmarks_root}/OSU_RUN/IMAGE/*.png; do
            local osu_caption=${osu_img##*/}
            osu_caption=${osu_caption%.png}
            osu_caption=${osu_caption//_/ }
            osu_caption=${osu_caption//-/ }
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Hardware Benchmarks" \
                -s "OSU Benchmark" \
                --add-img ${osu_img} \
                --add-caption "OSU micro benchmark ${osu_caption} on the ${platform^^} platform: latency (us) or bandwidth (MB/s) against the message size, with both axes on a logarithmic scale and one line per number of processes." \
                -T ${cfg}/latex/text/OSU.txt
        done
    fi

    if ${stream_enabled}; then
        python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Hardware Benchmarks" \
                -s "STREAM Benchmark" \
                --add-img ${hardware_benchmarks_root}/STREAM_RUN/${model}.png \
                --add-caption "STREAM benchmark on the ${platform^^} platform: sustained memory bandwidth (MB/s) of the copy, scale, add and triad kernels against the number of threads of the node." \
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
    add_test_info strongscaling "Strong scaling" "Scalability" "Test configuration"

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
            -T ${cfg}/latex/text/Scalability.txt
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Scalability" \
            -s "Test configuration" \
            --add-csv cases_info.csv \
            --add-caption "${cases_caption}."

        if [ ${#components[@]} -gt 1 ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                --add-img ${test}_scaling.png \
                --add-caption "Strong scaling of ${report_model^^} (test ${test}): ${scalability_metric} of every case against the total number of processing units. The dots are the measured cases and the dotted line is the ideal scaling extrapolated from the reference case."
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                --add-caption "Strong scaling of ${report_model^^} (test ${test}): total processing units, MPI tasks, threads, ${scalability_metric}, speedup and efficiency of every case. Speedup and efficiency are ratios, so they have no unit." \
                --add-csv ${test}_scaling.csv
        fi

        for component in "${components[@]}"; do
            # The model name adds nothing when the model is the component ("NEMO component of NEMO")
            test_subject="${component^^} component"
            [[ "${report_model,,}" != *"${component,,}"* ]] && test_subject+=" of ${report_model^^}"
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                -s "${component^^} Scalability" \
                --add-img ${component}_${test}_scaling.png \
                --add-caption "Strong scaling of the ${test_subject} (test ${test}): ${scalability_metric} of every case against the total number of processing units. The dots are the measured cases and the dotted line is the ideal scaling extrapolated from the reference case."
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Scalability" \
                -s "${component^^} Scalability" \
                --add-caption "Strong scaling of the ${test_subject} (test ${test}): total processing units, MPI tasks, threads, ${scalability_metric}, speedup and efficiency of every case. Speedup and efficiency are ratios, so they have no unit." \
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
                    --add-caption "Coupling cost of case $(basename ${case}), as reported by Lucia: number of MPI tasks, core hours per simulated year (chsy), coupling cost, waiting time and interpolation time of every component and of the coupled model."
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Scalability" \
                    -s "Coupling" \
                    -ss "$(basename ${case})" \
                    --add-img ${case}/stacked_events.png \
                    --add-caption "Coupling of case $(basename ${case}): time line of the coupling events of every component, from the trace produced by Lucia, with the events stacked on top of each other."
            done
        fi
    done
}

function add_user_functions() {
    if [ ${#components[@]} -gt 1 ]; then
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "Whole-model functions" \
            -T ${cfg}/latex/text/Function.txt
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "Whole-model functions" \
            -ss "Most expensive function summary" \
            -T ${cfg}/latex/text/FunctionSummary.txt \
            --add-csv most_expensive_function_summary.csv \
            --add-caption "The most time-consuming user functions of the whole model, ranked by the time they take, in percent of the fastest timestep of each case."
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "Whole-model functions" \
            -ss "Most expensive function summary" \
            --add-img function_time_share.png \
            --add-caption "Share of the fastest timestep of each traced case spent in the most time-consuming user functions of the whole model, in percent."
    fi

    for component in "${components[@]}"; do
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} Functions detailed report" \
            -T ${cfg}/latex/text/Function.txt
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} Functions detailed report" \
            -ss "Most expensive function summary" \
            -T ${cfg}/latex/text/FunctionSummary.txt \
            --add-csv ${component}_most_expensive_function_summary.csv \
            --add-caption "The most time-consuming ${component^^} user functions, ranked by the time they take, in percent of the fastest timestep of each case."
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} Functions detailed report" \
            -ss "Most expensive function summary" \
            --add-img ${component}_function_time_share.png \
            --add-caption "Share of the fastest timestep of each traced case spent in the most time-consuming ${component^^} user functions, in percent."

        local papi_counters_plots="%TRACING.USER_FUNCTIONS.PAPI_COUNTERS.VS_PLOTS%"
        if [ -n "${papi_counters_plots}" ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "PAPI counters plots" \
                -T ${cfg}/latex/text/PapiCounters.txt
        fi
        for papi_counter_plot in ${papi_counters_plots}; do
            local img_file=${component}-${papi_counter_plot}.png
            local first_counter=${papi_counter_plot%%-*}
            local second_counter=${papi_counter_plot##*-}
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "PAPI counters plots" \
                --add-img ${img_file} \
                --add-caption "$(counter_label "${first_counter}") against $(counter_label "${second_counter}") of the ${component^^} user functions."
        done

        tracking_mpi_table=${test_root}/tracking/MPI/${component}_functions.csv
        if [ -s "${tracking_mpi_table}" ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "Function MPI scalability" \
                -T ${cfg}/latex/text/FunctionMPI.txt \
                --add-csv "tracking/MPI/${component}_functions.csv" \
                --add-caption "MPI call profile of the most expensive ${component^^} user functions, in percent of the time inside each function." \
                -g --silent
        fi

        component_function_mpi_share=${component}_function_mpi_share.png
        if [ -s "${component_function_mpi_share}" ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "Function MPI scalability" \
                --add-img ${component_function_mpi_share} \
                --add-caption "Share of the time of each ${component^^} user function spent in each MPI call, in percent."
        fi

        tracking_counter_table=${test_root}/tracking/counters/${component}_functions.csv
        if [ -s "${tracking_counter_table}" ]; then
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "Function counter scalability" \
                -T ${cfg}/latex/text/FunctionCounters.txt \
                --add-csv "tracking/counters/${component}_functions.csv" \
                --add-caption "Hardware counters of the most expensive ${component^^} user functions." \
                -g --silent
        fi

        local counters_plots="%TRACING.USER_FUNCTIONS.PAPI_COUNTERS.SCALABILITY_PLOTS%"
        for counter in ${counters_plots}; do
            component_counters_plot=${component}_function_counters_${counter}.png
            [ -s "${component_counters_plot}" ] || continue
            local counter_text
            counter_text=$(counter_label "${counter}")
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "Function counter scalability" \
                --add-img ${component_counters_plot} \
                --add-caption "${counter_text} of the ${component^^} user functions against the number of MPI tasks of each traced case."
        done

        function_csv_functions=$(find ${test_root}/function_csv/ -type f ! -empty | { grep "${component}" || true; })
        for file_path in ${function_csv_functions}; do
            file_name=$(basename ${file_path})
            func_name=${file_name%.csv}
            local function_label=${func_name#"${component}_"}
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} Functions detailed report" \
                -ss "${func_name}" \
                --add-csv "function_csv/${file_name}" \
                --add-caption "Time scalability of the ${component^^} user function ${function_label}: number of MPI tasks, speedup and efficiency of every traced case." --silent
        done
    done
}

function add_paraver() {
    local case_comparison_cfgs="%TRACING.PARAVER.COMPARE_CFGS%"
    local paraver_cfgs="%TRACING.PARAVER.CFGS%"
    for component in "${components[@]}"; do
        for case_comparison_cfg in ${case_comparison_cfgs}; do
            local img_caption="${case_comparison_cfg} view of the fastest timestep of each ${component^^} traced case, top to bottom: "
            local case_comparison_imgs=""
            for case in "${tracing_names[@]}"; do
                case_paraver_folder=${test_root}/paraver_images/${case}
                img_caption+="${case}, "
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
                --add-caption "${img_caption%, }."
        done

        for case in "${tracing_names[@]}"; do
            for paraver_cfg in $paraver_cfgs; do
                case_paraver_folder=${test_root}/paraver_images/${case}
                echo $case_comparison_cfgs | grep -w $paraver_cfg &> /dev/null && continue
                local paraver_image="${case_paraver_folder}/$paraver_cfg@${component}.best_cut.png"
                ! [ -f $paraver_image ] && echo $paraver_image was not generated, skipping... && continue

                local paraver_caption="${paraver_cfg}"
                python3 ${latex_folder}/ReportGenerator.py \
                    -O ${report_full_path}.pkl \
                    -S "Tracing" \
                    -s "${component^^} Paraver" \
                    -ss "${case}" \
                    --add-img ${paraver_image} \
                    --add-caption "${paraver_caption} view of the fastest timestep of case ${case} in the ${component^^} trace."
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
    for component in "${components[@]}"; do
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} MPI Call Profile" \
            -T ${cfg}/latex/text/MPI.txt
    done

    for trace_id in "${tracing_names[@]}"; do
        for component in "${components[@]}"; do
            python3 ${latex_folder}/ReportGenerator.py \
                -O ${report_full_path}.pkl \
                -S "Tracing" \
                -s "${component^^} MPI Call Profile" \
                --add-csv ${test_root}/paramedir/${component}-${trace_id}-MPIcallprofile.csv \
                --add-caption "MPI call profile of case ${trace_id} in the ${component^^} trace, in percent of the traced window." \
                --csv-convert -p -r
        done
    done

    for component in "${components[@]}"; do
        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "${component^^} MPI Call Profile" \
            --add-img ${component}_mpi_profile_share.png \
            --add-caption "Share of the MPI call time spent in each MPI call of ${component^^}, in percent."
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
    add_test_info tracing "Tracing" "Tracing" "Test configuration"

    python3 ${latex_folder}/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Tracing" \
        -T ${cfg}/latex/text/Tracing.txt

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

        python3 ${latex_folder}/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Tracing" \
            -s "Test configuration" \
            --add-csv cases_info.csv \
            --add-caption "${cases_caption}."

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

    # Captions name the builds, not the member title, which already says it is compilation efficiency
    builds=$(echo "${multiexperiment_id%-}" | sed 's/-/, /g')

    add_test_info compilation_efficiency "Compilation efficiency" "Multi Experiment" "${member_title}" "Test configuration"

    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s "${member_title}" \
        -T ${cfg}/latex/text/compilation_efficiency.txt

    test_folders=($run_root/$current_member/*/)
    for test_folder in "${test_folders[@]}"; do
        python3 ${cfg}/latex/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Multi Experiment" \
            -s "${member_title}" \
            -ss "Test configuration" \
            --add-csv ${test_folder}/cases_info.csv \
            --add-caption "The cases of build $(basename ${test_folder}): the MPI tasks, the OpenMP threads per task and the total processing units of each case."
    done

    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s "${member_title}" \
        -ss "Results" \
        --add-csv ${run_root}/${current_member}/${multiexperiment_id}scaling.csv \
        --add-caption "Compilation efficiency of the builds ${builds}: ${scalability_metric} of every case of each build, as value ± standard deviation, and the difference in % with respect to the first build. Every build runs the same configuration with the same number of processing units, so the difference isolates the effect of the build."

    python3 ${latex_folder}/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s "${member_title}" \
        -ss "Results" \
        --add-img ${run_root}/${current_member}/${multiexperiment_id}scaling.png \
        --add-caption "Compilation efficiency of the builds ${builds}: ${scalability_metric} of every build against the total number of processing units, one line per build. There is no ideal line here: the build with the lowest time, or the highest throughput, is the best one."
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

    add_test_info weakscaling "Weak scaling" "Multi Experiment" "${member_title}" "Test configuration"

    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s "${member_title}" \
        -T ${cfg}/latex/text/weakscaling.txt

    python3 ${cfg}/latex/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        -S "Multi Experiment" \
        -s $member_title \
        -ss "Results" \
        --add-csv ${run_root}/${current_member}/${current_member}.csv \
        --add-caption "Weak scaling: the resolution in grid points of every component and the number of grid points of each case, one row per case. The problem size grows with the number of processing units, so the workload per processing unit must stay constant."

    for component in "${components[@]}"; do
        python3 ${cfg}/latex/ReportGenerator.py \
            -O ${report_full_path}.pkl \
            -S "Multi Experiment" \
            -s $member_title \
            -ss "${component^^} Results" \
            --add-csv ${run_root}/${current_member}/${component}_${current_member}.csv \
            --add-caption "Weak scaling of the ${component^^} component: the number of MPI tasks, the resolution, the timesteps per second (1/s) and the number of grid points of each case. The timesteps per second must stay constant when the problem size grows with the resources."
    done
}

#####################################################################################################################
# Brief: Writes the experiment-wide configuration table of the report
# Global:
#   - Other: model
# Param: None
#####################################################################################################################
function test_info()
{
    echo "Configuration,Value";
    test_info_${model}
    echo "PLATFORM,%DEFAULT.HPCARCH%";
}

function test_info_ecearth4()
{
    [ "%EXPERIMENT.RESOLUTION%" != "" ] && echo "Resolution, %EXPERIMENT.RESOLUTION%";
    [ "%EXPERIMENT.TEST_STEPS%" != "" ] && echo "TIMESTEPS,%EXPERIMENT.TEST_STEPS%";
    [ "%EXPERIMENT.OUTPUT%" != "" ] && echo "OUTPUT,%EXPERIMENT.OUTPUT%";
    for comp in "${components[@]}"; do
        case "${comp,,}" in
            nemo) echo "NEMO resolution,%EXPERIMENT.NEMO_RESOLUTION%";;
            oifs) echo "OIFS resolution,%EXPERIMENT.OIFS_RESOLUTION%";;
        esac
    done
    echo "START DATE,%EXPERIMENT.START_DATE%";
    echo "END DATE,%EXPERIMENT.END_DATE%";
}

function test_info_hpcw()
{
    echo "MODEL,${components[0]^^}";
}

function test_info_monarch()
{
    echo "DATELIST,%EXPERIMENT.DATELIST%";
    echo "START_HOUR,%MONARCH.HOUR%";
    echo "SPINUP_HOURS,%MONARCH.SPINUP%";
    echo "FORECAST_HOURS,%MONARCH.NHOURS%";
}

function test_info_nemo()
{
    [ "%EXPERIMENT.RESOLUTION%" != "" ] && echo "RESOLUTION, %EXPERIMENT.RESOLUTION%";
    [ "%EXPERIMENT.TEST_STEPS%" != "" ] && echo "TIMESTEPS,%EXPERIMENT.TEST_STEPS%";
    [ "%EXPERIMENT.OUTPUT%" != "" ] && echo "OUTPUT,%EXPERIMENT.OUTPUT%";
}

function test_info_toy()
{
    [ "%EXPERIMENT.RESOLUTION%" != "" ] && echo "RESOLUTION, %EXPERIMENT.RESOLUTION%";
    [ "%EXPERIMENT.TEST_STEPS%" != "" ] && echo "TIMESTEPS,%EXPERIMENT.TEST_STEPS%";
    echo "COMPONENTS,${components[*]}";
}

function test_info_strongscaling()
{
    [ "%STRONGSCALING.TEST_CONFIG%" != "" ] && echo "CONFIGURATION,%STRONGSCALING.TEST_CONFIG%";
    [ "%STRONGSCALING.TEST_STEPS%" != "" ] && echo "TIMESTEPS,%STRONGSCALING.TEST_STEPS%";
    [ "%STRONGSCALING.OUTPUT%" != "" ] && echo "OUTPUT,%STRONGSCALING.OUTPUT%";
}

function test_info_weakscaling()
{
    [ "%WEAKSCALING.TEST_CONFIG%" != "" ] && echo "CONFIGURATION,%WEAKSCALING.TEST_CONFIG%";
    [ "%WEAKSCALING.TEST_STEPS%" != "" ] && echo "TIMESTEPS,%WEAKSCALING.TEST_STEPS%";
    [ "%WEAKSCALING.OUTPUT%" != "" ] && echo "OUTPUT,%WEAKSCALING.OUTPUT%";
}

function test_info_tracing()
{
    [ "%TRACING.TEST_CONFIG%" != "" ] && echo "CONFIGURATION,%TRACING.TEST_CONFIG%";
    [ "%TRACING.START_DATE%" != "" ] && echo "START DATE,%TRACING.START_DATE%";
    [ "%TRACING.END_DATE%" != "" ] && echo "END DATE,%TRACING.END_DATE%";
    [ "%TRACING.NHOURS%" != "" ] && echo "NHOURS,%TRACING.NHOURS%";
    [ "%TRACING.TRACE_STEPS%" != "" ] && echo "TIMESTEPS,%TRACING.TRACE_STEPS%";
    [ "%TRACING.OUTPUT%" != "" ] && echo "OUTPUT,%TRACING.OUTPUT%";
}

function test_info_compilation_efficiency()
{
    [ "%COMPILATION_EFFICIENCY.TEST_CONFIG%" != "" ] && echo "CONFIGURATION,%COMPILATION_EFFICIENCY.TEST_CONFIG%";
    [ "%COMPILATION_EFFICIENCY.TEST_STEPS%" != "" ] && echo "TIMESTEPS,%COMPILATION_EFFICIENCY.TEST_STEPS%";
    [ "%COMPILATION_EFFICIENCY.OUTPUT%" != "" ] && echo "OUTPUT,%COMPILATION_EFFICIENCY.OUTPUT%";

    local test_names=($(bashify_array "%COMPILATION_EFFICIENCY.TEST_NAMES%"))
    local arch_names=($(bashify_array "%COMPILATION_EFFICIENCY.ARCH_NAMES%"))
    local seen=" "
    local i pair
    for i in "${!test_names[@]}"; do
        pair="${test_names[$i]}:${arch_names[$i]:-${test_names[$i]}}"
        case "${seen}" in *" ${pair} "*) continue ;; esac
        seen+="${pair} "
        echo "${test_names[$i]} ARCH,${arch_names[$i]:-${test_names[$i]}}"
    done
}

#####################################################################################################################
# Brief: Writes the configuration table of a test and adds it to the end of its section, or
#        to its subsection/subsubsection when one is given
# Global:
#   - Paths: report_folder, report_full_path, latex_folder
# Param:
#   - 1: test name, selects test_info_<test>
#   - 2: test label used in the table caption
#   - 3: section title
#   - 4: subsection title (optional)
#####################################################################################################################
function add_test_info()
{
    local test=$1
    local label=$2
    local section=$3
    local subsection=${4:-""}
    local subsubsection=${5:-""}
    local csv_file=${report_folder}/test_info_${test}.csv

    { echo "Configuration,Value"; test_info_${test} || true; } > ${csv_file}

    local context=(-S "${section}")
    [ -n "${subsection}" ] && context+=(-s "${subsection}")
    [ -n "${subsubsection}" ] && context+=(-ss "${subsubsection}")
    python3 ${latex_folder}/ReportGenerator.py \
        -O ${report_full_path}.pkl \
        "${context[@]}" \
        --add-csv ${csv_file} \
        --add-caption "${label^} test configuration: the values that every case of the test shares, such as the model configuration, the number of timesteps, the output settings and the platform. The values that change from case to case are listed in the table of the cases."
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

declare -A enabled_members=(
    ["tracing"]="%EXPERIMENT.APP_TESTS.TRACING.ENABLED%"
    ["strongscaling"]="%EXPERIMENT.APP_TESTS.STRONGSCALING.ENABLED%"
    ["weakscaling"]="%EXPERIMENT.APP_TESTS.WEAKSCALING.ENABLED%"
    ["compilation_efficiency"]="%EXPERIMENT.APP_TESTS.COMPILATION_EFFICIENCY.ENABLED%"
)

python3 ${cfg}/latex/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    --section-title "Glossary" \
    --section-number 1 \
    -T ${cfg}/latex/text/Glossary.txt

python3 ${cfg}/latex/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    --section-title "Introduction" \
    --section-number 2 \
    -T ${cfg}/latex/Introduction.txt

test_info > test_info.csv

# Model-specific experiment configuration description
experiment_config_txt=${cfg}/latex/text/ExperimentConfiguration_${model}.txt
[ ! -f "${experiment_config_txt}" ] && experiment_config_txt=${cfg}/latex/text/ExperimentConfiguration.txt

python3 ${latex_folder}/ReportGenerator.py \
    -O ${report_full_path}.pkl \
    -S "Experiment configuration" \
    --add-caption "Experiment configuration: the values shared by every test in this report. The values that apply to a single test are listed in the section of that test." \
    --add-csv test_info.csv \
    -T ${experiment_config_txt}

for current_member in strongscaling tracing weakscaling compilation_efficiency; do
    if ${enabled_members[$current_member],,}; then
        add_${current_member,,}
    fi
done

cd ${report_folder} || exit
echo model=${report_model^^} > param.cfg
echo configuration_name=${configuration_name} >> param.cfg
title="%REPORT.TITLE%"
# hpcw is a benchmark that bundles several models: name the model that was tested
title=${title//${model}/${report_model}}
title=${title//${model^^}/${report_model^^}}
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
