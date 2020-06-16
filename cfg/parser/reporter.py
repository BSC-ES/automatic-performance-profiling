from cfg.parser.utils.parsers import TimingInformation


def get_command_line_instructions():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    # Using optparse to enable command line selection of different runtime options
    from optparse import OptionParser

    # Initializing parser
    parser = OptionParser()

    # Adding options

    # Expanded description to make it easier for someone to add a new option
    parser.add_option(
        # Short cml option
        "-s",
        # Long cml option
        "--sypd",
        # Name of the property in which the value will be stored. i.e. options.sypd
        dest="sypd_file",
        # Help message for this specific option
        help="Produce a Simulation Years per Day report and save to the specified file ",
        # Default value
        default=None,
    )
    parser.add_option(
        # Short cml option
        "-p",
        # Long cml option
        "--sypd-plot",
        # Name of the property in which the value will be stored. i.e. options.sypd
        dest="sypd_plot_file",
        # Help message for this specific option
        help="Produce a Simulation Years per Day plot and save to the specified file ",
        # Default value
        default=None,
    )

    parser.add_option(
        "-f",
        "--csv_folder",
        dest="csv_function_folder",
        help="folder to save csv files with functions' info ",
        default=None,
    )

    parser.add_option(
        "--functions",
        dest="functions_file",
        help="Produce functions report",
        default=None,
    )

    # OptParser will parse the text provided as command line arguments and will distringuish between the options
    # and other arguments
    (options, args) = parser.parse_args()

    # Check that one argument is provided.
    if len(args) != 1:
        print(args)
        parser.print_help()
        print("A single json file is required as an argument.")
        exit(1)
    json_file = args[0]
    return json_file, options


if __name__ == "__main__":
    # Get files from command line
    json_file, options = get_command_line_instructions()
    # Deal with the options provided
    csv_function_folder = options.csv_function_folder
    sypd_file = options.sypd_file
    sypd_plot_file = options.sypd_plot_file
    functions_file = options.functions_file

    # Load the json file provided
    experiment_results = TimingInformation(
                                           json_file=json_file,
                                           )

    # Depending on the options selected, do different kinds of diagnostics.
    if csv_function_folder is not None:
        experiment_results.function_info_csv(csv_folder=csv_function_folder)

    if sypd_file is not None:
        experiment_results.simulated_years_per_day_summary().save(sypd_file)
    if sypd_plot_file:
        experiment_results.simulated_years_per_day_plot(sypd_plot_file)
    if functions_file is not None:
        experiment_results.function_summary().save(functions_file)

    # To create a new diagnostic/plot you need to create the function in curation.py and add the call inside parsers.py
