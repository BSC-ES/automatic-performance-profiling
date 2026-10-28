#!/bin/bash
#####################################################################################################################
# models/ecearth4/post.sh
# Brief: EC-Earth 4 post-processing for the scalability tests.
#        Declared in the FILE list of the ecearth4 post jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as post_<jobname>. post.sh sources it and calls post_ecearth4.
# Contract, set by post.sh before post_ecearth4 is called:
#   - Paths: cfg, test_dir, run_dir (post.sh); compilation, project (this file)
#   - Other: model, test, current_member, splits, components, report_components, test_procs, i
#####################################################################################################################

###################
# AS variables
###################
compilation=%COMMON_PATH_LOCATIONS.COMPILATION_ROOT%
project=%COMMON_PATH_LOCATIONS.PROJECT_ROOT%

#####################################################################################################################
# Brief: Extracts the component geometry, the SYPD and the optional coupling report of one EC-Earth 4 run
# Global:
#   - Paths: compilation, cfg, test_dir, run_dir, project
#   - Other: model, test, current_member, splits, components, report_components, test_procs, i
#####################################################################################################################
function post_ecearth4()
{
    oifs_on=false
    echo "${components[@]}" | grep -w "oifs" && oifs_on=true
    nemo_on=false
    echo "${components[@]}" | grep -w "nemo" && nemo_on=true

    cd ${run_dir} || exit

    if [ ${current_member} = "tracing" ]; then
        multiprog_fn=${run_dir}/run/multiprog.conf
    else
        multiprog_fn=${run_dir}/multiprog.conf
    fi

    save_job_geometry multiprog ${multiprog_fn} > job_geometry.sh
    . ./job_geometry.sh

    for component in ${!job_geometry[@]}; do
        component_geometry=${job_geometry[${component}]}
        component_geometry=${component_geometry//,/ }
        component_nproc=${component}_nproc
        declare ${component_nproc}=0
        for procs_range in ${component_geometry}; do
            first_proc=$(echo ${procs_range} | cut -d'-' -f1)
            last_proc=$(echo ${procs_range} | cut -d'-' -f2)
            curr_sypd=${!component_nproc}
            declare ${component_nproc}=$((curr_sypd + (last_proc - first_proc + 1)))
        done
    done

    # The multiprog total counts a process per component entry, so the requested count is used
    model_nproc=${test_procs[$i]}

    case ${current_member} in
        "tracing")
            mv run/*prv run/*pcf run/*row .

            cut_trace job_geometry.sh "${model}.prv"

            rm -rf set-* ./*.nc
        ;;
        *)
            local coupling_enabled="%STRONGSCALING.COUPLING_REPORT.ENABLED%"
            coupling_enabled=${coupling_enabled,,}
            if ${coupling_enabled}; then
                if ${nemo_on}; then
                    lucia_ts=$(cat time.step)
                else 
                    # If nemo is not present, it means that oifs is running coupled with amipfr
                    sim_length=$(cat namelist.amip | grep -oE "RunLengthSec = [0-9]+" | awk -F ' ' '{print $3}')
                    amip_coupling_period=$(cat namelist.amip | grep -oE "TimeStepSec = [0-9]+" | awk -F ' ' '{print $3}')
                    lucia_ts=$((sim_length/amip_coupling_period))
                fi

                local ignore_ini_ts="%STRONGSCALING.COUPLING_REPORT.LUCIA.IGNORE_INI_TS%"
                local ignore_end_ts="%STRONGSCALING.COUPLING_REPORT.LUCIA.IGNORE_END_TS%"
                local ignored_ts=$((ignore_ini_ts+ignore_end_ts))
                while ! python3 ${compilation}/lucia-alternative/lucia_lite_v2.py average ${ignore_ini_ts} ${ignore_end_ts} ${lucia_ts} --generate_plots true > lucia.log && [ ${lucia_ts} -gt ${ignored_ts} ]; do
                    lucia_ts=$((lucia_ts-1))
                done

                if [ ${lucia_ts} -le ${ignored_ts} ]; then
                    echo "[ERROR] Could not generate coupling report using lucia, check the logs or disable the coupling report in the AS settings." >&2 
                    return 1
                else
                    coupling_dir=${test_dir}/coupling/${test}
                    mkdir -p ${coupling_dir}
                    cp ${run_dir}/lucia_lite_plots/*    ${coupling_dir}
                    cp ${run_dir}/lucia_lite_results/*  ${coupling_dir}
                fi
            else
                if ${oifs_on}; then
                    oifs_sypd=$(grep "FORECAST DAYS PER DAY" log/001/NODE.001_01 |  grep -oE "[0-9.]+" )
                    oifs_sypd=$(echo ${oifs_sypd} / 365 | bc -l)
                fi
                                
                ${nemo_on} && nemo_sypd=$(grep "Model speed excl overhead:" log/001/timing.log |  grep -oE "[0-9.]+" )

                model_sypd=$(grep "Model speed excl overhead:" log/001/timing.log |  grep -oE "[0-9.]+" )
            fi

            ${oifs_on} && cp ${run_dir}/log/001/ifs.stat ${run_dir}/oifs-${test}-ifs.stat
            ${nemo_on} && cp ${run_dir}/timing.output ${run_dir}/nemo-${test}-timing.output
        ;;
    esac


    case ${current_member} in
        "weakscaling")
            if ${oifs_on}; then
                oifs_ws_resolutions=($(bashify_array "%WEAKSCALING.OIFS_RESOLUTION%"))
                oifs_resolution=${oifs_ws_resolutions[$i]}
                . ${project}/configurations/model/oifs/resolutions.sh 
                oifs_grid_points=${oifs_resolutions[${oifs_resolution}]}
            fi

            if ${nemo_on}; then
                nemo_ws_resolutions=($(bashify_array "%WEAKSCALING.NEMO_RESOLUTION%"))
                nemo_resolution=${nemo_ws_resolutions[$i]}
                . ${project}/configurations/model/nemo/resolutions.sh 
                nemo_grid_points=${nemo_resolutions[${nemo_resolution}]}
            fi
        ;;
        *)
            model_resolution=%EXPERIMENT.RESOLUTION%
            ${oifs_on} && oifs_resolution=%EXPERIMENT.OIFS_RESOLUTION%
            ${nemo_on} && nemo_resolution=%EXPERIMENT.NEMO_RESOLUTION%
        ;;
    esac

    variables_to_report="nproc resolution"
    [ ${current_member} = "weakscaling" ] && variables_to_report+=" grid_points"
    [ ${current_member} != "tracing" ] && ! ${coupling_enabled} && variables_to_report+=" sypd"
    
    report_test_cfg ${variables_to_report} > ${run_dir}/${test}-test_info.csv

    return 0
}
