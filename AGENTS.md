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
`dimemas_*.sh`, `modelfactors.sh`) and post-processing (`post.sh`, `analysis.sh`,
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
- Handle I/O sync and data integrity across distributed filesystems.
- Validate with `bash -n` and `shellcheck` before submitting.

## Analysis pipeline (`cfg/parser/`)

```
raw outputs -> collector.py -> <TEST>.json -> reporter.py (per test) -> report.sh -> ReportGenerator.py -> PDF
                                          \-> comparator.py (per member) /
```

`collector.py` (`-m inputs.yml -o <name>`), `reporter.py` (`-j <test>.json`, `-s/-p/-f`, `-v <metric>`) and
`comparator.py` (`-j <jsons> -s/-w --out-dir`) drive the three stages; each is a shim over the standalone
package in `cfg/parser/src/`. No file name is inspected to decide what a file contains: the mapping names
the format (`registry.py`) and the format selects the loader. Adding a model parser = one
`models/<model>.py` + one `registry.py` entry + one `component_specs` line in `analysis.sh`.

Full detail (every flag, the per-model input globs, the split folders): **`.agents/references/pipeline.md`**.
Python style there: PEP 8, type hints, Google-style docstrings, Python 3.9+, vectorised NumPy/pandas.
API docs: `docs/source/developers_guide/`.

## Workflow configuration

`conf/minimal.yml` → `bootstrap.yml` merges the shipped `core/defaults.yml`, the model `proj.yml`, the
`user/` files, `jobs-execution.yml`, the per-model `jobs.yml`, the per-test `jobs-<test>.yml` files,
`jobs-common.yml` and `core/platforms/<HPCARCH>.yml` **in that order (later wins)**, then
`~/platforms_credentials.yml`. The row-by-row chain: `.agents/references/configuration.md`.

**Test enable/disable** needs both layers (see **Overview**): the `jobs-<test>.yml` line in
`bootstrap.yml` `CUSTOM_CONFIG.PRE`, *and* that file's `EXPERIMENT.APP_TESTS.<TEST>.ENABLED: "TRUE"`
over the `"FALSE"` default in `core/defaults.yml`.

**Config traps that produce silence, not errors** (detail: `.agents/references/troubleshooting.md`):
- `core/jobs/model/ecearth4/jobs.yml` uses a **lowercase `jobs:`** key — Autosubmit reads only `JOBS`, so the whole file is skipped
- `core/jobs/platform/<HPCARCH>/jobs.yml` is **never loaded** — `bootstrap.yml` only includes `core/platforms/<HPCARCH>.yml`
- `conf/metadata/experiment_data.yml` is Autosubmit's resolved-config dump — editing it has zero effect
- `FOR` jobs must be fully self-contained (incl. `FILE`) in their block; a later file redefining a `FOR` job without `FILE` silently drops it

## Running and Operating the APP Workflow

Full instructions for installing, creating, and configuring the workflow are in the user guide:
`docs/source/users_guide/users_guide.rst` (source) or
https://automatic-performance-profiling.readthedocs.io/en/latest/ (built docs). In short:
`autosubmit expid -min -H "<PLATFORM>" --git_as_conf autosubmit/configuration/bootstrap.yml
-repo <app-repo> -b master`, add `MODEL` to `conf/minimal.yml`, set your user in
`~/platforms_credentials.yml`, then `autosubmit create <expid>`. In the bsceshub, `module load
autosubmit` (a pip install also has to configure the AS experiments database).

Operate the workflow with the Autosubmit CLI (the expid is a positional argument):

1. **Run** the workflow: `autosubmit run <expid>`
2. **Inspect** rendered job scripts without submitting (dry-run): `autosubmit inspect <expid> --quick -f`
3. **Monitor** live status: `autosubmit monitor <expid>`
4. **Query stats**: `autosubmit stats <expid>`
5. **Requeue** a job: `autosubmit setstatus <expid> -fl "<job>" -t READY -s`
6. **Recover** failed/waiting jobs: `autosubmit recovery <expid>`
7. **Clean up**: `autosubmit clean <expid>`, `autosubmit archive <expid>`, `autosubmit refresh <expid>`

Monarch runs through the Auto-Monarch workflow — its own Autosubmit config and templates, so the expid
needs the `cfg/utils/monarch/copy_experiments.py` steps; see
`docs/source/users_guide/configure_monarch.rst`. It reports scalability as SDPD and has no WeakScaling
test.

## Common Development Tasks

Recipes listing every file to touch — add a test, a model, an HW benchmark, a platform, a Paraver/Dimemas
view: **`.agents/references/extending.md`**.

## Testing and Validation

- When validating a change in a test experiment, rerun only the affected jobs — but "affected" is transitive: a job is
  also affected when it consumes what the change produces, even if none of its own files changed. In particular, a
  change to the on-disk layout (per-split run dirs, renamed or aggregated outputs) affects every downstream job that
  reads that layout (`POST_*`, `ANALYSIS_*`, `REPORT`)
- Validate rendered job scripts before running: `autosubmit inspect <expid> --quick`
- Check Bash templates with `bash -n` and `shellcheck`; templates use strict-mode tracing (`set -xv`/`set -xuve`) and `%VARIABLE%` substitution
- Lint Python under `cfg/` (parsers, collectors, comparators, reporters) before committing
- Parser tests: `python3 -m pytest cfg/parser/tests`. The fixtures are **real** outputs from the MN5
experiments, named `<model>-<version>-…`; when a release changes a format, add the new versioned
file next to the old one instead of overwriting it (`cfg/parser/tests/fixtures/README.md` has the
provenance and versions)
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
10. NEVER commit, push, or publish changes without explicit user approval. Make changes locally, present them, and wait for the user to say "commit" or "push". This includes git add/commit/push, creating merge requests, or any action writing to a remote.
11. NEVER change, weaken or delete a test (or a fixture) so that your change passes. A failing test is information: fix the code. Edit a test only when the test itself is wrong — it encodes behaviour that was intentionally changed, or it asserts an implementation detail instead of the contract — and state in your reply which test you touched and why. Never overwrite an existing fixture to make a new format parse; add the new version next to it.
