# Analysis pipeline (`cfg/parser/`)

```
raw outputs -> collector.py -> <TEST_NAME>.json -> reporter.py (per test)  -> report.sh -> ReportGenerator.py -> PDF
                                              \-> comparator.py (per member) /
```

`collector.py` + `reporter.py` are driven per test by
[`autosubmit/templates/analysis.sh`](../../autosubmit/templates/analysis.sh);
`comparator.py` is driven per member by
[`autosubmit/templates/report.sh`](../../autosubmit/templates/report.sh).

## `collector.py` (ingestion)

| Flag | Meaning |
|---|---|
| `-m`, `--mapping` | YAML declaring which file belongs to which case, component and format |
| `--input` | inline mapping entry `case=...,component=...,format=...,files=...` (repeatable; `;` separates several files) |
| `-o`, `--output-file` | output name; the script appends `.json` itself (`-o BENCH` → `BENCH.json`) |
| `-p`, `--param-file` | `param.cfg` (key=value: `processes_per_node`, `configuration_name`); the mapping can also carry it as `parameters` |
| `-c`, `--components` | component names; defaults to the components declared in the mapping |
| `--test` | test name; defaults to the output file name |
| `--splits` | number of repetitions the test declares; warns when a component matches fewer files |

No file name is inspected to decide what a file contains. Each mapping entry names its `format`,
and the format selects the loader (`src/registry.py`). The formats are `nemo-timing`,
`ifs-stat`, `icon-timing`, `icon-timer-report`, `paramedir` (needs `counter`), `dimemas` (needs
`simulation` and `counter`), `lucia` and `test_info` (`.csv` or `.yaml`). `test_info` is a normal
case-level `inputs` entry and is optional: a missing match is not warned about. `-i/--input-files`
was removed and is rejected with a pointer to `--mapping`.

Any other key under a case (`tasks`, `threads`, `resolution`, ...) is case data and is written to
the JSON unchanged, so a case can declare its values in the mapping and skip the `test_info` file.

`tasks` comes from `test_info` or from the case data; an optional `tasks` key in a component entry
overrides the task count the files report.

## `reporter.py` (per-test curation)

| Flag | Purpose |
|---|---|
| `-j`, `--json-file` | **required**; the `<TEST_NAME>.json` to load |
| `-s`, `--scalability-file` | scalability CSV out |
| `-p`, `--scalability-plot` | scalability PNG out |
| `-v`, `--scalability-variable` | metric; default `sypd`. Others: `ts_per_second`, plus `sdpd` (monarch) and `time` (ICON) |
| `-f`, `--csv-folder` | per-function CSVs (used as `-f function_csv` for tracing) |
| `--functions-file` | function summary text |
| `-m`, `--most_expensive_function_summary` | most-expensive-function CSV |
| `--function-time-share-plot` | stacked PNG with the share of the fastest timestep spent in each user function, one 100% bar per case |
| `--mpi-profile-share-plot` | stacked PNG with the share of the MPI call time spent in each MPI call, one 100% bar per case |
| `--function-mpi-share-plot` | stacked PNG with the MPI call profile of each function of each case, one 100% bar per function and case |
| `--function-counter-plot` | PNG with one panel per counter (IPC, PAPI_L3_TCM) and one line per function along the cases |
| `--scatter-plots` | PAPI scatter plots; the template passes the `PLOTS` list with spaces → `:` |
| `--dimemas-file` | Dimemas summary |
| `--tracking-folder` | tracking output folder |
| `--coupling-folder` | coupling output folder (`ecearth4`) |
| `--cases-component-data` | columns for `cases_info.csv`; default `tasks`, `nargs='+'` |

For tracing the template passes `-j`, `--cases-component-data`, `-f function_csv`,
`--functions-file`, `--most_expensive_function_summary`, `--function-time-share-plot`,
`--function-mpi-share-plot`, `--function-counter-plot`, `--mpi-profile-share-plot`,
`--tracking-folder`, and `--scatter-plots`;
it deliberately does **not** pass `--scalability-*` because tracing has no SYPD.
The tracking folder holds `MPI/<component>_functions.csv` (MPI call share of every function and
case) and `counters/<component>_functions.csv` (IPC, cycles, cache misses per thousand
instructions), the two tables the report embeds.

## `comparator.py` (per-member comparison)

| Flag | Purpose |
|---|---|
| `-j`, `--json-files` | `nargs='*'`; files or folders containing JSONs |
| `-s`, `--strong-scaling` | flag |
| `-w`, `--weak-scaling` | flag |
| `--scalability-variable` | default `sypd` |
| `-f`, `--function-info` | compare elapsed time per function |
| `--out-dir` | output folder; the computed quantity is appended to the filename |
| `--file-out` | exact path of the weak scaling CSV; overrides `--out-dir` (what `report.sh` passes) |

## What `analysis.sh` feeds in

The test identity comes from the job name: `current_member` is grep'd out of `%TASKTYPE%`
(`COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS`) and lowercased.

For every test `analysis.sh` writes `inputs.yml` with `write_input_mapping`, built from
`test_info_patterns`, `component_specs` (`"<component>|<format>|<pattern>"`) and `case_level_specs`
(`"<format>|<pattern>"`). Patterns are relative to a single run directory and expanded per case, so
only the `run_<name>` directories declared in `<TEST>.NAMES` are read.

| Model | Declared `component_specs` | `test_info` globs | Extra case columns |
|---|---|---|---|
| `monarch` | — | `*.csv`, `*.yaml` | `jnpes` `inpes` `write_groups` `write_tasks` |
| `nemo` | `nemo|nemo-timing|timing.output` | `*.csv` | — |
| `hpcw` | `icon|icon-timer-report|icon_timer.log` or `nemo|nemo-timing|timing.output` | `*.csv`, `*.yaml` | — |
| `ecearth4` | `oifs|ifs-stat|*-ifs.stat`, `nemo|nemo-timing|*-timing.output` (each if reported) | `*.csv` | — |

Every component pattern is written twice, `run_<case>/<pattern>` and `run_<case>/*/<pattern>`,
so the run directory layout of the model does not matter: the split folders
(`run_<case>/1/`, `run_<case>/2/`, ...) that every model is meant to use are read when present
and a file written straight into the run directory is read otherwise.

**Splits**: every file a pattern matches is one repetition of the same case. `src/splits.py`
averages the numeric values of the payloads (recursing into the nested mappings), keeps `tasks`
from the first one, and stores the per-split values of the scalability metric under `splits`
(`[{"sypd": 9.4}, {"sypd": 9.6}]`), which is what `generate_scalability_summary()`,
`multi_experiment_comparison()` and `plotting.py` read for their error bars. A single file means a
single split and adds no `splits` key. `post.sh` therefore no longer concatenates the timing files
nor averages the SYPD in bash.

`ecearth4` with `STRONGSCALING.COUPLING_REPORT.ENABLED` adds `case_level_specs+=("lucia|lucia_lite_results/table.csv")`
and `--coupling-folder coupling`. For `tracing`, one `paramedir` entry per component and per counter in
`cfg/trace_analysis/paramedir_configurations/` is appended, e.g.
`"nemo|paramedir|paramedir/nemo-*-Time.pm|Time"`. Dimemas entries are not generated by the template
(the feature is disabled and its results are meaningless); the `dimemas` format stays available for a
hand-written mapping and `dimemas_summary` returns an empty table when the JSON has no Dimemas data.

`--scalability-variable` overrides applied here: `sdpd` for `monarch`, `time` for `hpcw` when the
first `MODEL.REPORT_COMPONENTS` entry is `icon`. Everything else uses the `sypd` default.

Loop body per test: `cd run/<member>/<TEST_NAME>/`, write `param.cfg` and `inputs.yml`, run
`collector.py`, then `reporter.py`. So each test folder ends up with `<TEST_NAME>.json`,
`<TEST_NAME>_scaling.csv`, `<TEST_NAME>_scaling.png`, `cases_info.csv` and the function artifacts.

## `cfg/parser/src/`

| Module | Contents |
|---|---|
| `mapping.py` | mapping dataclasses, YAML and `--input` parsers, glob expansion |
| `registry.py` | `COMPONENT_FORMATS`, `CASE_FORMATS`, `MODEL_DEFAULT_FORMAT`; one line per format |
| `models/nemo.py`, `models/ifs.py`, `models/icon.py` | the parsers of each model's own outputs |
| `formats/paramedir.py`, `formats/dimemas.py`, `formats/lucia.py`, `formats/test_info.py` | model independent formats |
| `splits.py` | averages the repetitions of a case and keeps them under `splits` |
| `timing.py` | `TimingInformation`: merge, case ordering, JSON save/load, curation delegation |
| `merge.py` | `dictionary_pointer`, `merge_dictionaries` |
| `curation.py` | statistics, scalability, weak scaling, multi-experiment comparison, coupling |
| `plotting.py`, `histograms.py`, `scaling.py` | matplotlib helpers, histogram helpers, metric direction |
| `cli/` | `collect`, `report`, `compare`; `app-parser <command>` when installed |

`collector.py`, `reporter.py` and `comparator.py` at the package root add `src/` to `sys.path` and
call the CLI, so the workflow needs no installation. Tests: `cfg/parser/tests/`
(`python3 -m pytest cfg/parser/tests`). Python style: PEP 8, type hints, Google-style docstrings
(`Args`/`Returns`), `argparse` CLIs, Python 3.9+, vectorised NumPy/pandas over raw loops. API docs:
`docs/source/developers_guide/code/`.
