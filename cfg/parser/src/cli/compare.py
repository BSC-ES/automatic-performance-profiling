"""Compare the results of several tests of the same member."""

import argparse
import os

from .types import existing_file
from ..curation import (
    multiexperiment_comparison,
    multiexperiment_scalability_plot,
    weakscaling_compute,
)
from ..timing import TimingInformation


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compare the results of several tests of the same member")
    parser.add_argument(
        "-j", "--json-files", nargs="*", type=existing_file,
        help="list of json files to compare")
    parser.add_argument(
        "-w", "--weak-scaling", default=False, action="store_true",
        help="Whether you want to compute weak scaling ")
    parser.add_argument(
        "-s", "--strong-scaling", default=False, action="store_true",
        help="Whether you want to compute strong scaling ")
    parser.add_argument(
        "--scalability-variable", default="sypd",
        help="Variable to use for scalability comparison. Default is sypd (seconds per year of simulation). Other options are: ts_per_second and sypd")
    parser.add_argument(
        "-f", "--function-info", default=False, action="store_true",
        help="Whether you want to compare elapsed time by function ")
    parser.add_argument(
        "--out-dir", default=None,
        help="Folder where the results will be saved. The computed quantity will be added to the name")
    parser.add_argument(
        "--file-out", default=None,
        help="Exact path of the weak scaling csv; overrides --out-dir")
    return parser


def run(args) -> int:
    experiment_data = []
    for json_file in args.json_files:
        experiment = TimingInformation()
        experiment.load_json(json_file)
        experiment_data.append(experiment)

    comparator_id = ""
    for experiment in experiment_data:
        comparator_id += experiment.experiment_name + "-"

    out_dir = args.out_dir or "."

    if args.strong_scaling:
        multiexperiment_comparison(
            experiment_data, scalability_variable=args.scalability_variable
        ).print(os.path.join(out_dir, comparator_id + "scaling.csv"))

        scalability_plot_fn = os.path.join(out_dir, comparator_id + "scaling.png")
        multiexperiment_scalability_plot(
            experiment_data,
            filename=scalability_plot_fn,
            scalability_variable=args.scalability_variable,
        )

    if args.weak_scaling:
        weakscaling_compute(
            experiment_data,
            args.file_out or os.path.join(out_dir, comparator_id + "scaling.csv"),
        )
    return 0


def main(argv=None) -> int:
    return run(build_parser().parse_args(argv))
