"""Curate one ``<test>.json`` into the CSVs, plots and summaries the report uses."""

import argparse

from .types import existing_file
from ..timing import TimingInformation


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Produce the report resources of one test")
    parser.add_argument("-j", "--json-file", required=True, type=existing_file,
                        help="Mandatory: the json file to be parsed")
    parser.add_argument("-s", "--scalability-file", default=None,
                        help="Produce a scalability csv file with the specified name")
    parser.add_argument("-p", "--scalability-plot", default=None,
                        help="Produce a scalability plot and save to the specified png file")
    parser.add_argument("-v", "--scalability-variable", default="sypd", required=False,
                        help="Variable name to be used in the scalability plot. Default is 'sypd'.")
    parser.add_argument("-f", "--csv-folder", default=None,
                        help="folder to save csv files with functions' info ")
    parser.add_argument("--functions-file", default=None,
                        help="Produce functions report")
    parser.add_argument("-m", "--most_expensive_function_summary", default=None,
                        help="Print a summary of the most expensive functions per core")
    parser.add_argument("--function-time-share-plot", default=None,
                        help="Produce a stacked plot with the share of the timestep "
                             "spent in each user function")
    parser.add_argument("--mpi-profile-share-plot", default=None,
                        help="Produce a stacked plot with the share of the MPI call "
                             "time spent in each MPI call")
    parser.add_argument("--function-mpi-share-plot", default=None,
                        help="Produce a stacked plot with the MPI call profile of "
                             "each user function of each case")
    parser.add_argument("--function-counter-plot", default=None,
                        help="Produce a plot of the counters of each user function "
                             "along the cases, one png per counter")
    parser.add_argument("--function-counters", default=None, nargs="+",
                        help="Counter keys of the user function plots, e.g. IPC PAPI_L3_TCM. "
                             "Defaults to the IPC and the L3 misses")
    parser.add_argument("--scatter-plots", default=None,
                        help="Produce a png with L3 cache misses vs IPC in it")
    parser.add_argument("--dimemas-file", default=None,
                        help="Produce dimemas report")
    parser.add_argument("--tracking-folder", default=None,
                        help="Produce tracking report")
    parser.add_argument("--coupling-folder", default=None,
                        help="Produce coupling report")
    parser.add_argument("--cases-component-data", default="tasks", nargs="+",
                        help="Produce a csv file with the cases and components data. Default is 'tasks'.")
    return parser


def run(args) -> int:
    experiment_results = TimingInformation()
    experiment_results.load_json(args.json_file)

    if args.csv_folder is not None:
        experiment_results.function_info_csv(csv_folder=args.csv_folder)

    if args.scalability_file is not None:
        experiment_results.scalability_summary(
            args.scalability_file, args.scalability_variable)
    if args.scalability_plot is not None:
        experiment_results.scalability_plot(
            args.scalability_plot, args.scalability_variable)
    if args.functions_file is not None:
        experiment_results.function_summary(args.functions_file)
    if args.most_expensive_function_summary is not None:
        experiment_results.most_expensive_function_summary(
            out_file_name=args.most_expensive_function_summary)

    if args.function_time_share_plot is not None:
        experiment_results.function_time_share_plot(
            out_file_name=args.function_time_share_plot)

    if args.mpi_profile_share_plot is not None:
        experiment_results.mpi_profile_share_plot(
            out_file_name=args.mpi_profile_share_plot)

    if args.function_mpi_share_plot is not None:
        experiment_results.function_mpi_share_plot(
            out_file_name=args.function_mpi_share_plot)

    if args.function_counter_plot is not None:
        counters = tuple(args.function_counters or ("IPC", "PAPI_L3_TCM"))
        experiment_results.function_counter_plot(
            out_file_name=args.function_counter_plot, counters=counters)

    if args.scatter_plots:
        for scatter_plot in args.scatter_plots.split(":"):
            x_axis, y_axis = scatter_plot.split("-")
            experiment_results.scatter_plots(
                x_axis=x_axis, y_axis=y_axis, length_summary=20)

    if args.dimemas_file is not None:
        experiment_results.dimemas_summary().save(args.dimemas_file)
    if args.tracking_folder is not None:
        experiment_results.tracking(args.tracking_folder)
    if args.coupling_folder is not None:
        experiment_results.coupling_info(args.coupling_folder)

    experiment_results.cases_component_data(args.cases_component_data)
    return 0


def main(argv=None) -> int:
    return run(build_parser().parse_args(argv))
