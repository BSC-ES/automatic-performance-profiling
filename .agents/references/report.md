# Report generation

`autosubmit/templates/report.sh` runs as the `REPORT` job on the login platform. It consumes the
artifacts that `analysis.sh` produced and emits the final PDF.

## Flow

1. Sourcing `cfg/env/<platform>/environment.env`, then `PYTHONPATH=$PYTHONPATH:$PROJECT_ROOT`.
2. `report_folder=$CURRENT_ROOTDIR/report/` — **removed with `rm -rf` and recreated**, so everything
   in it is regenerated each run. `report.pkl` is git-ignored.
3. Repeated `ReportGenerator.py -O report.pkl …` calls accumulate sections into the pickle.
   The glossary is always added first (`--section-title "Glossary"`, text from
   `cfg/latex/text/Glossary.txt`), then the introduction (`cfg/latex/Introduction.txt`), then the
   experiment-configuration table, then the test sections in a fixed order
   (`strongscaling`, `tracing`, `weakscaling`, `compilation_efficiency`), so the document structure
   does not depend on shell hash ordering.
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
for current_member in strongscaling tracing weakscaling compilation_efficiency; do
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
| `Glossary` | inline | `cfg/latex/text/Glossary.txt` (first section) |
| `Introduction` | inline | `cfg/latex/Introduction.txt` |
| `Experiment configuration` | inline | `test_info.csv`: resolution, test steps, output, platform; model-specific extras (`ecearth4` resolutions/dates, `monarch` datelist/hours) |
| `Scalability` | `add_strongscaling` | `Test configuration` subsection: test settings + `cases_info.csv`; then `<test>_scaling.{csv,png}`; per-component `<component>_<test>_scaling.*`; `ecearth4` coupling from `coupling/*/{summary.csv,stacked_events.png}` |
| `Tracing` | `add_tracing` | per test: `Test configuration` subsection with `test_info.csv` (dates/steps, or `NHOURS` for monarch) and `cases_info.csv`; then `Whole-model functions` (multi-component only), `${COMPONENT} Functions detailed report` (adds `${component}_function_time_share.png` under the most-expensive-function summary), `MPI Call Profile` (adds `${component}_mpi_profile_share.png`), `Model Factors`, `Paraver` |
| `Multi Experiment` | `add_compilation_efficiency`, `add_weakscaling` | `comparator.py` output: `<name>-scaling.{csv,png}` for compilation efficiency, per-component comparisons for weak scaling; the test settings and per-build `cases_info.csv` go in the `Test configuration` subsubsection and the `Results` subsubsection holds the comparison table and plot (subsubsections render in insertion order, so configuration comes first) |
| `Hardware Benchmarks` | `add_hw_benchmarks` | OSU images from `run/hw_benchmarks/OSU_RUN/IMAGE/*.png`, STREAM from `run/hw_benchmarks/STREAM_RUN/<model>.png` |

Tracing sub-sections are each individually gated by their `TRACING.*` switch:
`MODELFACTORS.ENABLED`, `MPI.ENABLED`, `USER_FUNCTIONS.ENABLED`, `PARAVER.ENABLED`.
When user functions are enabled, the report includes two tables with one row per function and
traced case: `tracking/MPI/<component>_functions.csv` (MPI call share) and
`tracking/counters/<component>_functions.csv` (IPC, cycles, cache misses), each followed by its
figure: `<component>_function_mpi_share.png` (stacked bars, one per function and case, grouped
under the function name) and one figure per counter of
`TRACING.USER_FUNCTIONS.PAPI_COUNTERS.SCALABILITY_PLOTS`,
`<component>_function_counters_<COUNTER>.png` (IPC and PAPI_L3_TCM by default, one line per
function). Tables and figures name each counter by its PAPI id without the `PAPI_` prefix
and give its unit, `IPC (instructions per cycle)` and `L3_TCM (misses per 1000
instructions)`.

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
| `--csv-convert`, `-p`, `-r`, `--silent` | CSV presentation (precision/rotate/suppress noise) |
| `-g` | group the rows: an empty first cell continues the group above, a rule separates the groups, and the all-numeric columns are right aligned. It emits a plain booktabs `tabular` instead of `\csvautobooktabular` (as does any table whose header holds `\&%#_`, see below) |
| `--section-title`, `--section-number` | create a top-level section |
| `--report-title`, `--report-authors`, `--logo-path`, `--add-newcommand` | document metadata, from `REPORT.*` in `user/common.yml` |
| `--dump-to-file` | render `report.tex` |

Supporting assets: `cfg/latex/report.cfg` (`REPORT.CONFIG`), `cfg/latex/csv_formatter.py`,
`cfg/latex/Introduction.txt` plus `cfg/latex/text/` (one `.txt` per section/sub-section, e.g.
`Scalability.txt`, `Tracing.txt`, `Function.txt`, `MPI.txt`, `ParaverViews.txt`,
`ModelFactors.txt`, `HardwareBenchmarks.txt`, `OSU.txt`, `STREAM.txt`, and per-member texts keyed by
the lowercased member name), `cfg/latex/img/`.

Every section and subsection gets a `-T` description (what is measured, how the tables and figures
are read); `ReportGenerator.py` skips sections and subsections that end up with no content, so an
empty view never leaves a blank page.

Every table keeps its natural size. It is centred on the text block and, when it does not fit,
grows into both margins instead of being scaled down to them; the `\fitpage` macro of the
preamble scales it down, keeping the aspect ratio and a 1 cm margin on each side of the paper
(`\apptablemargin`), only when it would be wider than the page (`\paperwidth`, or `\paperheight`
for a table set in landscape). The `\makebox[\linewidth][c]`
around it is what centres the overflow: its `\hss` padding shrinks, whereas plain `\centering`
cannot shrink and pushes the whole excess to one side. The preamble sets
`\belowcaptionskip` to 8pt, because the `article` class leaves it at 0pt and the top rule of a
table was landing on the last line of its caption.

Every table and figure caption names the unit of the values it shows, and the table headers and
axis labels carry it too: the scalability metric comes from `scalability_label()` in
`cfg/parser/src/scaling.py` (`sypd` → `SYPD (simulated years per day)`, `time` → `Integration
time (s)`), and the scatter plot axes and counter figures from `scatter_axis_label()` in
`timing.py` and `counter_label_with_units()` in `curation.py`. A magnitude without its unit
cannot be compared across platforms, so do not add a table of values without it.

Two kinds of column are the exception, because their name is short and their prose already carries
the explanation:

- **A percentage** is written `(%)`, and the **caption** says what it is a percentage of (`MPI call
  profile ... in % of the traced window`, `each column of a case is the % of the fastest timestep
  of that case spent in the function`). A header never grows into a sentence.
- **A hardware counter** is written as its **PAPI id** without the `PAPI_` prefix (`IPC`,
  `TOT_CYC`, `L1_DCM`, `L2_DCM`, `L3_TCM`), and the caption spells the units out (`L1_DCM`,
  `L2_DCM` and `L3_TCM` are misses per 1000 instructions, so the value is a rate and not a
  count). The tables that carry them are the ones of `tracking/MPI` and `tracking/counters`; the
  figures keep the unit on their axis (`counter_label_with_units()`).

`\csvautobooktabular` cannot print either: csvsimple reads the header cells as pgfkeys keys and
typesets them as text, so `%` would start a comment and `_` would be a math subscript. A table
whose header holds `\&%#_` is therefore typeset from its data instead
(`LatexText.add_data_table()`), where `_latex_header()` escapes the cells; the rest keep on reading
the dumped CSV at LaTeX time. Csvsimple also splits the header on commas, so a column name must
never contain one (`compare in %`, not `compare, %`).

To add a new section: add the `add_<member>` function, a `cfg/latex/text/<member>.txt`, and register
the member in the `enabled_members` map **and** in the fixed order list that drives the section
loop in `report.sh`.
