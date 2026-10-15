# Auto Performance Profiling (APP)

Expert context for developing and operating the Automatic Performance Profiling (APP) tool:
Bash/Python job templates, Autosubmit workflows and the result-processing pipeline for climate
models (EC-Earth 4, NEMO 4.2.1, HPCW 3.0, monarch) on HPC platforms (MN5, HPC2020).

## Overview

APP wraps climate-model performance tests in Autosubmit workflows: Bash templates run the model
and the analysis tools, Python under `cfg/` parses the results, and LaTeX renders a PDF report.

Tests: `STRONGSCALING`, `WEAKSCALING`, `COMPILATION_EFFICIENCY`, `TRACING` (Extrae/Paraver/Dimemas:
PAPI counters, MPI profile, user functions) and `HW_BENCHMARKS` (OSU + STREAM).

A test is enabled/disabled by adding or removing its per-test file
`core/jobs/model/<MODEL>/jobs-<test>.yml` from the `CUSTOM_CONFIG.PRE` list in
`autosubmit/configuration/bootstrap.yml`. Non-auto models also set
`EXPERIMENT.APP_TESTS.<TEST>.ENABLED` (`core/defaults.yml` keeps the defaults `FALSE`); HW
benchmarks are gated by `HW_BENCHMARKS.{OSU,STREAM}.ENABLED` in `user/common.yml` and run FOR loops
over `HW_BENCHMARKS.*.NAMES`/`PROCESSORS`. The Autosubmit *members* feature is no longer used for
test selection (only auto-monarch runs a single member); `EXPERIMENT.DATELIST`/`MEMBERS` are
placeholders Autosubmit requires.

Experiments use the minimal configuration format — a single `conf/minimal.yml` with `CONFIG`,
`DEFAULT` (EXPID, HPCARCH, LOGIN_PLATFORM, MODEL, `CUSTOM_CONFIG`), `GIT` and `PROJECT` — not the
legacy `expdef_*.yml`/`jobs_*.yml`/`platforms_*.yml`/`autosubmit_*.yml` files.

## Skills to load

Read the matching `SKILL.md` before starting the work — do not improvise these from memory:

- `autosubmit-workflows` — before adding/modifying Autosubmit jobs, dependencies, wrappers, platforms
  or script templates.
- `remote-developer` — before running anything over SSH (host aliases, scheduler commands, per-host
  quirks). Never guess a hostname or alias.
- `ponytail` — on any coding task (writing, fixing, refactoring, reviewing, choosing dependencies),
  to get the smallest change that fully solves the task and a one-read reply; also when the user says
  "ponytail", "be lazy", "yagni" or complains about over-engineering. Levels: lite, full (default),
  ultra.

## Reference files

The sections in this file are the working context — enough to orient and to take routine action.
Read the matching file **before** starting the work whenever the task needs the detail:

| When the task involves… | Read |
|---|---|
| the config chain, a specific config file, `proj.yml` or platform keys, arch files | `.agents/references/configuration.md` |
| `cfg/parser` — collector/reporter/comparator flags, input globs per model, `TimingInformation` | `.agents/references/pipeline.md` |
| the PDF report — `report.sh`, report sections, `ReportGenerator.py` | `.agents/references/report.md` |
| Extrae/Paraver/Dimemas, PAPI counters, user functions, modelfactors | `.agents/references/tracing.md` |
| adding a test, model, benchmark, platform or Paraver/Dimemas view | `.agents/references/extending.md` |
| a FAILED job, a job that never runs, config changes that have no effect | `.agents/references/troubleshooting.md` |

## Repository layout

- `autosubmit/configuration/` — `core/` (`defaults.yml`, shared and per-test job files) and `user/`
  (`common.yml` tool settings, `platforms.yml`, `model/<MODEL>/proj.yml`)
- `autosubmit/templates/` — Bash job templates (conventions below)
- `cfg/` — `parser/` (analysis pipeline), `latex/` (report generator), `benchmarks/` (OSU/STREAM),
  `trace/` + `trace_analysis/` (Extrae/Paraver/Dimemas), `arch/` + `env/` (platform files), `utils/`
- `configurations/model/` — model parameter files; `docs/` — Sphinx users/developers guide
- `.agents/references/` — on-demand agent reference notes (see **Reference files**)

## Bash template conventions

Templates in `autosubmit/templates/` are rendered by the Autosubmit template engine
(`%VARIABLE%`/`%SECTION.KEY%` placeholders → `.cmd` → scheduler). They cover setup (`clean.sh`,
`synchronize.sh`, `remote_setup.sh`, `ini.sh`, `compilation.sh`, `tests.sh`), execution
(`scalability.sh`, `osu_run.sh`, `stream.sh`), tracing (`trace_cut.sh`, `paramedir.sh`, `paraver.sh`,
`dimemas_*.sh`, `modelfactors.sh`) and post-processing (`post.sh`, `configuration_json.sh`,
`report.sh`).

- Use `%VARIABLE%`/`%SECTION.KEY%` placeholders — never hardcode paths, models, platforms or
  credentials; placeholders resolve only at submission time.
- Source shared helpers from `cfg/utils/bash/utils.sh` with a `# shellcheck source=...` annotation;
  reuse `bashify_array`, `report_test_cfg`, `save_test_yaml`, `save_job_geometry`.
- Document each function with the `Brief:`/`Parameters:`/`Global:` header convention.
- Keep templates model- and platform-agnostic: `case` on `$model`/`$current_member`, lowercase the
  platform with `${platform,,}`.
- Guard destructive commands (`rm -rf "${run_dir:?}"/*`), `cd ... || exit`, `local` variables.
- Use strict-mode tracing (`set -xv`, `set -xuve`); wrap optional env-var exports (e.g. `PYTHONPATH`)
  in `set +u`/`set -u`.
- Integrate `as_checkpoint` for FROM_STEP dependencies; handle I/O sync and data integrity across
  distributed filesystems.
- Validate with `bash -n` and `shellcheck` before submitting.

## Analysis pipeline (`cfg/parser/`)

```
raw outputs -> collector.py -> <TEST>.json -> reporter.py (per test) -> report.sh -> ReportGenerator.py -> PDF
                                          \-> comparator.py (per member) /
```

**Entry points:**

| Tool | Key flags | What it does |
|---|---|---|
| `collector.py` | `-i <folders> -o <name> -p param.cfg -c <comps>` | Classifies raw files (timing outputs, `.pm`, `.dm`, LUCIA, test_info) into a `TimingInformation` JSON |
| `reporter.py` | `-j <test>.json -s <csv> -p <png> -v <metric>` | Curation: scalability CSV/PNG, function CSVs, scatter plots, Dimemas summary, coupling |
| `comparator.py` | `-j <jsons> -s/-w --scalability-variable <metric> --out-dir <dir>` | Cross-member comparison (strong/weak scaling) |

`-v` default `sypd`; `sdpd` for monarch, `time` for ICON. Tracing never passes `--scalability-*`.

**Per-model collector extras:**

| Model | Extra inputs | Extra case columns |
|---|---|---|
| `monarch` | `*test_info.yaml` | `jnpes` `inpes` `write_groups` `write_tasks` |
| `nemo`, `hpcw` | `*-timing.output` | — |
| `ecearth4` | `*-ifs.stat` (if oifs), `*-timing.output` (if nemo), `lucia table.csv` (if coupling enabled) | — |
| tracing (all) | `paramedir/*pm` | — |

**Python style:** PEP 8, type hints, Google-style docstrings, `argparse`, Python 3.9+, vectorised NumPy/pandas over raw loops. Core logic in `cfg/parser/utils/` (`parsers.py`, `curation.py`, `plotter.py`, `histograms.py`), entry points thin.

Full detail: **`.agents/references/pipeline.md`**. API docs: `docs/source/developers_guide/`.

## Workflow configuration

`conf/minimal.yml` → `bootstrap.yml` merges these files **in order** (later wins):

| # | File | Role |
|---|---|---|
| 1 | `core/defaults.yml` | shipped defaults; all `APP_TESTS` = `"FALSE"` |
| 2 | `user/model/%MODEL%/proj.yml` | model specs + per-test config |
| 3 | `user/common.yml`, `platforms.yml`, `autosubmit.yml` | shared tool/AS settings |
| 4 | `core/jobs/jobs-execution.yml` | model-agnostic setup chain |
| 5 | `core/jobs/model/%MODEL%/jobs.yml` | model job overrides (ecearth4, hpcw only) |
| 6 | `core/jobs/jobs-hwbenchmarks.yml` | **commented out by default** |
| 7-10 | `core/jobs/model/%MODEL%/jobs-{strong,weak,compilation, tracing}.yml` | one per test |
| 11 | `core/jobs/jobs-common.yml` | `CLEAN`, `SYNCHRONIZE`, `REPORT` |
| 12 | `core/platforms/%HPCARCH%.yml` | platform defaults |
| — | `~/platforms_credentials.yml` (POST) | your `PLATFORMS.*.USER` |

**Test enable/disable** requires **both** layers:
- **Job chain** — include/exclude the `jobs-<test>.yml` line in `bootstrap.yml` `CUSTOM_CONFIG.PRE`. The jobs-<test>.yml includes an `EXPERIMENT.APP_TESTS.<TEST>.ENABLED` setting it to TRUE, and overrides the default FALSE in `defaults.yml`.

**Config traps that produce silence, not errors:**
- `core/jobs/model/ecearth4/jobs.yml` uses a **lowercase `jobs:`** key — Autosubmit reads only `JOBS`, so the whole file is skipped
- `core/jobs/platform/<HPCARCH>/jobs.yml` is **never loaded** — `bootstrap.yml` only includes `core/platforms/<HPCARCH>.yml`
- `conf/metadata/experiment_data.yml` is Autosubmit's resolved-config dump — editing it has zero effect
- `FOR` jobs must be fully self-contained (incl. `FILE`) in their block; a later file redefining a `FOR` job without `FILE` silently drops it

Full detail: **`.agents/references/configuration.md`** and **`.agents/references/troubleshooting.md`**.

## Running and Operating the APP Workflow

Full instructions for installing, creating, and configuring the workflow are in the user guide: `docs/source/users_guide/users_guide.rst` (source) or https://automatic-performance-profiling.readthedocs.io/en/latest/ (built docs).

In the bsceshub load autosubmit using:

```bash
module load autosubmit
```

In local machines, it can be installed via pip, but then the user has to configure the AS experiments database.

**Create the experiment** with the custom minimal-format `autosubmit expid` command:

```bash
autosubmit expid \
  -min \
  -H "<PLATFORM>" \
  -d "<DESCRIPTION>" \
  --git_as_conf autosubmit/configuration/bootstrap.yml \
  -repo "https://earth.bsc.es/gitlab/ces/automatic_performance_profiling.git" \
  -b "master"
```

Then, from the experiment root (`cd /esarchive/autosubmit/<expid>`), add the model to `conf/minimal.yml` (e.g. `sed -i "/HPCARCH: .*/a \ \ MODEL: ${model}" conf/minimal.yml`), configure `~/platforms_credentials.yml` with your user, and run `autosubmit create <expid>`.

Operate the workflow with the Autosubmit CLI (the expid is a positional argument):

1. **Run** the workflow: `autosubmit run <expid>`
2. **Inspect** rendered job scripts without submitting (dry-run): `autosubmit inspect <expid> --quick -f`
3. **Monitor** live status: `autosubmit monitor <expid>`
4. **Query stats**: `autosubmit stats <expid>`
5. **Requeue** a job: `autosubmit setstatus <expid> -fl "<job>" -t READY -s`
6. **Recover** failed/waiting jobs: `autosubmit recovery <expid>`
7. **Clean up**: `autosubmit clean <expid>`, `autosubmit archive <expid>`, `autosubmit refresh <expid>`

### Monarch special case

Monarch is run through the Auto-Monarch workflow (which provides its own Autosubmit config and templates), so creating an experiment requires extra steps. After generating the expid with `autosubmit expid -min ...`:

1. Clone the APP repository into the experiment with `autosubmit refresh ${expid}`.
2. Run the copy script (from the experiment root, replace `SRC_EXPID`/`CURRENT_EXPID`):

   `python3 proj/auto-performance-profiling/cfg/utils/monarch/copy_experiments.py --src-expid <SRC_EXPID> --current-expid <CURRENT_EXPID>`

   The script rsyncs `proj/auto-monarch/` from the source experiment into the current one, symlinks the APP `autosubmit/` and `cfg/` folders into the Auto-Monarch project, sets `PROJECT.PROJECT_DESTINATION` to `auto-monarch` (and `APP_PROJECT_DESTINATION` to the original APP project) in `conf/minimal.yml`, comments out `jobs-execution.yml` in the experiment's `bootstrap.yml`, and regenerates the monarch config files (`proj_monarch.yml`, `jobs.yml`, `platforms_monarch.yml`) from the source experiment. Pass `--no-copy-source` to copy only the templates (use when rerunning the script).
3. Update the platforms configuration (`autosubmit/configuration/user/platforms_monarch.yml`) with your user and adjust `proj_monarch.yml` if necessary.
4. Create the experiment with `autosubmit create ${expid}`.

Note: MONARCH reports scalability using simulated days per day (SDPD) instead of the default simulated years per day (SYPD), and it does not use the WeakScaling test (no `jobs-weakscaling.yml`).

## Common Development Tasks

**Add a test:** (1) `core/jobs/model/<MODEL>/jobs-<test>.yml` — copy `jobs-strongscaling.yml`; job must be named `CONFIGURATION_JSON_<TEST>`. (2) Runner template in `autosubmit/templates/`. (3) `<TEST>:` block in `proj.yml`. (4) `APP_TESTS.<TEST>.ENABLED: "TRUE"` in the job file. (5) `case` branch in `configuration_json.sh` for input globs + reporter flags. (6) Raw data producer in `post.sh`. (7) Register in `bootstrap.yml` + `report.sh`.

**Add a model:** (1) `user/model/<MODEL>/proj.yml`. (2) `core/jobs/model/<MODEL>/jobs-*.yml` per test. (3) Model params in `configurations/model/<MODEL>/`. (4) Arch files in `cfg/arch/<platform>/<MODEL>/`. (5) Helpers in `cfg/utils/<MODEL>/`. (6) Template dispatch: `compile_<model>`, `clone_<model>`, `ini_<model>`, `post_<model>` in the matching templates; `autosubmit/templates/models/<MODEL>/run.sh` for `run_<model>`. (7) `case` in `configuration_json.sh`.

**Add an HW benchmark:** (1) Extend `HW_BENCHMARKS` in `user/common.yml` (`NAMES`/`PROCESSORS` drive the `FOR` loops). (2) Runner template. (3) Parser under `cfg/benchmarks/`. (4) Uncomment `jobs-hwbenchmarks.yml` in `bootstrap.yml` + set `ENABLED: true`.

**Add a platform:** (1) Define in `user/platforms.yml` (real `USER` in `~/platforms_credentials.yml`). (2) `cfg/env/<platform>/environment.env`. (3) `cfg/arch/<platform>/<MODEL>/` arch files for each model.

**Add a Paraver/Dimemas view:** (1) Drop `.cfg` into `cfg/trace_analysis/paraver_configurations/` (or `dimemas_configurations/`). (2) List its name in `TRACING.PARAVER.CFGS` (or `TRACING.DIMEMAS.CFGS`) in `user/common.yml`. (3) Optionally add to `COMPARE_CFGS` for cross-case comparison images.

Full step-by-step: **`.agents/references/extending.md`**.

## Testing and Validation

- Validate rendered job scripts before running: `autosubmit inspect <expid> --quick`
- Check Bash templates with `bash -n` and `shellcheck`; templates use strict-mode tracing (`set -xv`/`set -xuve`) and `%VARIABLE%` substitution
- Lint Python under `cfg/` (parsers, collectors, comparators, reporters) before committing
- Build docs with `make html` in `docs/` (Sphinx; dependencies in `docs/requirements.txt`)

## Workflow Guidelines

1. Never change `EXPERIMENT.DATELIST` or `EXPERIMENT.MEMBERS` in `defaults.yml` without reason — they are placeholders required by Autosubmit. The workflow does not use the AS members feature: auto models (only auto-monarch) run a single member, and non-auto models don't use members at all (tests are selected via `EXPERIMENT.APP_TESTS` plus the `bootstrap.yml` include files)
2. Per-experiment customization belongs in `$expid/conf`, not in the project configuration
3. Model-specific job definitions live in `autosubmit/configuration/core/jobs/model/<MODEL>/jobs-*.yml`
4. Shared workflow config lives in `autosubmit/configuration/user/common.yml` and platform config in `user/platforms.yml`
5. Credentials are kept outside the repo in `~/platforms_credentials.yml` — never hardcode users
6. DO NOT modify other folders outside the current experiment directory, example don't try to modify experiments under /esarchive/autosubmit since that folder is shared
7. DO NOT remove any files, if it is needed to continue the developments create a backup and remove it.
8. Commits for small changes can be a short title, if there are a lot of changes use multiple line explanation commit
9. The code, when possible, should be self-documenting, meaning that if the variables and logic are self explanatory there is no need for long comments in the code. Docstring for functions are still mandatory. This also applies to config files, env files...