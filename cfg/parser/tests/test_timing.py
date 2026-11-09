"""The collected JSON is the only input of the reporter and the comparator."""

from src.timing import TimingInformation


def test_the_saved_json_loads_back_with_the_same_data(tmp_path):
    experiment = TimingInformation(experiment_name="BENCH", components=["nemo"])
    experiment.add_component("bench_1", "nemo", {"tasks": 112, "sypd": 9.5})
    experiment.finalize()

    experiment.save_json(str(tmp_path / "BENCH"))
    loaded = TimingInformation()
    loaded.load_json(str(tmp_path / "BENCH.json"))

    assert loaded.cases == ["bench_1"]
    assert loaded.components == ["nemo"]
    assert loaded.data["bench_1"]["sypd"] == 9.5
