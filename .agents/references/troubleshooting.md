# Troubleshooting

Everything below was verified against this repository (or observed while debugging a real experiment,
where noted). Check the item before inventing a new explanation.

## Config is silently ignored

**`core/jobs/model/ecearth4/jobs.yml` uses a lowercase `jobs:` key.** Autosubmit reads only `JOBS`,
so the entire file is skipped with no error. Verified at line 1 of that file. Check the key case
first whenever "my job definitions have no effect" on a model.

**`core/jobs/platform/<HPCARCH>/jobs.yml` is never loaded.** `bootstrap.yml` includes
`core/platforms/<HPCARCH>.yml` (which sets `DEFAULT.LOGIN_PLATFORM` and similar), not
`core/jobs/platform/<HPCARCH>/jobs.yml`. Editing the latter has no effect.

**`conf/metadata/experiment_data.yml` is not an input.** It is Autosubmit's own resolved-config dump.
Editing it changes nothing at run time; the real overrides belong in `$expid/conf/minimal.yml`.

**`core/jobs/jobs-execution.yml` is part of the current chain.** It is listed (uncommented) in
`bootstrap.yml` `CUSTOM_CONFIG.PRE` and supplies `REMOTE_SETUP`, `REMOTE_INIDATA`,
`REMOTE_COMPILATION` and `PREPARE_TESTS` for the models that lack their own setup jobs. Only the
**monarch** flow comments it out, and the copy script does that for you. (An older note in
`AGENTS.md` claimed it was unreferenced — that is wrong.)

## Missing `FILE` on a `FOR` job

Observed while fixing the hpcw model (now fixed):

```
AutosubmitCritical: 7014 Mandatory FILE parameter not found
```

`parse_data_loops` **replaces** the expanded `<JOB>_<VALUE>` entries wholesale, so a job with `FOR:`
must be fully self-contained in its own block — including `FILE`. If a later file in the chain
redefines a `FOR` job without `FILE`, the job is silently dropped. `autosubmit create` only warns;
`autosubmit run` fails. Fixed for `hpcw` by adding `FILE` to the `REMOTE_COMPILATION` block in
`core/jobs/model/hpcw/jobs.yml`. The same pattern still exists in the (unloaded)
`core/jobs/platform/*/jobs.yml` files.

## `members` are a leftover (migration complete)

Tests are **not** selected by members — selection is `bootstrap.yml` (the job chain) plus
`EXPERIMENT.APP_TESTS` (the report). Each test used to be a member distinguished by a shared
`Scalability`/`post`/`trace` job name and `MEMBERS_FROM` cross-test dependency rework; that is gone.
Every per-test job file now names its jobs after the test:

```
SCALABILITY_<TEST> -> POST_<TEST> -> ANALYSIS_<TEST>
```

(tracing adds `FUNCTIONS_DIR`, `TRACE`, `TRACE_CUT`, `PARAMEDIR`, `PARAVER`, `MODELFACTORS`,
`DIMEMAS_*`, `PARADIM`). `RUNNING: member` remains only because `EXPERIMENT.MEMBERS: "000"` in
`core/defaults.yml` is a placeholder Autosubmit requires — a single member, so each job still runs
once; do not repurpose it.

## Report section missing (or report fails)

The report is gated by `EXPERIMENT.APP_TESTS.<TEST>.ENABLED`, not by the job chain. Two failure
modes:

- Test ran, but its `APP_TESTS` key is `"FALSE"` → the section is silently absent.
- Key is `"TRUE"` but the job chain is absent → `add_<member>` runs against missing artifacts and
  the `REPORT` job fails.

Every model's per-test job files (`hpcw`, `monarch`, `nemo`, `ecearth4`) flip their `APP_TESTS` key
to `"TRUE"`; `core/defaults.yml` keeps the `"FALSE"` defaults, and `$expid/conf` can override them.

## `analysis.sh` finds no tests

The member is recovered by pattern-matching the job name:

```bash
current_member=$(echo "%TASKTYPE%" | grep -oE "COMPILATION_EFFICIENCY|STRONGSCALING|WEAKSCALING|TRACING|HW_BENCHMARKS")
```

So the test job must be named `ANALYSIS_<MEMBER>`. Rename it and `current_member` becomes
empty: the `case` matches nothing, `tests` is unset and the loop does nothing — no error, no output.

## HPCW re-downloads multi-GB inputs

`MODEL.STORE` must point to a path shared across archs and experiments. HPCW appends its own store
(`${CMAKE_SOURCE_DIR}/hpcw-store`) to CMake's ExternalData module, so `ExternalData_OBJECT_STORES`
is ignored. With `STORE: ""` each compilation job keeps a throwaway store and re-downloads
everything. Populate a real store with `cfg/utils/hpcw/populate_store.sh`; `user/model/hpcw/proj.yml`
ships a populated MN5 path.

## MN5: long compilations die on the login node

Observed on MN5. `/etc/security/limits.conf` sets `* soft cpu 5` / `* hard cpu 5` — 300 s of CPU
time per process. Autosubmit `ps`-type jobs run on the login node and inherit it, so a long
optimised build (e.g. `-O3`) can be killed by `SIGXCPU` with little to show in the log. The `ps`
platforms here are `%DEFAULT.LOGIN_PLATFORM%`-bound setup jobs; heavy compilation belongs on the
scheduler platform.

## `ps`-type job status looks wrong

For `ps` (login) jobs the `.STAT` file is three lines — start timestamp, end timestamp, `COMPLETED` —
and a `<job>_COMPLETED` marker file is written alongside it. Autosubmit inspects the last line and
the marker; a hand-written STAT file with the wrong shape reports a bogus state.

## Diagnose without submitting

```bash
autosubmit inspect <expid> --quick -f     # render every job script, no submission
autosubmit describe <expid>               # resolved config for the run
bash -n <template>; shellcheck <template> # templates use %PLACEHOLDER%
```

Templates only resolve placeholders at submission time, so `inspect` is the real check — a template
that looks fine on disk can still render to something broken.

A strict config check without a full run:

```python
from autosubmit.config.basicconfig import BasicConfig
from autosubmit.config.yamlparser import YAMLParserFactory
from autosubmitconfigparser.config.configcommon import AutosubmitConfig

BasicConfig.read()
as_conf = AutosubmitConfig("<expid>", BasicConfig, YAMLParserFactory())
as_conf.check_conf_files(running_time=True, force_load=True)
```
