from cfg.parser.utils.parsers import TimingInformation
from cfg.parser.utils.curation import experiment_comparison, multiexperiment_comparison, find_common_cases_and_functions
from cfg.parser.collector import expand_arguments


def get_file_list_from_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    from optparse import OptionParser

    # Parse and assert command line options
    parser = OptionParser()

    (options, args) = parser.parse_args()

    # Using the glob library to make it possible to use wildcards
    files = expand_arguments(args)

    # In case of not having any argument print help and exit
    if not files:
        parser.print_help()
        exit(0)
    return files, options


if __name__ == "__main__":
    # Get files from command line
    files, options = get_file_list_from_command_line_arguments()
    # Load the two experiments provided.
    experiment_data = [TimingInformation(json_file=f) for f in files]

    # Example how to get comparison of SYPD
    info_type = "Communication"
    var_type = "sypd"
    field3 = "average"
    multiexperiment_comparison(experiment_data, field1=info_type, field2=var_type, field3=field3).print()

    common_cases, common_functions = find_common_cases_and_functions(experiment_data)

    # Example on how to compare elapsed time by function
    info_type = "FunctionInfo"
    field = 'Elap. Time(s)'
    for function in common_functions:
        multiexperiment_comparison(experiment_data, field1=info_type, field2=function, field3=field).print()


