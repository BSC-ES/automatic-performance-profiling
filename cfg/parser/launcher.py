from cfg.parser.utils.parsers import TimingInformation


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
    return files


if __name__ == "__main__":
    # Get files from command line
    files = get_file_list_from_command_line_arguments()
    # Process the info of the experiments provided
    experiment_results = TimingInformation(files)
    # Prepare and print some summaries
    experiment_results.function_summary().print()
    experiment_results.simulated_years_per_day_summary().print()

