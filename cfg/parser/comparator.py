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
    experiment_data = [TimingInformation(json_file=f) for f in files]
    experiment_comparison(experiment_data[0], experiment_data[1]).print()
