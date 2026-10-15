# Analysis pipeline (`cfg/parser/`)

```
raw outputs -> collector.py -> <TEST_NAME>.json -> reporter.py (per test)  -> report.sh -> ReportGenerator.py -> PDF
                                              \-> comparator.py (per member) /
```

`collector.py` + `reporter.py` are driven per test by
[`autosubmit/templates/configuration_json.sh`](../../autosubmit/templates/configuration_json.sh);
`comparator.py` is driven per member by
[`autosubmit/templates/report.sh`](../../autosubmit/templates/report.sh).

## `collector.py` (ingestion)

| Flag | Meaning |
|---|---|
| `-i`, `--input-files` | required, `nargs='+'`; input **folders** to scan |
| `-o`, `--output-file` | output name; the script appends `.json` itself (`-o BENCH` → `BENCH.json`) |
| `-p`, `--param-file` | `param.cfg` (key=value: `processes_per_node`, `configuration_name`) |
| `-c`, `--components` | component names; space-separated string that the script splits |

It classifies raw files by name (`timing.output`, `*-timing.output`, `.pm` Paramedir, `.dm` Dimemas,
LUCIA `table.csv`, `test_info.csv`, `test_info.yaml`, `ifs.stat`) into a `TimingInformation` and
serialises one JSON per test.

## `reporter.py` (per-test curation)

| Flag | Purpose |
|---|---|
| `-j`, `--json-file` | **required**; the `<TEST_NAME>.json` to load |
| `-s`, `--scalability-file` | scalability CSV out |
| `-p`, `--scalability-plot` | scalability PNG out |
| `-v`, `--scalability-variable` | metric; default `sypd`. Others: `ts_per_second`, `sypd_per_core`, plus `sdpd` (monarch) and `time` (ICON) |
| `-f`, `--csv-folder` | per-function CSVs (used as `-f function_csv` for tracing) |
| `--functions-file` | function summary text |
| `-m`, `--most_expensive_function_summary` | most-expensive-function CSV |
| `--scatter-plots` | PAPI scatter plots; the template passes the `PLOTS` list with spaces → `:` |
| `--dimemas-file` | Dimemas summary |
| `--tracking-folder` | tracking output folder |
| `--coupling-folder` | coupling output folder (`ecearth4`) |
| `--cases-component-data` | columns for `cases_info.csv`; default `nproc`, `nargs='+'` |

For tracing the template passes `-j`, `--cases-component-data`, `-f function_csv`,
`--functions-file`, `--most_expensive_function_summary`, `--tracking-folder`, and `--scatter-plots`;
it deliberately does **not** pass `--scalability-*` because tracing has no SYPD.

## `comparator.py` (per-member comparison)

| Flag | Purpose |
|---|---|
| `-j`, `--json-files` | `nargs='*'`; files or folders containing JSONs |
| `-s`, `--strong-scaling` | flag |
| `-w`, `--weak-scaling` | flag |
| `--scalability-variable` | default `sypd` |
| `-f`, `--function-info` | compare elapsed time per function |
| `--out-dir` | output folder; the computed quantity is appended to the filename |

## What `configuration_json.sh` feeds in

The test identity comes from the job name: `current_member` is grep'd out of `%TASKTYPE%`
(`COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS`) and lowercased.

Base input glob is `run_*/*test_info.csv`, with `cases_variables` starting at `nproc`. Then, by model:

| Model | Extra inputs | Extra case columns |
|---|---|---|
| `monarch` | `run_*/*test_info.yaml` | `jnpes` `inpes` `write_groups` `write_tasks` |
| `nemo`, `hpcw` | `run_*/*-timing.output` | — |
| `ecearth4` | `run_*/*-ifs.stat` if `oifs` is a report component; `run_*/*-timing.output` if `nemo` is; `run_*/lucia_lite_results/table.csv` + `--coupling-folder coupling` if `STRONGSCALING.COUPLING_REPORT.ENABLED` | — |

For `tracing`, `paramedir/*pm` is added.

`--scalability-variable` overrides applied here: `sdpd` for `monarch`, `time` for `hpcw` when
`EXPERIMENT.COMPONENT` is `icon`. Everything else uses the `sypd` default.

Loop body per test: `cd run/<member>/<TEST_NAME>/`, write `param.cfg`, run `collector.py`, then
`reporter.py`. So each test folder ends up with `<TEST_NAME>.json`, `<TEST_NAME>_scaling.csv`,
`<TEST_NAME>_scaling.png`, `cases_info.csv` and the function artifacts.

## `cfg/parser/utils/`

| Module | Contents |
|---|---|
| `parsers.py` | `TimingInformation` (the data model), the per-format parsers (`parse_nemo_timing`, `parse_ifs_file`, `parse_paramedir_files`, `parse_dimemas_files`, `parse_filename`, …), `dictionary_pointer`, `merge_dictionaries` |
| `curation.py` | statistics, scalability, weak scaling, multi-experiment comparison, coupling |
| `plotter.py` | matplotlib helpers for plots/tables |
| `histograms.py` | histogram helpers |
| `model/nemo/`, `model/harmonie/` | model-specific converters |

Keep logic in `utils/` and the three entry points thin. Python style: PEP 8, type hints,
Google-style docstrings (`Args`/`Returns`), `argparse` CLIs, Python 3.9+, vectorised NumPy/pandas
over raw loops. API docs: `docs/source/developers_guide/code/`.
