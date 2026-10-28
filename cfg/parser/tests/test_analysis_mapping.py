import subprocess
from pathlib import Path

from src.mapping import load_mapping

TEMPLATE = Path(__file__).resolve().parents[3] / "autosubmit/templates/analysis.sh"


def write_mapping(tmp_path, names: list, specs: list) -> "object":
    """Run the template's ``write_input_mapping`` with stub values and parse the result."""
    function = subprocess.run(
        ["sed", "-n", "/^function write_input_mapping/,/^}/p", str(TEMPLATE)],
        check=True, capture_output=True, text=True).stdout
    assert function, f"write_input_mapping not found in {TEMPLATE}"

    script = "\n".join([
        "names=(" + " ".join(f'"{name}"' for name in names) + ")",
        "component_specs=(" + " ".join(f'"{spec}"' for spec in specs) + ")",
        'case_level_specs=("")',
        'test_info_patterns="*test_info.csv *test_info.yaml"',
        function,
        "write_input_mapping BENCH",
    ])
    output = subprocess.run(["bash", "-c", script], check=True,
                            capture_output=True, text=True).stdout
    (tmp_path / "inputs.yml").write_text(output)
    return load_mapping(tmp_path / "inputs.yml")


def test_the_mapping_declares_the_run_and_split_layouts(tmp_path):
    mapping = write_mapping(tmp_path, ["bench_1"],
                            ["icon|icon-timer-report|icon_timer.log"])

    assert mapping.cases[0].test_info == ("run_bench_1/*test_info.csv",
                                          "run_bench_1/*test_info.yaml")
    entry = mapping.cases[0].inputs[0]
    assert entry.input.format == "icon-timer-report"
    assert entry.input.files == ("run_bench_1/icon_timer.log",
                                 "run_bench_1/*/icon_timer.log")


def test_a_case_placeholder_is_resolved_per_case_and_declared_once(tmp_path):
    mapping = write_mapping(tmp_path, ["trace_1", "trace_2"],
                            ["icon|paramedir|../paramedir/icon-@CASE@-Time.pm|Time"])

    files = {case.name: case.inputs[0].input.files for case in mapping.cases}
    assert files["trace_1"] == ("run_trace_1/../paramedir/icon-trace_1-Time.pm",)
    assert files["trace_2"] == ("run_trace_2/../paramedir/icon-trace_2-Time.pm",)
    assert mapping.cases[0].inputs[0].input.counter == "Time"
