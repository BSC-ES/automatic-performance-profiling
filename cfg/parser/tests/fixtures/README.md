# Parser test fixtures

Real output files taken from the APP test experiments on MareNostrum 5, so a format change in a
model or tool release shows up as a failing test instead of a silent zero in the report.

The model (or tool) version is part of the file name. When a release changes a format, add
`<model>-<new-version>-...` next to the current one and keep both tests, so the old format is not
lost while experiments using it are still around.

Fetched 2026-10-27 from `mn5-gpp4:/gpfs/scratch/bsc32/bsc032333/`.

| Fixture | Source (relative to the path above) | Version | Notes |
|---|---|---|---|
| `nemo-4.0-bench_1-timing.output` | `abxl/run/strongscaling/BENCH/run_bench_1/nemo-bench_1-timing.output` | NEMO 4.0 | 112 ranks, concatenated by `post_nemo` |
| `nemo-4.0-bench_1-test_info.csv` | `abxl/run/strongscaling/BENCH/run_bench_1/bench_1-test_info.csv` | — | `report_test_cfg` output |
| `nemo-5.0/nemo-5.0-bench_1-timing.output` + `nemo-5.0/namelist_cfg` | — | NEMO 5.0 | **synthetic**: no NEMO 5 APP run exists yet; the parser reads `namelist_cfg` from the same directory |
| `oifs-48r1-bench_1-ifs.stat` | `a7nq/run/strong_scaling/BENCH/run_bench_1/oifs-bench_1-ifs.stat` | OIFS 48r1 | |
| `ecearth4-nemo4.0-oifs48r1-bench_1-test_info.csv` | `a7nq/run/strong_scaling/BENCH/run_bench_1/bench_1-test_info.csv` | NEMO 4.0 + OIFS 48r1 | both components in one file |
| `ecearth4-lucia-lite-v2-table.csv` | `a7nq/run/strong_scaling/BENCH/run_bench_1/lucia_lite_results/table.csv` | LUCIA lite v2 | coupling report |
| `icon-2024.10-bench_1-timing.output` | `absd/run/strongscaling/BENCH/run_bench_1/icon-bench_1-timing.output` | ICON 2024.10 (HPCW v3.0) | GNU `time` `@hpcw-time:` line |
| `icon-2024.10-bench_1-timer.log` | `absd/run/strongscaling/BENCH/run_bench_1/icon-bench_1-timer.log` | ICON 2024.10 | one `Timer report`, wrapped rows |
| `icon-2024.10-bench_1-test_info.csv` / `.yaml` | `absd/run/strongscaling/BENCH/run_bench_1/bench_1-test_info.*` | — | |
| `extrae-4.3.3-Time.pm` | `absd/run/tracing/BENCH/paramedir/icon-trace_1-Time.pm` | Extrae 4.3.3 | `paramedir` `Time` counter, case `trace_1`, component `icon` |
| `dimemas-5.4.2-Original-Wallclock.dm` | `absd/run/tracing/BENCH/dimemas_traces/trace_1_icon_Original_Wallclock.dm` | Dimemas 5.4.2-devel | tracing and Dimemas are disabled by default |

Versions were read from the runs themselves: the `version` line of the NEMO timing, the ICON URL in
`<absd>/compilation/hpcw_v3.0/versions.cmake` (`icon-2024.10-public`), `oifs-48r1` in the experiment
multiprog launcher, and the module loads in `cfg/env/mn5/*.env` (`extrae/4.3.3`, `dimemas/5.4.2-devel`).
