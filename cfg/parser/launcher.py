from cfg.parser.utils.parsers import TimingInformation
from cfg.parser.utils.curation import experiment_comparison, fit_step_time_to_model, fit_functions_to_model


def get_file_list_from_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    from optparse import OptionParser
    import glob
    # Parse and assert command line options
    parser = OptionParser()
    parser.add_option("-n", "--name", dest="experiment_name",
                      help="Experiment name", default="Experiment")
    parser.add_option("-f", "--csv_folder", dest="csv_function_folder",
                      help="folder to save csv files with functions' info ", default=None)
    parser.add_option("-s", "--save", dest="save_experiment",
                      help="Save a json file with the experiment data.", default=True, action="store_false")
    (options, args) = parser.parse_args()

    # Using the glob library to make it possible to use wildcards
    expanded_arguments = []
    for arg in args:
        if arg.count("*"):
            for new_argument in glob.glob(arg):
                expanded_arguments.append(new_argument)
        else:
            expanded_arguments.append(arg)
    files = expanded_arguments

    # In case of not having any argument print help and exit
    if not files:
        parser.print_help()
        exit(0)
    return files, options


if __name__ == "__main__":
    # Get files from command line
    files, options = get_file_list_from_command_line_arguments()
    experiment_name = options.experiment_name
    save_experiment = options.save_experiment
    csv_function_folder = options.csv_function_folder
    # Process the info of the experiments provided
    timing_files = [f for f in files if f.count(".timing")]
    paramedir_files = [f for f in files if f.count(".pm")]
    experiment_results = TimingInformation(experiment_name=experiment_name,
                                           timing_files=timing_files,
                                           paramedir_files=paramedir_files,
                                           )
    if csv_function_folder is not None:
        experiment_results.function_info_csv(csv_folder=csv_function_folder)


    if save_experiment:
        experiment_results.save_json()
