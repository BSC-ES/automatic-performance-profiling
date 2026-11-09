import pytest

from src.mapping import expand_files, load_mapping


def test_yaml_mapping_nested_by_case(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "test: BENCH\n"
        "parameters: param.cfg\n"
        "cases:\n"
        "  bench_1:\n"
        "    inputs:\n"
        "      - format: test_info\n"
        "        files: bench_1-test_info.csv\n"
        "    components:\n"
        "      nemo:\n"
        "        files: run_bench_1/nemo-bench_1-timing.output\n"
        "      oifs:\n"
        "        format: ifs-stat\n"
        "        files: [run_bench_1/oifs-bench_1-ifs.stat]\n"
    )

    mapping = load_mapping(str(mapping_file))

    assert mapping.test == "BENCH"
    assert mapping.parameters == "param.cfg"
    assert mapping.components == ["nemo", "oifs"]
    (case,) = mapping.cases
    assert case.name == "bench_1"
    assert [i.input.files for i in case.test_info] == [("bench_1-test_info.csv",)]
    assert [(i.component, i.input.format) for i in case.inputs] == [
        (None, "test_info"),
        ("nemo", "nemo-timing"),
        ("oifs", "ifs-stat"),
    ]


def test_flat_inputs_list_used_by_the_template(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "test: TRACING\n"
        "cases:\n"
        "  bench_1:\n"
        "    inputs:\n"
        "      - format: test_info\n"
        "        files: [run_bench_1/*test_info.csv, run_bench_1/*test_info.yaml]\n"
        "      - component: nemo\n"
        "        format: nemo-timing\n"
        "        files: run_bench_1/nemo-bench_1-timing.output\n"
        "      - component: nemo\n"
        "        format: paramedir\n"
        "        counter: Time\n"
        "        files: run_bench_1/paramedir/nemo-bench_1-Time.pm\n"
        "      - format: lucia\n"
        "        files: run_bench_1/lucia_lite_results/table.csv\n"
    )

    (case,) = load_mapping(str(mapping_file)).cases

    assert [i.input.files for i in case.test_info] == [
        ("run_bench_1/*test_info.csv", "run_bench_1/*test_info.yaml"),
    ]
    assert [(i.component, i.input.format) for i in case.inputs] == [
        (None, "test_info"),
        ("nemo", "nemo-timing"),
        ("nemo", "paramedir"),
        (None, "lucia"),
    ]
    assert case.inputs[2].input.counter == "Time"


def test_case_keys_other_than_inputs_are_case_data(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "cases:\n"
        "  bench_1:\n"
        "    tasks: 112\n"
        "    threads: 4\n"
        "    resolution: Tco95\n"
        "    inputs:\n"
        "      - component: nemo\n"
        "        format: nemo-timing\n"
        "        files: run_bench_1/nemo-bench_1-timing.output\n"
    )

    (case,) = load_mapping(str(mapping_file)).cases

    assert case.data == {"tasks": 112, "threads": 4, "resolution": "Tco95"}
    assert case.test_info == ()


def test_inline_spec_adds_a_case():
    mapping = load_mapping(
        specs=["case=bench_2,component=nemo,format=nemo-timing,files=a:1;b:2"])

    (case,) = mapping.cases
    assert case.name == "bench_2"
    (case_input,) = case.inputs
    assert case_input.component == "nemo"
    assert case_input.input.files == ("a:1", "b:2")


def test_case_level_input_has_no_component(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "cases:\n"
        "  bench_1:\n"
        "    case_inputs:\n"
        "      - format: lucia\n"
        "        files: lucia/table.csv\n"
    )

    (case,) = load_mapping(str(mapping_file)).cases
    assert case.inputs[0].component is None
    assert mapping_components(case) == []


def mapping_components(case):
    return [case_input.component for case_input in case.inputs if case_input.component]


def test_unknown_format_is_rejected(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "cases:\n"
        "  bench_1:\n"
        "    components:\n"
        "      nemo: {format: nope, files: a}\n"
    )

    with pytest.raises(ValueError, match="unknown format"):
        load_mapping(str(mapping_file))


def test_component_without_default_format_needs_one(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "cases:\n"
        "  bench_1:\n"
        "    components:\n"
        "      pangea: {files: a}\n"
    )

    with pytest.raises(ValueError, match="needs an explicit 'format'"):
        load_mapping(str(mapping_file))


def test_paramedir_needs_a_counter(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "cases:\n"
        "  bench_1:\n"
        "    components:\n"
        "      nemo: {format: paramedir, files: a.pm}\n"
    )

    with pytest.raises(ValueError, match="needs a 'counter'"):
        load_mapping(str(mapping_file))


def test_dimemas_needs_a_simulation_and_a_counter(tmp_path):
    mapping_file = tmp_path / "inputs.yml"
    mapping_file.write_text(
        "cases:\n"
        "  trace_1:\n"
        "    components:\n"
        "      icon: {format: dimemas, files: a.dm, simulation: Original}\n"
    )

    with pytest.raises(ValueError, match="dimemas needs 'simulation' and 'counter'"):
        load_mapping(str(mapping_file))


def test_empty_mapping_is_rejected():
    with pytest.raises(ValueError, match="no case"):
        load_mapping(specs=[])


def test_expand_files_keeps_matches_and_warns(tmp_path, capsys):
    (tmp_path / "a.pm").write_text("")
    (tmp_path / "b.pm").write_text("")

    files = expand_files([str(tmp_path / "*.pm"), str(tmp_path / "*.dm")])

    assert [f.rsplit("/", 1)[-1] for f in files] == ["a.pm", "b.pm"]
    assert "no file matches" in capsys.readouterr().err
