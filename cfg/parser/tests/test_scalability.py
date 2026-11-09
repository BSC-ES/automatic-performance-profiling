"""The scalability table and plot are the headline of the report, so their direction must hold."""

import csv

import pytest

from src.curation import generate_scalability_summary
from src.scaling import ideal_value
from src.timing import TimingInformation


def summary_rows(variable, cases):
    """Return the rows of the scalability summary keyed by case name."""
    experiment = TimingInformation(experiment_name="BENCH")
    for name, data in cases.items():
        experiment.add_case({name: data})
    experiment.finalize()

    log = generate_scalability_summary(experiment, scalability_variable=variable)
    rows = [[field.strip() for field in row] for row in csv.reader(log.text.splitlines())]
    assert rows[0][0] == "Case"
    return {row[0]: row for row in rows[1:]}


def test_a_rate_metric_reports_its_speedup_and_efficiency():
    rows = summary_rows("sypd", {"bench_1": {"tasks": 100, "sypd": 1.0},
                                 "bench_2": {"tasks": 200, "sypd": 1.5}})

    # Case, Total Resources, Tasks, Threads, Sypd, SpeedUp, Efficiency
    assert rows["bench_2"][1:4] == ["200", "200", "1"]
    assert rows["bench_2"][5] == "1.5"
    assert rows["bench_2"][6] == "0.75"


def test_a_duration_metric_gets_its_speedup_inverted():
    rows = summary_rows("time", {"bench_1": {"tasks": 100, "time": 100.0},
                                 "bench_2": {"tasks": 200, "time": 75.0}})

    assert rows["bench_2"][5] == "1.3"
    assert rows["bench_2"][6] == "0.67"


def test_a_case_without_a_value_is_left_out(capsys):
    rows = summary_rows("sypd", {"bench_1": {"tasks": 100, "sypd": 1.0},
                                 "bench_2": {"tasks": 200}})

    assert list(rows) == ["bench_1"]
    assert "bench_2 has no sypd value" in capsys.readouterr().out


def test_the_ideal_line_extrapolates_the_base_case():
    assert ideal_value(2.0, 100, 400, "sypd") == pytest.approx(8.0)
    assert ideal_value(10.0, 100, 400, "time") == pytest.approx(2.5)
