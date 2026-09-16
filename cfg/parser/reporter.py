from cfg.parser.utils.parsers import TimingInformation


def get_command_line_instructions():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    # Using Argparse to enable command line selection of different runtime options
    from argparse import ArgumentParser
    from cfg.Error import PathType
    # Initializing parser
    parser = ArgumentParser()

    # Read command line options
    parser.add_argument("-j", "--json-file", required=True, type=PathType(exists=True, type="file"),
                        help="Mandatory: the json file to be parsed")
    parser.add_argument("-s", "--scalability-file", default=None,
                        help="Produce a scalability csv file with the specified name")

    parser.add_argument("-p", "--scalability-plot",  default=None,
                        help="Produce a scalability plot and save to the specified png file")
    parser.add_argument("-v", "--scalability-variable", default="sypd", required=False,
                        help="Variable name to be used in the scalability plot. Default is 'sypd'.")

    parser.add_argument("-f", "--csv-folder", default=None,
                        help="folder to save csv files with functions' info ")

    parser.add_argument("--functions-file", default=None,
                        help="Produce functions report")
    parser.add_argument("-m", "--most_expensive_function_summary", default=None,
                        help="Print a summary of the most expensive functions per core")
    parser.add_argument("--scatter-plots", default=None,
                        help="Produce a png with L3 cache misses vs IPC in it")
    parser.add_argument("--dimemas-file", default=None,
                        help="Produce dimemas report")
    parser.add_argument("--tracking-folder", default=None,
                        help="Produce tracking report")
    parser.add_argument("--coupling-folder", default=None,
                        help="Produce coupling report")
    parser.add_argument("--cases-component-data", default="nproc", nargs='+',
                        help="Produce a csv file with the cases and components data. Default is 'nproc'.")
    return parser.parse_args()


if __name__ == "__main__":
    # Get files from command line
    arguments = get_command_line_instructions()
    # Deal with the arguments provided
    json_file = arguments.json_file
    scalability_file = arguments.scalability_file
    scalability_plot_file = arguments.scalability_plot
    scalability_variable = arguments.scalability_variable
    csv_function_folder = arguments.csv_folder
    functions_file = arguments.functions_file
    most_expensive_function_summary = arguments.most_expensive_function_summary
    scatter_plots = arguments.scatter_plots
    dimemas_file = arguments.dimemas_file
    tracking_folder = arguments.tracking_folder
    coupling_folder = arguments.coupling_folder

    # Load the json file provided
    experiment_results = TimingInformation(json_file=json_file)

    # Depending on the options selected, do different kinds of diagnostics.
    if csv_function_folder is not None:
        experiment_results.function_info_csv(csv_folder=csv_function_folder)

    if scalability_file is not None:
        experiment_results.scalability_summary(scalability_file, scalability_variable)
    if scalability_plot_file is not None:
        experiment_results.scalability_plot(scalability_plot_file, scalability_variable)
    if functions_file is not None:
        experiment_results.function_summary(functions_file)
    if most_expensive_function_summary is not None:
        experiment_results.most_expensive_function_summary(
            out_file_name=most_expensive_function_summary)

    if scatter_plots:
        scatter_plots = scatter_plots.split(":")
        for scatter_plot in scatter_plots:
            x_axis, y_axis = scatter_plot.split("-")
            experiment_results.scatter_plots(
                x_axis=x_axis, y_axis=y_axis, length_summary=20)

    if dimemas_file is not None:
        experiment_results.dimemas_summary().save(dimemas_file)
    if tracking_folder is not None:
        experiment_results.tracking(tracking_folder)
    if coupling_folder is not None:
        experiment_results.coupling_info(coupling_folder)

    experiment_results.cases_component_data(arguments.cases_component_data)
