# Report generation

`autosubmit/templates/report.sh` runs as the `REPORT` job on the login platform. It consumes the
artifacts that `configuration_json.sh` produced and emits the final PDF.

## Flow

1. Sourcing `cfg/env/<platform>/environment.env`, then `PYTHONPATH=$PYTHONPATH:$PROJECT_ROOT`.
2. `report_folder=$CURRENT_ROOTDIR/report/` — **removed with `rm -rf` and recreated**, so everything
   in it is regenerated each run. `report.pkl` is git-ignored.
3. Repeated `ReportGenerator.py -O report.pkl …` calls accumulate sections into the pickle.
   The introduction is always added first (`--section-title "Introduction" --section-number 1`,
   text from `cfg/latex/Introduction.txt`), then the experiment-configuration table plus a glossary
   are appended at the end.
4. `ReportGenerator.py -O report --dump-to-file` renders `report.tex`.
5. `pdflatex --shell-escape report.tex && pdflatex report.tex` (twice, for cross-references). If
   `pdflatex` is absent the script prints the `.tex` path instead of failing outright.

## Section gating

```bash
declare -A enabled_members=(
    ["tracing"]="%EXPERIMENT.APP_TESTS.TRACING.ENABLED%"
    ["strongscaling"]="%EXPERIMENT.APP_TESTS.STRONGSCALING.ENABLED%"
    ["weakscaling"]="%EXPERIMENT.APP_TESTS.WEAKSCALING.ENABLED%"
    ["compilation_efficiency"]="%EXPERIMENT.APP_TESTS.COMPILATION_EFFICIENCY.ENABLED%"
)
for current_member in "${!enabled_members[@]}"; do
    if ${enabled_members[$current_member],,}; then add_${current_member,,}; fi
done
```

So the report content is driven purely by the four `APP_TESTS` flags — **not** by which
`jobs-<test>.yml` files are in `bootstrap.yml`. A test can run without appearing in the report (and
vice versa, which fails at report time because the artifacts are missing). Keep the two layers in
sync.

## Sections

| Section | Produced by | Content |
|---|---|---|
| `Introduction` | inline | `cfg/latex/Introduction.txt` |
| `Experiment configuration` | inline | `test_info.csv`: resolution, test steps, output, platform; model-specific extras (`ecearth4` resolutions/dates, `monarch` datelist/hours) |
| `Scalability` | `add_strongscaling` | `cases_info.csv`, then `<test>_scaling.{csv,png}`; per-component `<component>_<test>_scaling.*`; `ecearth4` coupling from `coupling/*/{summary.csv,stacked_events.png}` |
| `Tracing` | `add_tracing` | per test: `test_info.csv` (dates/steps, or `NHOURS` for monarch); then `Functions detailed report`, `${COMPONENT} Paraver`, `${COMPONENT} Model Factors`, `${COMPONENT} MPI Call Profile` |
| `Multi Experiment` | `add_compilation_efficiency`, `add_weakscaling` | `comparator.py` output: `<name>-scaling.{csv,png}` for compilation efficiency, per-component comparisons for weak scaling |
| `Hardware Benchmarks` | `add_hw_benchmarks` | OSU images from `run/hw_benchmarks/OSU_RUN/IMAGE/*.png`, STREAM from `run/hw_benchmarks/STREAM_RUN/<model>.png` |
| `Glossary` | inline | `cfg/latex/text/Glossary.txt` |

Tracing sub-sections are each individually gated by their `TRACING.*` switch:
`MODELFACTORS.ENABLED`, `MPI.ENABLED`, `USER_FUNCTIONS.ENABLED`, `PARAVER.ENABLED`.

## `ReportGenerator.py`

`cfg/latex/ReportGenerator.py` is a stateful CLI: it reads and rewrites the pickle named by `-O`.

| Flag | Meaning |
|---|---|
| `-O` | pickle path (with `.pkl` to accumulate, without it for `--dump-to-file`) |
| `-S` | section title |
| `-s` | sub-section title |
| `-ss` | sub-sub-section title |
| `-T` | text file to insert |
| `--add-csv` | CSV/table to add |
| `--add-img` | image to add |
| `--add-caption` | caption for the preceding table/image |
| `--csv-convert`, `-p`, `-r`, `-f`, `--silent` | CSV presentation (precision/rotate/fit-margins/suppress noise) |
| `--section-title`, `--section-number` | create a top-level section |
| `--report-title`, `--report-authors`, `--logo-path`, `--add-newcommand` | document metadata, from `REPORT.*` in `user/common.yml` |
| `--dump-to-file` | render `report.tex` |

Supporting assets: `cfg/latex/report.cfg` (`REPORT.CONFIG`), `cfg/latex/csv_formatter.py`,
`cfg/latex/text/` (one `.txt` per section/sub-section, e.g. `Scalability.txt`, `Function.txt`,
`ParaverViews.txt`, `ModelFactors.txt`, `OSU.txt`, `STREAM.txt`, and per-member texts keyed by the
lowercased member name), `cfg/latex/img/`.

To add a new section: add the `add_<member>` function, a `cfg/latex/text/<member>.txt`, and register
the member in the `enabled_members` map.
