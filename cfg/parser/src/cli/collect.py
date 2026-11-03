"""Collect the raw outputs of one test into ``<output>.json``."""

import argparse
import sys
from dataclasses import replace
from os.path import abspath

from ..mapping import expand_files, load_mapping
from ..registry import CASE_FORMATS, COMPONENT_FORMATS
from ..timing import TimingInformation


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Parse the raw outputs of one test into <output-file>.json")
    parser.add_argument(
        "-m", "--mapping",
        help="YAML file declaring which file belongs to which case and component")
    parser.add_argument(
        "--input", action="append", default=[], metavar="KEY=VALUE,...",
        help="Inline mapping entry with case=, component=, format= and files= "
             "(semicolon separated); repeatable")
    parser.add_argument(
        "-o", "--output-file", required=True,
        help="Name of the output .json file")
    parser.add_argument(
        "-p", "--param-file",
        help="Parameter file with processes_per_node and configuration_name")
    parser.add_argument(
        "-c", "--components", nargs="+",
        help="Components of the report; defaults to the components of the mapping")
    parser.add_argument(
        "--test", help="Test name; defaults to the output file name")
    parser.add_argument(
        "--splits", type=int, default=None,
        help="Repetitions declared by the test; warns when a component matches fewer files")
    parser.add_argument(
        "-i", "--input-files", nargs="+", help=argparse.SUPPRESS)
    return parser


def run(args) -> int:
    mapping = load_mapping(args.mapping, args.input, test=args.test,
                           parameters=args.param_file)
    experiment = TimingInformation(
        experiment_name=mapping.test or args.output_file,
        param_file=mapping.parameters,
        components=args.components or mapping.components,
    )

    for case in mapping.cases:
        for pattern in case.test_info:
            for filename in expand_files([pattern], warn=False):
                experiment.load_case_test_info(case.name, filename)

    # Component data is applied before case-level data so that a per-component value (e.g. the
    # NEMO SYPD of the timing file) is not replaced by the aggregate one (e.g. the LUCIA row),
    # whatever the order of the mapping
    for case in mapping.cases:
        for case_input in case.inputs:
            if case_input.component is None:
                continue
            files = _expand_files(case.name, case_input)
            if not files:
                continue
            if args.splits and len(files) < args.splits:
                print(f"[WARNING] {case.name}/{case_input.component}: {len(files)} of "
                      f"{args.splits} splits found, the mean is over {len(files)}",
                      file=sys.stderr)
            entry = replace(case_input.input, files=tuple(files))
            payload = COMPONENT_FORMATS[entry.format](
                entry, case.name, case_input.component)
            experiment.add_component(
                case.name, case_input.component, payload, tasks=entry.tasks)

    for case in mapping.cases:
        for case_input in case.inputs:
            if case_input.component is not None:
                continue
            files = _expand_files(case.name, case_input)
            if not files:
                continue
            entry = replace(case_input.input, files=tuple(files))
            experiment.add_case(CASE_FORMATS[entry.format](
                entry, case.name, case_input.component))

    experiment.finalize()
    experiment.save_json(args.output_file)
    print("json file saved in ", abspath(args.output_file + ".json"))
    return 0


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.input_files:
        parser.error(
            "-i/--input-files was removed: declare the files in --mapping or --input")
    return run(args)


def _expand_files(case: str, case_input) -> list:
    """Expand the files of one mapping entry, warning once when none of them matches.

    An entry declares the run directory and the per-split folder of the same file, so a
    pattern without matches is normal and only the entry as a whole is reported.
    """
    files = expand_files(case_input.input.files, warn=False)
    if not files:
        label = case if case_input.component is None else f"{case}/{case_input.component}"
        print(f"[WARNING] {label}: no file matches "
              f"{', '.join(case_input.input.files)}", file=sys.stderr)
    return files
