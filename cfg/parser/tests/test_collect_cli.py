import json
import shutil

import pytest

from src.cli import collect
from conftest import FIXTURES


@pytest.fixture
def nemo_dir(tmp_path, monkeypatch):
    """A run directory with the real NEMO 4.0 timing, its test_info and a paramedir counter."""
    run_dir = tmp_path / "run_bench_1"
    (run_dir / "paramedir").mkdir(parents=True)
    shutil.copy(FIXTURES / "nemo-4.0-bench_1-timing.output",
                run_dir / "nemo-bench_1-timing.output")
    shutil.copy(FIXTURES / "nemo-4.0-bench_1-test_info.csv",
                run_dir / "bench_1-test_info.csv")
    shutil.copy(FIXTURES / "extrae-4.3.3-Time.pm",
                run_dir / "paramedir" / "nemo-bench_1-Time.pm")

    (tmp_path / "inputs.yml").write_text(
        "test: BENCH\n"
        "parameters: param.cfg\n"
        "cases:\n"
        "  bench_1:\n"
        "    inputs:\n"
        "      - format: test_info\n"
        "        files: [run_bench_1/*test_info.csv, run_bench_1/*test_info.yaml]\n"
        "      - component: nemo\n"
        "        format: nemo-timing\n"
        "        files: run_bench_1/*-timing.output\n"
        "      - component: nemo\n"
        "        format: paramedir\n"
        "        counter: Time\n"
        "        files: run_bench_1/paramedir/*-Time.pm\n"
    )
    (tmp_path / "param.cfg").write_text(
        "processes_per_node=112\nconfiguration_name=BENCH\n")
    monkeypatch.chdir(tmp_path)
    return tmp_path


@pytest.fixture
def nemo_split_dir(tmp_path, monkeypatch):
    """Two repetitions of the same NEMO case, one per split folder, as the runs write them."""
    run_dir = tmp_path / "run_bench_1"
    for split in (1, 2):
        (run_dir / str(split)).mkdir(parents=True)
        shutil.copy(FIXTURES / "nemo-4.0-bench_1-timing.output",
                    run_dir / str(split) / "timing.output")
    shutil.copy(FIXTURES / "nemo-4.0-bench_1-test_info.csv",
                run_dir / "bench_1-test_info.csv")

    (tmp_path / "inputs.yml").write_text(
        "test: BENCH\n"
        "parameters: param.cfg\n"
        "cases:\n"
        "  bench_1:\n"
        "    inputs:\n"
        "      - format: test_info\n"
        "        files: [run_bench_1/*test_info.csv, run_bench_1/*test_info.yaml]\n"
        "      - component: nemo\n"
        "        format: nemo-timing\n"
        "        files: [run_bench_1/timing.output, run_bench_1/*/timing.output]\n"
    )
    (tmp_path / "param.cfg").write_text(
        "processes_per_node=112\nconfiguration_name=BENCH\n")
    monkeypatch.chdir(tmp_path)
    return tmp_path


@pytest.fixture
def ecearth4_dir(tmp_path, monkeypatch):
    """The two components of EC-Earth 4 plus its LUCIA coupling table."""
    run_dir = tmp_path / "run_bench_1"
    (run_dir / "lucia_lite_results").mkdir(parents=True)
    shutil.copy(FIXTURES / "oifs-48r1-bench_1-ifs.stat", run_dir / "oifs-bench_1-ifs.stat")
    shutil.copy(FIXTURES / "nemo-4.0-bench_1-timing.output",
                run_dir / "nemo-bench_1-timing.output")
    shutil.copy(FIXTURES / "ecearth4-nemo4.0-oifs48r1-bench_1-test_info.csv",
                run_dir / "bench_1-test_info.csv")
    shutil.copy(FIXTURES / "ecearth4-lucia-lite-v2-table.csv",
                run_dir / "lucia_lite_results" / "table.csv")

    (tmp_path / "inputs.yml").write_text(
        "test: BENCH\n"
        "cases:\n"
        "  bench_1:\n"
        "    inputs:\n"
        "      - format: test_info\n"
        "        files: run_bench_1/*test_info.csv\n"
        "      - component: oifs\n"
        "        format: ifs-stat\n"
        "        files: run_bench_1/*-ifs.stat\n"
        "      - component: nemo\n"
        "        format: nemo-timing\n"
        "        files: run_bench_1/*-timing.output\n"
        "      - format: lucia\n"
        "        files: run_bench_1/lucia_lite_results/table.csv\n"
    )
    monkeypatch.chdir(tmp_path)
    return tmp_path


def test_collect_writes_the_expected_json(nemo_dir):
    assert collect.main(["--mapping", "inputs.yml", "-o", "BENCH"]) == 0

    with open(nemo_dir / "BENCH.json", encoding="utf8") as json_f:
        saved = json.load(json_f)

    assert saved["experiment_name"] == "BENCH"
    assert saved["cases"] == ["bench_1"]
    assert saved["components"] == ["nemo"]
    assert saved["processes_per_node"] == "112"
    assert len(saved["functions"]) == 12
    assert "nwp_convection" in saved["functions"]

    # a single component is flattened to the case, as the reports expect
    assert saved["data"]["bench_1"]["tasks"] == 112
    assert saved["data"]["bench_1"]["sypd"] == pytest.approx(9.572)
    assert saved["data"]["bench_1"]["number_ts"] == 240

    # trace-only sections stay under the component
    nemo_component = saved["data"]["bench_1"]["components"]["nemo"]
    assert nemo_component["fastest_ts_functions_time"]["nwp_convection"] == pytest.approx(0.01469)
    assert "counters" in nemo_component
    assert "counters" not in saved["data"]["bench_1"]


def test_collect_maps_two_components_and_the_coupling_table(ecearth4_dir):
    assert collect.main(["--mapping", "inputs.yml", "-o", "BENCH"]) == 0

    with open(ecearth4_dir / "BENCH.json", encoding="utf8") as json_f:
        saved = json.load(json_f)

    assert saved["components"] == ["oifs", "nemo"]
    case_data = saved["data"]["bench_1"]
    assert case_data["tasks"] == 28
    assert case_data["components"]["oifs"]["tasks"] == 84
    assert case_data["components"]["nemo"]["tasks"] == 26
    # the Coupled row of the LUCIA table becomes case-level values
    assert case_data["sypd"] == pytest.approx(4.074)
    assert case_data["cpl_cost"] == pytest.approx(15.348)
    # the component keeps the value of its own timing file (9.572), not the LUCIA row (10.593),
    # as the collector always applies the case-level data last
    assert case_data["components"]["nemo"]["sypd"] == pytest.approx(9.572)


def test_collect_rejects_the_removed_input_files_flag(nemo_dir):
    with pytest.raises(SystemExit):
        collect.main(["-i", "run_bench_1", "-o", "BENCH"])


def test_collect_takes_the_case_values_from_the_mapping(tmp_path, monkeypatch):
    """A case declares its values in the mapping, so it needs no test_info file."""
    run_dir = tmp_path / "run_bench_1"
    run_dir.mkdir()
    shutil.copy(FIXTURES / "nemo-4.0-bench_1-timing.output",
                run_dir / "nemo-bench_1-timing.output")

    (tmp_path / "inputs.yml").write_text(
        "test: BENCH\n"
        "cases:\n"
        "  bench_1:\n"
        "    tasks: 224\n"
        "    threads: 2\n"
        "    resolution: ORCA25\n"
        "    inputs:\n"
        "      - component: nemo\n"
        "        format: nemo-timing\n"
        "        files: run_bench_1/*-timing.output\n"
    )
    monkeypatch.chdir(tmp_path)

    assert collect.main(["--mapping", "inputs.yml", "-o", "BENCH"]) == 0

    with open(tmp_path / "BENCH.json", encoding="utf8") as json_f:
        saved = json.load(json_f)

    case_data = saved["data"]["bench_1"]
    assert case_data["tasks"] == 224
    assert case_data["threads"] == 2
    assert case_data["resolution"] == "ORCA25"
    assert case_data["total_resources"] == 448


def test_collect_warns_when_a_declared_split_is_missing(nemo_dir, capsys):
    assert collect.main(["--mapping", "inputs.yml", "-o", "BENCH", "--splits", "2"]) == 0

    assert "bench_1/nemo: 1 of 2 splits found" in capsys.readouterr().err


def test_collect_reads_one_file_per_split(nemo_split_dir):
    assert collect.main(["--mapping", "inputs.yml", "-o", "BENCH"]) == 0

    with open(nemo_split_dir / "BENCH.json", encoding="utf8") as json_f:
        saved = json.load(json_f)

    case_data = saved["data"]["bench_1"]
    assert case_data["tasks"] == 112
    assert case_data["sypd"] == pytest.approx(9.572)
    assert [split["sypd"] for split in case_data["splits"]] == pytest.approx([9.572, 9.572])
