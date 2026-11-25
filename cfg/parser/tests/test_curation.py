"""The traced user functions are reported as one row per function and case."""

import csv

from src.curation import (
    function_counter_plot,
    function_mpi_share_plot,
    generate_most_expensive_function_summary_data,
    multiexperiment_comparison,
    tracking_counter_scalability,
    tracking_mpi_scalability,
)


class FakeExperiment:
    """Minimal experiment data, with the fields the summary reads."""

    def __init__(self, data, components=("nemo",), name="build"):
        self.data = data
        self.components = list(components)
        self.cases = list(data)
        self.experiment_name = name

    def __getitem__(self, item):
        return self.data[item]


def test_the_comparison_header_keeps_one_column_per_build():
    # The header is a row of the csv, so a comma inside a column name would split it in
    # two and leave the table with more columns than values
    experiments = [
        FakeExperiment(
            {"case_1": {"total_resources": "112", "sypd": 1.0}}, name="go"
        ),
        FakeExperiment(
            {"case_1": {"total_resources": "112", "sypd": 1.2}}, name="march"
        ),
    ]

    rows = [
        [cell.strip() for cell in row]
        for row in csv.reader(multiexperiment_comparison(experiments).text.splitlines())
    ]

    assert rows[0] == [
        "Resources",
        "go SYPD (simulated years per day)",
        "march SYPD (simulated years per day) (diff vs go in %)",
    ]
    assert len(rows[1]) == len(rows[0])


def test_a_function_missing_from_a_case_is_dashed(tmp_path):
    experiment = FakeExperiment(
        {
            "case_a": {
                "components": {
                    "nemo": {
                        "fastest_ts_time": "10.0",
                        "fastest_ts_functions_time": {"dyn": 5.0, "io": 2.0},
                    }
                }
            },
            "case_b": {
                "components": {
                    "nemo": {
                        "fastest_ts_time": "10.0",
                        "fastest_ts_functions_time": {"io": 4.0},
                    }
                }
            },
        }
    )
    out_file = tmp_path / "summary.csv"

    generate_most_expensive_function_summary_data(experiment, str(out_file))

    rows = list(csv.reader(out_file.open()))
    assert rows[0] == [
        "function_name",
        "case_a (%)",
        "case_b (%)",
    ]
    assert rows[1:] == [["dyn", "50.00", "-"], ["io", "20.00", "40.00"]]


def test_the_mpi_table_holds_one_row_per_function_and_case():
    experiment = FakeExperiment(
        {
            case: {
                "components": {
                    "nemo": {
                        "counters": {
                            "MPIcallprofile": {
                                "func_1": {
                                    "names": [
                                        "Outside_MPI", "MPI_Recv", "MPI_Waitall",
                                    ],
                                    "Average": average,
                                }
                            }
                        }
                    }
                }
            }
            for case, average in (
                ("trace_1", [78.08, 0.0, 15.38]),
                ("trace_2", [59.38, 0.0, 32.34]),
            )
        }
    )
    experiment.base_case = "trace_1"

    log = tracking_mpi_scalability(experiment, "nemo", ["func_1"])

    assert list(csv.reader(log.text.splitlines())) == [
        [
            "User function", "Case",
            "Outside_MPI (%)", "MPI_Waitall (%)",
        ],
        ["func_1", "trace_1", "78.08", "15.38"],
        ["", "trace_2", "59.38", "32.34"],
    ]


def test_the_counter_table_holds_one_row_per_function_and_case():
    experiment = FakeExperiment(
        {
            "trace_1": {
                "components": {
                    "nemo": {
                        "counters": {
                            "IPC": {"func_1": {"Average": [1.66]}},
                            "PAPI_TOT_CYC": {"func_1": {"Average": [269560112.24]}},
                        }
                    }
                }
            },
            "trace_2": {
                "components": {
                    "nemo": {
                        "counters": {"IPC": {"func_1": {"Average": [2.13]}}}
                    }
                }
            },
        }
    )
    experiment.base_case = "trace_1"

    log = tracking_counter_scalability(experiment, "nemo", ["func_1"])

    assert list(csv.reader(log.text.splitlines())) == [
        [
            "User function", "Case",
            "IPC", "TOT_CYC",
        ],
        ["func_1", "trace_1", "1.66", "2.696e+08"],
        ["", "trace_2", "2.13", ""],
    ]


def test_the_two_figures_are_written_for_each_component(tmp_path):
    experiment = FakeExperiment(
        {
            case: {
                "components": {
                    "nemo": {
                        "tasks": tasks,
                        "counters": {
                            "Time": {"func_1": {"Average": [10.0]}},
                            "MPIcallprofile": {
                                "func_1": {
                                    "names": ["Outside_MPI", "MPI_Waitall"],
                                    "Average": [78.08, 21.92],
                                }
                            },
                            "IPC": {"func_1": {"Average": [1.66]}},
                            "PAPI_L3_TCM": {"func_1": {"Average": [10.76]}},
                        },
                    }
                }
            }
            for case, tasks in (("trace_1", 112), ("trace_2", 224))
        }
    )
    experiment.base_case = "trace_1"

    function_mpi_share_plot(experiment, str(tmp_path / "mpi.png"))
    function_counter_plot(experiment, str(tmp_path / "counters.png"))

    expected = (
        "nemo_mpi.png",
        "nemo_counters_IPC.png",
        "nemo_counters_PAPI_L3_TCM.png",
    )
    for name in expected:
        assert (tmp_path / name).stat().st_size > 0
