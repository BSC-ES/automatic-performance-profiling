"""Which raw file feeds which case, component and format.

The mapping replaces the old file-name classification: nothing here inspects a file
name to decide what it contains. A mapping is either a YAML document:

    test: BENCH
    parameters: param.cfg
    cases:
      bench_1:
        inputs:
          - format: test_info
            files: run_bench_1/bench_1-test_info.csv
          - component: nemo
            format: nemo-timing
            files: run_bench_1/nemo-bench_1-timing.output

Any other key under a case (``tasks``, ``threads``, ``resolution``…) is case data and
is stored in the JSON as it is, so a case needs no ``test_info`` file to report the
values the mapping already declares.

The mapping can also be given as ``--input`` specifications:

    --input case=bench_1,component=nemo,format=nemo-timing,files=run_bench_1/nemo-bench_1-timing.output
"""

from __future__ import annotations

import glob
import sys
from dataclasses import dataclass

import yaml

from .registry import ALL_FORMATS, MODEL_DEFAULT_FORMAT


@dataclass(frozen=True)
class Input:
    """One format read from a set of files.

    Attributes:
        format (str): Registered loader name.
        files (tuple): Paths or globs to read.
        tasks (int, optional): Number of MPI tasks, when the files do not report it.
        counter (str, optional): Counter category of ``paramedir`` and ``dimemas``.
        simulation (str, optional): Dimemas configuration name.
    """

    format: str
    files: tuple[str, ...]
    tasks: int | None = None
    counter: str | None = None
    simulation: str | None = None


@dataclass(frozen=True)
class CaseInput:
    """An :class:`Input` bound to the component it belongs to.

    Attributes:
        component (str, optional): Component name, or ``None`` for case-level data.
        input (Input): The files and their format.
    """

    component: str | None
    input: Input


@dataclass(frozen=True)
class Case:
    """A benchmark case, such as ``bench_1``.

    Attributes:
        name (str): Case identifier.
        data (dict): Values the mapping declares for the case itself, such as
            ``tasks`` or ``resolution``. They are stored in the JSON unchanged.
        inputs (tuple): Every file declared for the case, ``test_info`` included.
    """

    name: str
    data: dict
    inputs: tuple[CaseInput, ...]

    @property
    def test_info(self) -> tuple[CaseInput, ...]:
        """Return the ``test_info`` inputs of the case, in load order."""
        return tuple(case_input for case_input in self.inputs
                     if case_input.input.format == "test_info")


@dataclass(frozen=True)
class InputMapping:
    """Everything the collector needs to know about the files of one test.

    Attributes:
        test (str, optional): Test name, defaults to the output file name.
        parameters (str, optional): ``param.cfg`` of the test.
        cases (tuple): The cases and their files.
    """

    test: str | None
    parameters: str | None
    cases: tuple[Case, ...]

    @property
    def components(self) -> list[str]:
        """Return the components declared by the mapping, in declaration order."""
        components: list[str] = []
        for case in self.cases:
            for case_input in case.inputs:
                if case_input.component and case_input.component not in components:
                    components.append(case_input.component)
        return components


def load_mapping(path=None, specs=(), test=None, parameters=None) -> InputMapping:
    """Build an :class:`InputMapping` from a YAML file and/or ``--input`` specs.

    Args:
        path (str, optional): YAML mapping file.
        specs (Iterable[str], optional): ``key=value,...`` specifications.
        test (str, optional): Overrides the ``test`` of the file.
        parameters (str, optional): Overrides the ``parameters`` of the file.

    Returns:
        InputMapping: The merged mapping.

    Raises:
        ValueError: If the mapping declares no case or an unknown format.
    """
    document = {}
    if path:
        with open(path, "r", encoding="utf8") as mapping_f:
            document = yaml.safe_load(mapping_f) or {}

    cases = _parse_cases(document.get("cases") or {})
    for spec in specs:
        case_name, case_input = _parse_spec(spec)
        cases = _add_input(cases, case_name, case_input)

    if not cases:
        raise ValueError("the input mapping declares no case")

    return InputMapping(
        test=test or document.get("test"),
        parameters=parameters or document.get("parameters"),
        cases=tuple(cases.values()),
    )


def expand_files(patterns, warn: bool = True) -> list[str]:
    """Expand the globs of an input, warning about the ones that match nothing.

    Args:
        patterns (Iterable[str]): Paths or globs.
        warn (bool): Warn about a pattern without matches. Optional files, such as
            the ``test_info`` of a case, are expanded with ``warn=False``.
    """
    files: list[str] = []
    for pattern in patterns:
        matches = sorted(glob.glob(pattern))
        if not matches and warn:
            print(f"[WARNING] no file matches {pattern}", file=sys.stderr)
        files.extend(matches)
    return files


# Keys of a case that declare files; every other key is case data
_CASE_FILE_KEYS = ("inputs", "case_inputs", "components", "test_info")


def _parse_cases(document: dict) -> dict[str, Case]:
    cases = {}
    for name, body in document.items():
        body = body or {}
        inputs = []
        for entry in _as_list(body.get("case_inputs")):
            inputs.append(CaseInput(None, _parse_input(str(name), None, entry)))
        for entry in _as_list(body.get("inputs")):
            entry = dict(entry or {})
            component = entry.pop("component", None) or None
            inputs.append(CaseInput(component, _parse_input(str(name), component, entry)))
        for component, entries in (body.get("components") or {}).items():
            for entry in _as_list(entries):
                inputs.append(CaseInput(component, _parse_input(str(name), component, entry)))
        # ``test_info`` as a bare key is the older spelling of the format; keep it working
        for pattern in _as_tuple(body.get("test_info")):
            entry = {"format": "test_info", "files": pattern}
            inputs.append(CaseInput(None, _parse_input(str(name), None, entry)))
        data = {key: value for key, value in body.items() if key not in _CASE_FILE_KEYS}
        cases[str(name)] = Case(str(name), data, tuple(inputs))
    return cases


def _parse_input(case: str, component: str | None, entry) -> Input:
    entry = dict(entry or {})
    file_format = entry.get("format") or MODEL_DEFAULT_FORMAT.get(component or "")
    if not file_format:
        raise ValueError(
            f"{case}: component {component!r} needs an explicit 'format' "
            f"(known formats: {', '.join(sorted(ALL_FORMATS))})"
        )
    if file_format not in ALL_FORMATS:
        raise ValueError(
            f"{case}: unknown format {file_format!r} "
            f"(known formats: {', '.join(sorted(ALL_FORMATS))})"
        )
    if "files" not in entry:
        raise ValueError(f"{case}/{component}: entry {file_format} declares no 'files'")
    if file_format == "paramedir" and not entry.get("counter"):
        raise ValueError(f"{case}/{component}: paramedir needs a 'counter' (e.g. Time)")
    if file_format == "dimemas" and not (entry.get("simulation") and entry.get("counter")):
        raise ValueError(f"{case}/{component}: dimemas needs 'simulation' and 'counter'")

    files = entry["files"]
    if isinstance(files, str):
        files = [files]

    return Input(
        format=file_format,
        files=tuple(files),
        tasks=entry.get("tasks"),
        counter=entry.get("counter"),
        simulation=entry.get("simulation"),
    )


def _parse_spec(spec: str) -> tuple[str, CaseInput]:
    fields = {}
    for part in spec.split(","):
        key, separator, value = part.partition("=")
        if not key or not separator:
            raise ValueError(f"--input needs key=value pairs, got {part!r} in {spec!r}")
        fields[key.strip()] = value.strip()

    case = fields.pop("case", None)
    if not case:
        raise ValueError(f"--input needs a 'case', got {spec!r}")
    component = fields.pop("component", None) or None
    if "files" in fields:
        fields["files"] = [f for f in fields["files"].split(";") if f]
    return case, CaseInput(component, _parse_input(case, component, fields))


def _add_input(cases: dict[str, Case], name: str, case_input: CaseInput) -> dict[str, Case]:
    previous = cases.get(name) or Case(name, {}, ())
    cases[name] = Case(previous.name, previous.data, previous.inputs + (case_input,))
    return cases


def _as_tuple(value) -> tuple[str, ...]:
    if not value:
        return ()
    if isinstance(value, str):
        return (value,)
    return tuple(value)


def _as_list(value) -> list:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]
