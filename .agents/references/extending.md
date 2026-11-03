# Extending the tool

Recipes for adding things to APP. Each step is a file you must touch — missing one usually shows up
as a silent no-op rather than an error (see `troubleshooting.md`).

## Add a performance test

1. **Job chain** — `autosubmit/configuration/core/jobs/model/<MODEL>/jobs-<test>.yml`, defining
   `Scalability` (or `trace`) → `post` → `ANALYSIS_<TEST>`. Copy `jobs-strongscaling.yml`
   as the template. The job **must** be named `ANALYSIS_<TEST>`: that suffix is what
   `analysis.sh` greps out of `%TASKTYPE%` to identify the test.
2. **Runner template** — `autosubmit/templates/`. Reuse `scalability.sh` if it is a scalability test;
   it `source`s the per-model runner (step 6) and calls `run_${model}`.
3. **Test spec** — `<TEST>:` block in `autosubmit/configuration/user/model/<MODEL>/proj.yml`:
   `TEST_NAMES`, `NAMES`, `PROCESSORS`, `THREADS`, `TEST_CONFIG`, `ARCH_NAME`. The `FOR` block in the
   job file reads these.
4. **Report flag** — `EXPERIMENT.APP_TESTS.<TEST>.ENABLED: "TRUE"` in that same job file. `APP_TESTS`
   has no entry for `HW_BENCHMARKS`; only add a key that `core/defaults.yml` already declares.
5. **Input mapping + reporter params** — a `case` branch in `analysis.sh`. It adds the
   `component_specs` entries (`"<component>|<format>|<pattern>"`), the `case_level_specs` entries
   (`"<format>|<pattern>"`) for whole-case inputs, and the reporter flags for the member. The specs
   are written to `inputs.yml` by `write_input_mapping`, so no file name is ever inspected to decide
   its content.
6. **Raw data producer** — `autosubmit/templates/models/<MODEL>/post.sh` writes the collector's base
   input, `run_<member>/<test>/<test>-test_info.csv`, via `report_test_cfg` (monarch uses
   `save_test_yaml` for `.yaml`). `post.sh` is a generic wrapper: it resolves the member runs, calls
   `configure_<model>` when defined, then hands each run to `post_<model>`. If the test emits a new raw
   format, add `cfg/parser/src/models/<model>.py` and register it in
   `cfg/parser/src/registry.py`.
7. **Register** — add the `bootstrap.yml` `CUSTOM_CONFIG.PRE` line, and add `add_<member>` plus an
   `enabled_members` entry to `report.sh`.

## Add a model

1. `autosubmit/configuration/user/model/<MODEL>/proj.yml` — `MODEL` (`NAME`, `COMPONENTS`,
   `REPORT_COMPONENTS`, `ORIGIN`, `BRANCH`, `ARCH_NAMES`), `EXPERIMENT`, and the per-test specs.
2. `autosubmit/configuration/core/jobs/model/<MODEL>/jobs-<test>.yml` for each test. A `jobs.yml`
   with model-wide overrides is optional (only `ecearth4` and `hpcw` have one) even though
   `bootstrap.yml` references the path.
3. Model parameters under `configurations/model/<MODEL>/`.
4. Arch files under `cfg/arch/<platform>/<MODEL>/` — `<component>/<ARCH>.cmake` + `<component>/<ARCH>.env`
   for `hpcw` (one folder per `MODEL.COMPONENTS` entry), `<ARCH>.cmake` + `<ARCH>.env` for
   `monarch`-style models, `arch-<ARCH>.fcm` for `nemo`.
5. Model helpers under `cfg/utils/<MODEL>/`.
6. **Parser** — `cfg/parser/src/models/<MODEL>.py` with a `load(entry, case, component)`
   returning the component dictionary, one entry in `COMPONENT_FORMATS` (and in
   `MODEL_DEFAULT_FORMAT` when the component name implies the format) in
   `cfg/parser/src/registry.py`, and the matching `component_specs` line in
   `analysis.sh`. Tests live under `cfg/parser/tests/`.
7. **Template dispatch** — add `compile_<model>`, `clone_<model>`, `ini_<model>` and
   `test_info_<model>` (the model-specific rows of the report experiment-configuration table) to
   the matching template (`compilation.sh`, `remote_setup.sh` / `hw_remote_setup.sh`, `ini.sh`,
   `report.sh`). The templates that are one-file-per-model do not take a `case`:
   `autosubmit/templates/models/<MODEL>/run.sh` defines `run_<model>`, and
   `autosubmit/templates/models/<MODEL>/post.sh` defines `post_<model>` (plus an optional
   `configure_<model>` for member-dependent inputs). Both are declared in the `FILE` list of the
   matching jobs (`SCALABILITY_*`/`TRACE`, `POST_*`); `scalability.sh` and `post.sh` source them as
   `run_<jobname>` / `post_<jobname>` and dispatch on `${model}`. A model that embeds another one
   reuses its extraction template (hpcw stages `models/nemo/extract.sh`).
   Verified existing pairs: `clone_`/`compile_`/`ini_` `× {ecearth4, hpcw, nemo}` plus
   `post_<model>` for every model.
7. A `case "${model}"` branch in `analysis.sh` for its input files and reporter flags.

## Add an HW benchmark

1. Extend `HW_BENCHMARKS` in `autosubmit/configuration/user/common.yml` — `SOURCE`, `TESTS`, `NAMES`,
   `PROCESSORS`, `ENABLED`. The `NAMES`/`PROCESSORS` lists drive the `FOR` loops in
   `core/jobs/jobs-hwbenchmarks.yml`.
2. Add the runner template (`osu_run.sh`, `stream.sh` as models).
3. Add/extend the parser under `cfg/benchmarks/` — `OSU/osu_test_plots.py`,
   `STREAM/stream_data_parser.py`.
4. Enable it: uncomment the `jobs-hwbenchmarks.yml` line in `bootstrap.yml` and set
   `HW_BENCHMARKS.<NAME>.ENABLED: true`.

## Add a platform

1. Define it in `autosubmit/configuration/user/platforms.yml` (`TYPE`, `HOST`, `PROJECT`, `USER`,
   `QUEUE`, `SCRATCH_DIR`, …). Put the real `USER` in `~/platforms_credentials.yml`.
2. Add `cfg/env/<platform>/environment.env` — sourced by every template and responsible for the
   module environment.
3. Add `cfg/arch/<platform>/<MODEL>/` arch files for each model you intend to build.

## Add a Paraver/Dimemas view

1. Drop the `.cfg` into `cfg/trace_analysis/paraver_configurations/` (or
   `dimemas_configurations/`).
2. List its name in `TRACING.PARAVER.CFGS` (or `TRACING.DIMEMAS.CFGS`) in `user/common.yml`.
3. Optionally add it to `TRACING.PARAVER.COMPARE_CFGS` for an appended cross-case comparison image.
   `report.sh` skips a case with a message when the image is missing, so the first run after adding a
   view is safe.
