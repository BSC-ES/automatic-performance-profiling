from cfg.parser.collector import expand_arguments
from cfg.parser.utils.curation import multiexperiment_comparison, \
    find_common_cases_and_functions, \
    weakscaling_compute
from cfg.parser.utils.parsers import TimingInformation


def get_file_list_from_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    from optparse import OptionParser

    # Parse and assert command line options
    parser = OptionParser()

    parser.add_option("-w", "--weak-scaling", dest="weak_scaling", default=False, action="store_true",
                      help="Whether you want to compute weak scaling ")
    parser.add_option("-s", "--sypd", dest="SYPD", default=False, action="store_true",
                      help="Whether you want to compare SYPD ")
    parser.add_option("-f", "--function-info", dest="function_info", default=False, action="store_true",
                      help="Whether you want to compare elapsed time by function ")
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
    weak_scaling = options.weak_scaling
    SYPD = options.SYPD
    function_info = options.function_info

    # Load the two experiments provided.
    experiment_data = [TimingInformation(json_file=f) for f in files]

    if SYPD:
        # Example how to get comparison of SYPD
        info_type = "Communication"
        var_type = "sypd"
        field3 = "average"
        multiexperiment_comparison(experiment_data, field1=info_type, field2=var_type, field3=field3).print()

    if function_info:
        # Example on how to compare elapsed time by function
        common_cases, common_functions = find_common_cases_and_functions(experiment_data)
        #
        info_type = "FunctionInfo"
        field = 'Elap. Time(s)'
        for function in common_functions:
            multiexperiment_comparison(experiment_data, field1=info_type, field2=function, field3=field).print()

    # Prints weak scaling info
    if weak_scaling:
        weakscaling_compute(experiment_data).print()
