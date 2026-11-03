import pytest

from src.formats import dimemas, lucia, paramedir, test_info
from src.mapping import Input
from src.models import icon, ifs, nemo
from conftest import FIXTURES


def test_nemo4_timing_from_a_real_run():
    payload = nemo.parse_nemo_timing(str(FIXTURES / "nemo-4.0-bench_1-timing.output"))

    assert payload["tasks"] == 112
    assert payload["number_ts"] == 240
    assert payload["sypd"] == pytest.approx(9.572)
    assert payload["ts_per_second"] == pytest.approx(1 / 1.0309792641938351)
    assert len(payload["total_sim_functions_time"]) == 79
    assert payload["total_sim_functions_time"]["trc_ldf"] == pytest.approx(19.35)


def test_nemo5_timing_sample():
    payload = nemo.parse_nemo_timing(
        str(FIXTURES / "nemo-5.0" / "nemo-5.0-bench_1-timing.output"))

    assert payload["number_ts"] == 100.0
    assert payload["total_sim_time"] == 3600.0
    assert payload["ts_per_second"] == pytest.approx(1 / 0.0009)
    assert payload["total_sim_functions_time"] == {"sbc_abl": 12.5}
    assert payload["sypd"] == pytest.approx(900 * 100 / (365 * 3600))


def test_ifs_stat_from_a_real_run():
    payload = ifs.parse_ifs_file(str(FIXTURES / "oifs-48r1-bench_1-ifs.stat"))

    assert payload["ts_per_second"] == pytest.approx(1.3323541666666663)


def test_icon_timer_report_reads_the_real_total_row():
    payload = icon.parse_icon_timer_report(
        str(FIXTURES / "icon-2024.10-bench_1-timer.log"))

    assert payload["time"] == pytest.approx(54.012)
    assert payload["tasks"] == 891
    assert "splits" not in payload


def test_icon_timing_reads_the_elapsed_time():
    payload = icon.parse_icon_timing(
        str(FIXTURES / "icon-2024.10-bench_1-timing.output"))

    assert payload["time"] == pytest.approx(20.94)


def test_icon_timer_reports_of_every_split_are_averaged():
    timer_log = str(FIXTURES / "icon-2024.10-bench_1-timer.log")
    entry = Input(format="icon-timer-report", files=(timer_log, timer_log))

    payload = icon.load_timer_report(entry, "bench_1", "icon")

    assert payload["time"] == pytest.approx(54.012)
    assert payload["tasks"] == 891
    assert payload["splits"] == [{"time": pytest.approx(54.012)}] * 2


def test_nemo_test_info_csv():
    case_data = test_info.load_csv(
        str(FIXTURES / "nemo-4.0-bench_1-test_info.csv"), "bench_1")["bench_1"]

    assert case_data["tasks"] == 112
    assert case_data["components"]["nemo"] == {"tasks": 112, "resolution": "orca1"}


def test_ecearth4_test_info_csv_has_both_components():
    case_data = test_info.load_csv(
        str(FIXTURES / "ecearth4-nemo4.0-oifs48r1-bench_1-test_info.csv"), "bench_1")["bench_1"]

    assert case_data["tasks"] == 28
    assert case_data["resolution"] == "TL255L91+eORCA1L75"
    assert case_data["components"]["oifs"]["tasks"] == 84
    assert case_data["components"]["nemo"]["tasks"] == 26


def test_icon_test_info_yaml():
    payload = test_info.load_yaml(
        str(FIXTURES / "icon-2024.10-bench_1-test_info.yaml"))

    assert payload == {"bench_1": {"tasks": 896, "components": {"icon": {"tasks": 896}}}}


def test_paramedir_returns_component_counters():
    entry = Input(format="paramedir",
                  files=(str(FIXTURES / "extrae-4.3.3-Time.pm"),), counter="Time")

    counters = paramedir.load(entry, "bench_1", "icon")["counters"]["Time"]

    assert len(counters) == 12
    convection = counters["nwp_convection"]
    assert convection["Total"] == pytest.approx([1630.06])
    assert convection["Average"] == pytest.approx([14.69])
    assert convection["Maximum"] == pytest.approx([31.82])


def test_paramedir_without_counter_is_rejected():
    entry = Input(format="paramedir", files=("x.pm",))

    with pytest.raises(ValueError, match="needs a 'counter'"):
        paramedir.load(entry, "bench_1", "nemo")


def test_lucia_renames_the_coupling_components():
    entry = Input("lucia", (str(FIXTURES / "ecearth4-lucia-lite-v2-table.csv"),))

    payload = lucia.load(entry, "bench_1", None)["bench_1"]

    assert sorted(payload["components"]) == ["RNFMAP", "nemo", "oifs"]
    assert payload["SYPD"] == pytest.approx(4.074)
    assert payload["cpl_cost"] == pytest.approx(15.348)
    assert payload["components"]["nemo"]["sypd"] == pytest.approx(10.593)


def test_dimemas_reads_the_simulated_wallclock():
    entry = Input("dimemas",
                  (str(FIXTURES / "dimemas-5.4.2-Original-Wallclock.dm"),),
                  simulation="Original", counter="Wallclock")

    payload = dimemas.load(entry, "trace_1_icon", "icon")

    maximum = payload["trace_1_icon"]["Dimemas"]["Original"]["Wallclock"]["data"]["Maximum"]
    assert maximum[0] == pytest.approx(10_000_000.0)
