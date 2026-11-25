# Tracing (Extrae / Paraver / Dimemas)

The tracing test runs the model under Extrae, cuts the trace to one timestep, and extracts metrics
with Paramedir, Paraver, Dimemas and Modelfactors.

## Job chain

```
SCALABILITY_TRACING (FOR) -> POST_TRACING (FOR)
POST_TRACING -> TRACE_CUT
TRACE_CUT   -> PARAMEDIR, PARAVER, MODELFACTORS, DIMEMAS_TRACES
DIMEMAS_TRACES -> DIMEMAS_IMAGES, PARADIM
POST_TRACING, PARAMEDIR, PARADIM -> ANALYSIS_TRACING
```

`SCALABILITY_TRACING` uses `FILE: autosubmit/templates/scalability.sh cfg/trace/utils.sh
autosubmit/templates/models/<MODEL>/run.sh` — i.e. `scalability.sh` sources the tracing helper (as
`utils_<jobname>`) and the model runner (as `run_<jobname>`) — plus a dependency on `FUNCTIONS_DIR`.

It also sets `CUSTOM_DIRECTIVES: "%TRACING_CUSTOM_DIRECTIVES%"`. The value lives in
`core/platforms/<HPCARCH>.yml`, because needing the nodes that expose the PAPI hardware counters is a
property of the machine: `mn5` sets `"#SBATCH -C perfparanoid"`, `hpc2020` and `local` set `""`. Without
a perfparanoid node Extrae records no counters, every `paramedir` counter file comes back empty and the
counter plots of the report are blank.

All post-processing jobs walk the cases through `%TRACING.NAMES%` (never a `run_*` glob), the same way
`analysis.sh` builds `run_${name}/…`.

## Dimemas

`TRACING.DIMEMAS.ENABLED` is `false` by default. When enabled, `dimemas_traces.sh` runs `prv2dim` on
each cut trace (`dimemas_traces/<case>.dim`, named after the case only, so a second component
overwrites it) and then `Dimemas` with every view in
`cfg/trace_analysis/dimemas_configurations/platform/<platform>/` (`<case>_<cfg>.prv`); `paradim.sh`
runs PARADIM over those `.prv` files. `dimemas_images.sh` only echoes the `paraver` command — the
render is commented out — so no images reach `dimemas_images/`.

Dimemas is not reported today: `analysis.sh` passes no `--dimemas-file`, `report.sh` has no Dimemas
section, and the images are never embedded. The parser keeps the `dimemas` format (`simulation` and
`counter`, `src/formats/dimemas.py`), `reporter.py` keeps `--dimemas-file`, and
`dimemas_curated_summary()` still summarises it, for a hand-written mapping.

## Config keys (`user/common.yml` → `TRACING`)

| Key | Purpose |
|---|---|
| `EXTRAE.HOME`, `EXTRAE.TRACING_LIB`, `EXTRAE.TRACE_NAME` | Extrae install, tracing library, output `.prv` name (`%MODEL.NAME%.prv`) |
| `EXTRAE.MPI.ENABLED`, `EXTRAE.MPI.COUNTERS.ENABLED` | MPI profiling and hardware counters |
| `EXTRAE.CALLERS.{ENABLED,MPI.{ENABLED,LEVELS},SAMPLING.{ENABLED,LEVELS}}` | callers / sampling depth |
| `EXTRAE.USER_FUNCTIONS.{ENABLED,SAMPLING.ENABLED,LIST}` | trace a fixed function list, or discover them by sampling |
| `EXTRAE.PAPI_COUNTERS.{ENABLED,LIST}` | comma-separated PAPI events |
| `EXTRAE.OPENMP.ENABLED` | OpenMP instrumentation |
| `PARAVER.{ENABLED,CFGS,COMPARE_CFGS,LEGEND_SCALE}` | which Paraver views to render, which get cross-case comparison, and how much the legend is enlarged before it is appended |
| `DIMEMAS.{ENABLED,CFGS}` | which Dimemas views to render |
| `USER_FUNCTIONS.ENABLED` | enables the function report in the report |
| `USER_FUNCTIONS.PAPI_COUNTERS.{ENABLED,PLOTS}` | scatter plots; `PLOTS` is a space-separated list of `PC_id_1-PC_id_2` pairs (ids from `papi_avail`) |
| `MODELFACTORS.ENABLED`, `MPI.ENABLED` | report sub-sections |

If `EXTRAE.USER_FUNCTIONS.LIST` is empty, the default list in
`cfg/trace/model/<MODEL>/extrae_functions.txt` is used.

## Per-model keys (`user/model/<MODEL>/proj.yml` → `TRACING`)

`TEST_NAMES`, `NAMES`, `PROCESSORS`, `THREADS`, `TEST_CONFIG`, `ARCH_NAME` drive the `trace` `FOR`
block; `TIMESTEP_ZERO`, `TRACE_STEPS`, `USER_FUNCTIONS_PROC`, `USER_FUNCTIONS_THREADS`,
`TRACE_N_FUNCTIONS` control the cut and the sampling run. `TRACING.ARCH_NAME` is normally the
`O*_trace` arch, while the other tests use `O*_prod`.

## Assets

| Path | Role |
|---|---|
| `cfg/trace/extrae.xml.tmpl` | Extrae XML template rendered at run time |
| `cfg/trace/model/<MODEL>/` | per-model tracing assets: `extrae_functions.txt`, `cutter.xml`, `sentinel.diff`, `trace-run.sh.j2` (varies by model) |
| `cfg/trace/utils.sh` | tracing helpers sourced by `scalability.sh` |
| `autosubmit/templates/models/<MODEL>/run.sh` | per-model `run_<model>` implementation, staged by Autosubmit and sourced by `scalability.sh` |
| `cfg/trace/generate_function_list.sh` | generates the function list |
| `cfg/generate_func_list/` | `generate_function_list.sh`, `extrae.xml`, `sampling_user_function*.cfg`, `sum_user_function*.cfg`, `model/<MODEL>/` |
| `cfg/utils/bash/utils.sh` | `cut_trace()`, `create_threads_to_ignore()`, `parse_multiprog()` |

`cfg/trace_analysis/` holds the view definitions and image pipelines:
`paraver_configurations/`, `dimemas_configurations/`, `paradim_configurations/`,
`paramedir_configurations/`, `cfgs/`, plus the `paraver/`, `Dimemas/`, `paramedir/`, `prv2dim/`,
`modelfactors/` working dirs and `generate_paraver_images.sh`.

## Adding a view

1. Drop the `.cfg` into `cfg/trace_analysis/paraver_configurations/` or `dimemas_configurations/`.
2. List its name in `TRACING.PARAVER.CFGS` or `TRACING.DIMEMAS.CFGS`.
3. Optionally add it to `TRACING.PARAVER.COMPARE_CFGS` to get an appended cross-case image (the
   image must exist for at least one case or `report.sh` skips it with a message).

Metric note: tracing has no SYPD, so `analysis.sh` does not pass `--scalability-*` for the
tracing member; the report shows function/PAPI/MPI data instead.
