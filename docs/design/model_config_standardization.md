# Model config standardization plan

Goal: the per-model config (`autosubmit/configuration/user/model/<MODEL>/proj.yml`) should have the
same section order, the same key order inside those sections, and the same home and name for the
same concept across models — so that reading one model tells you where to find things in another,
and a template can use one placeholder for one concept.

Scope: `ecearth4`, `hpcw`, `nemo`. `monarch` is deliberately excluded (special case: its length is
model hours, it runs through the Auto-Monarch config/templates and has no weak scaling).

Where models genuinely need different things, the plan records the difference as an explicit,
documented exception instead of forcing it.

## 1. Audit of the current differences

| # | What | ecearth4 | hpcw | nemo |
|---|---|---|---|---|
| 1 | Section order | MODEL, EXPERIMENT, TRACING, STRONGSCALING, WEAKSCALING, COMPILATION_EFFICIENCY | MODEL, TRACING, STRONGSCALING, COMPILATION_EFFICIENCY | MODEL, EXPERIMENT, TRACING, STRONGSCALING, WEAKSCALING, COMPILATION_EFFICIENCY |
| 2 | Model output switch | `EXPERIMENT.OUTPUT` | `MODEL.OUTPUT` | `EXPERIMENT.OUTPUT` |
| 3 | Simulation length | `EXPERIMENT.TEST_STEPS` + `TRACING.TRACE_STEPS` | per-test `TEST_STEPS` + `TRACING.TRACE_STEPS` | `EXPERIMENT.TEST_STEPS` + `TRACING.TRACE_STEPS` |
| 4 | Tracing length keys | `TRACE_STEPS: 32` | `TRACE_STEPS: 32` **and** `TEST_STEPS: 10` (conflicting) | `TRACE_STEPS: 32` |
| 5 | Input-data path | `EXPERIMENT.INIDATA` | `MODEL.STORE` | `MODEL.XIOS` (repo, not a path) |
| 6 | Key order inside a test section | `USE_OMP_THREADS`, `MODEL_RESOLUTION`, `TEST_CONFIG`, `ARCH_NAME`, `COUPLING_REPORT` | `TEST_CONFIG`, `TEST_STEPS`, `ARCH_NAME` | `TEST_CONFIG`, `ARCH_NAME` |
| 7 | Weak-scaling base values | `NEMO_BASE_PROCS`, `OIFS_BASE_PROCS`, `NEMO_BASE_RESOLUTION`, `OIFS_BASE_RESOLUTION`; no `THREADS` | section absent | `BASE_PROCS`, `BASE_RESOLUTION`, has `THREADS`; `NAMES` before `TEST_NAMES` |
| 8 | Boolean casing | `FALSE` | `false` | `false` |
| 9 | Defaults in `core/defaults.yml` | — | only `MODEL.STORE` | — |

### Dead / duplicate keys found

| Key | Model | Status |
|---|---|---|
| `MODEL_RESOLUTION` | ecearth4 (TRACING, STRONGSCALING, COMPILATION_EFFICIENCY) | **dead** — no consumer anywhere in `autosubmit/` |
| `TRACING.OUTPUT` | ecearth4 | **dead** — no consumer; duplicates `EXPERIMENT.OUTPUT` |
| `TRACING.START_DATE` / `END_DATE` / `FREQ` / `INTERVAL` | ecearth4 | **live but duplicated** — consumed by `report.sh add_tracing`, while `experiment.*` copies are consumed by `models/ecearth4/run.sh`; two values to keep in sync |
| `WEAKSCALING` section | hpcw | missing, while `core/jobs/model/hpcw/jobs-weakscaling.yml` exists → the test cannot run if enabled |

## 2. Standardization rules

### S1 — Section order

```
MODEL
EXPERIMENT            # omitted when the model has nothing to put in it
TRACING
STRONGSCALING
WEAKSCALING           # only models that support weak scaling
COMPILATION_EFFICIENCY
```

Already true for `nemo`/`ecearth4`; `hpcw` simply omits `EXPERIMENT`. Keep it that way.

### S2 — Key order inside `MODEL`

```
NAME, COMPONENTS, REPORT_COMPONENTS, ORIGIN, BRANCH, ARCH_NAMES, <model extras>
```
Model extras (`STORE`, `XIOS`, `OUTPUT`, `INIDATA`) go last, alphabetically.

### S3 — Key order inside `EXPERIMENT`

```
RESOLUTION, [<COMPONENT>_RESOLUTION ...], START_DATE, END_DATE, FREQ, INTERVAL
```
Only what is genuinely experiment-wide: the resolution(s) and (for date-driven models) the run
dates. Everything else moves out (S4, S5, S8).

### S4 — Simulation length is per test

`TEST_STEPS` becomes a per-test key in **every** test section of every model, replacing
`EXPERIMENT.TEST_STEPS` — the `hpcw` layout becomes the general one. Rationale: a test case fixes how
long the run must be (an ICON package and a NEMO benchmark do not need the same number of steps), and
it puts the length next to the `TEST_CONFIG` it belongs to.

### S5 — Key order inside a test section

```
1. section-wide knobs     TIMESTEP_ZERO, USER_FUNCTIONS_*, [START_DATE, END_DATE, FREQ, INTERVAL]
2. parallel lists         TEST_NAMES, NAMES, PROCESSORS, <COMPONENT>_PROCS, THREADS
3. per-test identity      TEST_CONFIG, TEST_STEPS, ARCH_NAME
4. feature extras         COUPLING_REPORT, USE_OMP_THREADS, SPLITS
```
Lists that must have the same length are grouped and aligned; identity last so the "what/where/how
long" of each test reads as one block.

### S6 — One home for the model output switch

`MODEL.OUTPUT` for all models (drop `EXPERIMENT.OUTPUT`). It is a property of the model run, not of
the experiment, and `MODEL` already hosts `STORE`. Add `OUTPUT: false` to the `MODEL` block of
`core/defaults.yml` as the default.

### S7 — One length key for tracing

Today `TRACE_STEPS` is used for two things at once: the length the model runs
(`models/nemo/run.sh`, `models/hpcw/run.sh`) and the timestep the trace is cut at
(`trace_cut.sh magiccut_steps`). `hpcw` ended up with both `TRACE_STEPS: 32` and `TEST_STEPS: 10`,
which contradict each other.

Rule: `TRACING.TEST_STEPS` = the length the model runs (consistent with S4), and
`TRACING.TRACE_STEPS` = optional cut point, defaulting to `TEST_STEPS` when unset. `trace_cut.sh`
uses `TRACE_STEPS` if set, otherwise `TEST_STEPS`. This keeps the "trace a long run, cut a short
window" use case without two competing run-length keys.

### S8 — Model input-data paths live in `MODEL`

`MODEL.STORE` (hpcw) stays; `EXPERIMENT.INIDATA` (ecearth4) becomes `MODEL.INIDATA`; `MODEL.XIOS`
(nemo) stays. All three answer "where do this model's inputs come from". Add `INIDATA: ""` to the
`MODEL` block of `core/defaults.yml` next to `STORE: ""`.

### S9 — Weak-scaling base values are always component-qualified

`<COMPONENT>_BASE_PROCS` / `<COMPONENT>_BASE_RESOLUTION` for every model (single-component models
qualify with their own component: `NEMO_BASE_PROCS` in `nemo`). Weak scaling is inherently per
component, and this removes the `BASE_*` vs `<COMPONENT>_BASE_*` split. Lower priority than S4-S8
(needs a `models/nemo/run.sh` change for no behavioural gain).

### S10 — Defaults for every standardized key

`core/defaults.yml` gains a default for each key a template reads unconditionally, so no model is
expected to define it and no template sees an undefined placeholder (`MODEL.OUTPUT`, `MODEL.INIDATA`
alongside the existing `MODEL.STORE`).

### S11 — Formatting

* 2-space indent; list values aligned by column inside a block (pad to the longest entry).
* Booleans lowercase: `false` / `true` (templates lowercase with `${var,,}` anyway).
* Quote a scalar only when it needs it (`:` or `+`, e.g. `"TL255L91+eORCA1L75"`).
* Comment header `# <NAME> CONFIG` above every section, same wording for the same section.
* No per-key comments unless the value is non-obvious; no comments that restate the key name.
* Comments that describe another model's conventions were wrong more than once
  (`ARCH_NAMES` says "e.g. arch-O1_prod.fcm for nemo" in the `hpcw` file) — keep them model-accurate.

## 3. Deliberately not standardized

| Thing | Why it stays |
|---|---|
| `monarch` (whole file) | Hours instead of steps, Auto-Monarch config/templates, no weak scaling |
| `ecearth4` `<COMPONENT>_PROCS` (`OIFS_`, `NEMO_`, `XIOS_`, `AMIP_`, `RNFM_`) | Coupled multi-component model; `PROCESSORS` is the total, the rest is the decomposition. `nemo`/`hpcw` are single-component and need none |
| `ecearth4` `<COMPONENT>_RESOLUTION` | Resolution is per component in a coupled model |
| `ecearth4` `FREQ` / `INTERVAL` / run dates | Date-driven run definition; the other models have no dates |
| `ecearth4` `COUPLING_REPORT` + `LUCIA` | Feature only `ecearth4` implements (`post.sh`, `report.sh`, `configuration_json.sh` are gated on it) |
| `ecearth4` `USE_OMP_THREADS` | `ecearth4`-only threading switch |
| `WEAKSCALING` resolution model | `ecearth4`/`nemo` scale by cycling resolutions; the resolution list is inherently model-specific |
| `TEST_CONFIG` value space | Same key everywhere; `hpcw` names ICON input packages, `ecearth4`/`nemo` the `BENCH` test case |
| Per-test `TEST_STEPS` for `hpcw` tracing vs `TRACE_STEPS` | Resolved by S7 (one run-length key) |

## 4. Phases

Each phase is independently reviewable and verifiable; do not mix phases in one commit.

**P0 — dead keys and defaults (no behaviour change).**
Remove `MODEL_RESOLUTION` (ecearth4 ×3) and `TRACING.OUTPUT` (ecearth4). Add `MODEL.OUTPUT` /
`MODEL.INIDATA` defaults to `core/defaults.yml`. Decide the hpcw weak-scaling gap: add a
`WEAKSCALING` section or drop `core/jobs/model/hpcw/jobs-weakscaling.yml`.

**P1 — single-home moves.**
`EXPERIMENT.OUTPUT` → `MODEL.OUTPUT` (`nemo`, `ecearth4`; update `models/*/run.sh`, `report.sh`).
`EXPERIMENT.INIDATA` → `MODEL.INIDATA` (`ecearth4`; update `models/ecearth4/run.sh`,
`compilation.sh`). `EXPERIMENT.TEST_STEPS` → per-test `TEST_STEPS` (`nemo`, `ecearth4`; update
`scalability.sh`, `models/*/run.sh`, `report.sh`). One model per commit.

**P2 — tracing length (S7).**
Replace `TRACING.TRACE_STEPS` with `TRACING.TEST_STEPS` as the run length, make `TRACE_STEPS` the
optional cut point, update `trace_cut.sh`, `models/{nemo,hpcw}/run.sh`, `report.sh`.

**P3 — ordering and formatting (S1-S5, S11).**
Reorder keys and lists, align columns, normalize booleans/comments. No semantic change.

**P4 — weak-scaling base keys (S9, optional).**
`nemo`: `BASE_PROCS` → `NEMO_BASE_PROCS`, `BASE_RESOLUTION` → `NEMO_BASE_RESOLUTION`, move `NAMES`
after `TEST_NAMES`; add the missing `THREADS` to `ecearth4`'s `WEAKSCALING`.

**P5 — docs.**
`docs/source/users_guide/configure_{ece4,nemo,hpcw}.rst` (per-key lists and examples),
`.agents/references/configuration.md` (the shared structure), `CHANGELOG.md`.

## 5. Verification

1. **Placeholder/provider audit** — the check that found the dead keys, run after every phase: list
   every `%SECTION.KEY%` used by the templates, and every key defined by `core/defaults.yml` +
   `user/common.yml` + the model `proj.yml`, and diff. A placeholder with no provider is silently
   replaced by an empty string, so this is the only reliable way to catch a rename that missed a
   consumer.
2. `python3 -c "import yaml; yaml.safe_load(open(p))"` on every touched `proj.yml`.
3. `bash -n` and `shellcheck` on every touched template.
4. `autosubmit create <expid>` + `autosubmit inspect <expid> --quick` on one experiment per model,
   comparing the rendered `.cmd` before/after the phase.
5. One `STRONGSCALING` + `COMPILATION_EFFICIENCY` smoke run per model (and `TRACING` after P2, where
   `trace_cut` is affected).

## 6. Risks

* A renamed/removed key reaches a template as an empty string, so a missed consumer fails **silently**
  (no error, just a wrong or skipped step). Mitigation: the audit in §5.1 plus one model per commit.
* `TEST_STEPS` (P1) touches `scalability.sh`, two `run.sh` and `report.sh`; `scalability.sh` already
  resolves `<TEST>.TEST_STEPS` with no fallback since the last cleanup pass, so models that do not
  define it get an empty value — restore a fallback or keep the resolution per model.
* `trace_cut.sh` output feeds the Paraver/Dimemas sections; a wrong cut point shows up only in the
  report, so P2 needs a tracing smoke run, not just a syntax check.
* Booleans are compared after `${var,,}` in some places and directly in others; normalizing the
  casing in the YAML is safe, but do not remove the `${var,,}` normalizations in the templates.
