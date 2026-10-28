import pytest

from src.splits import aggregate


def test_a_single_payload_is_returned_as_is():
    payload = {"sypd": 9.5, "nproc": 112}

    assert aggregate([payload], "sypd") == payload


def test_the_metric_of_every_split_is_averaged_and_kept():
    payloads = [
        {"sypd": 4.0, "nproc": 112, "total_sim_functions_time": {"sbc": 2.0}},
        {"sypd": 6.0, "nproc": 112, "total_sim_functions_time": {"sbc": 4.0}},
    ]

    merged = aggregate(payloads, "sypd")

    assert merged["sypd"] == pytest.approx(5.0)
    assert merged["total_sim_functions_time"]["sbc"] == pytest.approx(3.0)
    assert merged["splits"] == [{"sypd": 4.0}, {"sypd": 6.0}]


def test_an_already_concatenated_payload_contributes_one_value_per_report():
    payloads = [
        {"time": 5.0, "splits": [{"time": 4.0}, {"time": 6.0}]},
        {"time": 8.0},
    ]

    merged = aggregate(payloads, "time")

    assert merged["time"] == pytest.approx(6.5)
    assert merged["splits"] == [{"time": 4.0}, {"time": 6.0}, {"time": 8.0}]


def test_the_number_of_processors_is_not_averaged(capsys):
    merged = aggregate([{"nproc": 112, "sypd": 1.0}, {"nproc": 224, "sypd": 2.0}], "sypd")

    assert merged["nproc"] == 112
    assert "different nproc" in capsys.readouterr().out
