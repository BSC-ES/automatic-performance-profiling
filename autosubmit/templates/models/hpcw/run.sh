#!/bin/bash
#####################################################################################################################
# models/hpcw/run.sh
# Brief: HPCW run implementation (ICON and NEMO components) for the scalability tests.
#        Declared in the FILE list of the hpcw scalability jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as run_<jobname>. scalability.sh sources it and calls run_hpcw.
# Global (set by scalability.sh):
#   - Paths: compilation, cfg, platform, run_root, project
#   - Other: model, branch, test, test_name, arch_name, test_config, current_member
# Global (set by Autosubmit):
#   - split: current split of the job (see SPLITS in the job definition)
#####################################################################################################################

function run_hpcw_icon()
{
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local split="%SPLIT%"
    local run_dir=${test_dir}/run_${run_id}/${split}
    local src_dir=${compilation}/${arch_name}
    local icon_nproc="%NUMPROC%"
    local icon_threads="%THREADS%"
    icon_threads=${icon_threads:-1}
    local input_pkg="icon-${test_config}"

    rm -rf ${run_dir}
    mkdir -p ${run_dir}
    cd ${run_dir} || exit

    HPCW_SOURCE_DIR=${src_dir} HPCW_INSTALL=${src_dir}/build/icon/install \
        source ${cfg}/arch/${platform}/${model}/icon/${arch_name}.env

    # The arch env pins OMP_NUM_THREADS=1, so re-apply the test thread count for hybrid runs
    export OMP_NUM_THREADS=${icon_threads}
    export ICON_THREADS=${icon_threads}
    if [ "${icon_threads}" -gt 1 ]; then
        # Give each MPI rank its own set of threads instead of a single pinned core
        export I_MPI_PIN_DOMAIN=omp
    fi

    local icon_base=${src_dir}/build/icon
    local staged_inputs=${icon_base}/install/inputs/${input_pkg}
    local downloaded_inputs=${icon_base}/inputs/icon/experiments/${test_config}
    if [ -d "${staged_inputs}" ]; then
        rsync -av ${staged_inputs}/ ${run_dir}/
    elif [ -d "${downloaded_inputs}" ]; then
        rsync -av --copy-links ${downloaded_inputs}/ ${run_dir}/
    else
        echo "[ERROR] ICON inputs not found at ${staged_inputs} nor ${downloaded_inputs}" >&2
        exit 1
    fi

    TIME_FORMAT="@hpcw-time: %C: %Uuser %Ssystem %eelapsed %PCPU (%Xtext+%Ddata %Mmax)k"

    local steps="${test_steps}"
    local atmo_nml
    atmo_nml=$(grep -m1 "model_namelist_filename" icon_master.namelist 2>/dev/null | \
        sed "s/.*['\"]\([^'\"]*\)['\"].*/\1/")
    [ -z "${atmo_nml}" ] && atmo_nml="NAMELIST_${test_config}"

    if [ -n "${steps}" ] && [ "${steps}" -gt 0 ] 2>/dev/null; then
        if [ -f "${atmo_nml}" ] && ! grep -q "^[[:space:]]*nsteps" "${atmo_nml}"; then
            sed -i "/^[[:space:]]*&run_nml/a\ nsteps = ${steps}" "${atmo_nml}"
        fi
    fi

    if [ "${output,,}" = "false" ] && [ -f "${atmo_nml}" ]; then
        # Comment out all &output_nml blocks so ICON writes no output files
        sed -i '/^[[:space:]]*&output_nml/,/^[[:space:]]*\//s/^[[:space:]]*/&!/' "${atmo_nml}"
        echo "[INFO] Model output disabled in ${atmo_nml}"
    fi

    case "${current_member}" in
        "tracing")
            fd_enabled=%TRACING.AUTOMATIC_USER_FUNCTIONS.ENABLED%
            fd_enabled=${fd_enabled,,}
            if ${fd_enabled}; then
                cp $run_root/$test_name/functions_dir/extrae_functions.txt ${run_dir}/
            else
                uf_list=($(bashify_array "%TRACING.EXTRAE.USER_FUNCTIONS.LIST%" true))
                if [ "${uf_list}" != "None" ]; then
                    echo -n > ${run_dir}/extrae_functions.txt
                    for user_function in "${uf_list[@]}"; do
                        echo "${user_function}" >> ${run_dir}/extrae_functions.txt
                    done
                else
                    cp ${cfg}/trace/model/${model}/${component}/extrae_functions.txt ${run_dir}/extrae_functions.txt
                fi
            fi
            chmod +x ${cfg}/trace/generate_function_list.sh
            ${cfg}/trace/generate_function_list.sh ${icon_base}/install/bin/icon extrae_functions.txt

            create_trace_sh ${run_dir}

            configure_extrae ${run_dir}

            \time -o timing.output -f "${TIME_FORMAT}" srun -n ${icon_nproc} --hint=nomultithread --cpus-per-task=${icon_threads} ${run_dir}/trace.sh ${icon_base}/install/bin/icon
            ;;
        *)
            \time -o timing.output -f "${TIME_FORMAT}" srun -n ${icon_nproc} --hint=nomultithread --cpus-per-task=${icon_threads} ${icon_base}/install/bin/icon
            ;;
    esac

    scontrol show JobId="${SLURM_JOB_ID}"
}

function run_hpcw_nemo()
{
    local test_dir=${run_root}/${test_name}
    local run_id="%CURRENT_NAME%"
    local split="%SPLIT%"
    local run_dir=${test_dir}/run_${run_id}/${split}
    local src_dir=${compilation}/${arch_name}
    local nemo_nproc="%NUMPROC%"

    rm -rf ${run_dir}
    mkdir -p ${run_dir}
    cd ${run_dir} || exit

    local log_dir="${test_dir}/hpcw_logs"
    local log_file="${log_dir}/nemo-${run_id}.log"
    mkdir -p "${log_dir}"
    rm -f "${log_file}"
    exec > >(tee -a "${log_file}") 2>&1

    export SETTE_DIR="${src_dir}/build/nemo/nemo_orca25/sette"
    export EXE_DIR="$PWD"

    . "${SETTE_DIR}/all_functions.sh"

    case ${test_config} in
        "orca025-medium")
            "${src_dir}/toolchains/job-stagein.sh" --strip-components=-1 \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/context_nemo.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/domain_def_nemo.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/field_def_nemo-ice.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/field_def_nemo-oce.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/file_def_nemo-ice.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/file_def_nemo-oce.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_precip_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_q_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_rain_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_rlds_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_rsds_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_slp_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_snow_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_t_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_u_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/JRA55_v_10_y2000.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/ORCA025_ESACCI_CHLA_bicubic_new.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/ORCA025_JRA55_weights_bicubic.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/Forcing/ORCA025_JRA55_weights_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/domain_cfg.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/domain_cfg_updated.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/domain_cfg_updated_new.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_CHLA_bicubic.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_CHLA_bicubic_new.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_CHLA_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_ESACCI_weights_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_JRA55_weights_bicubic.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/ORCA025_JRA55_weights_bilinear.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/runoff_child.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/runoff_clim.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/runoff.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/WOA13_ORCA025_S_nomask.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/InitialConditions/WOA13_ORCA025_T_nomask.nc" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/grid_def_nemo.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/iodef.xml" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_cfg" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_ice_cfg" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_ice_ref" \
            -s "${src_dir}/build/nemo/inputs/nemo-orca25/namelist_ref"

            ln -sf "${src_dir}/build/nemo/nemo_orca25/cfgs/MY_ORCA25/BLD/bin/nemo.exe" nemo
            set_namelist namelist_ref sn_cfctl%l_runstat .true.
            set_namelist namelist_ref ln_timing   .true.
        ;;
        "orca1-like-small")
            rsync -rLv ${src_dir}/build/nemo/nemo_bench1/tests/BENCH/EXP00/ ${run_dir}/
            set_namelist namelist_cfg ln_timing   .true.
        ;;
    esac

    HPCW_SOURCE_DIR=${src_dir} HPCW_INSTALL="${src_dir}/build/nemo/install" . ${cfg}/arch/${platform}/${model}/nemo/${arch_name}.env

    TIME_FORMAT="@hpcw-time: %C: %Uuser %Ssystem %eelapsed %PCPU (%Xtext+%Ddata %Mmax)k"

    case "${current_member}" in
        "tracing")
            trace_steps="%TRACING.TRACE_STEPS%"
            set_namelist namelist_cfg nn_itend ${trace_steps}

            fd_enabled=%TRACING.AUTOMATIC_USER_FUNCTIONS.ENABLED%
            fd_enabled=${fd_enabled,,}
            if ${fd_enabled}; then
                cp $run_root/$test_name/functions_dir/extrae_functions.txt ${run_dir}/
            else
                uf_list=($(bashify_array "%TRACING.EXTRAE.USER_FUNCTIONS.LIST%" true))
                if [ "${uf_list}" != "None" ]; then
                    echo -n > ${run_dir}/extrae_functions.txt
                    for user_function in "${uf_list[@]}"; do
                        echo "${user_function}" >> ${run_dir}/extrae_functions.txt
                    done
                else
                    cp ${cfg}/trace/model/${model}/${component}/extrae_functions.txt ${run_dir}/extrae_functions.txt
                fi
            fi
            chmod +x ${cfg}/trace/generate_function_list.sh
            ${cfg}/trace/generate_function_list.sh ./nemo extrae_functions.txt


            create_trace_sh ${run_dir}

            configure_extrae ${run_dir}

            \time -f "$TIME_FORMAT" srun -n ${nemo_nproc} ./trace.sh ./nemo
            ;;
        *)
            steps="${test_steps}"
            set_namelist namelist_cfg nn_itend ${steps}

            \time -f "$TIME_FORMAT" srun -n ${nemo_nproc} ./nemo
            ;;
    esac

    scontrol show JobId="${SLURM_JOB_ID}"
}

function run_hpcw()
{
    local component
    # shellcheck source=proj/auto-performance-profiling/cfg/utils/bash/utils.sh
    component=$(bashify_array "%MODEL.COMPONENTS%" true)
    component=$(echo "${component%% *}" | tr '[:upper:]' '[:lower:]')

    run_hpcw_${component}
}
