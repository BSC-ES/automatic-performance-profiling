from cfg.parser.utils.parsers import TimingInformation
from os.path import isfile


def expand_arguments(arguments):
    import glob
    # Using the glob library to make it possible to use wildcards
    expanded_arguments = []
    for arg in arguments:
        if arg.count("*"):
            for new_argument in glob.glob(arg):
                expanded_arguments.append(new_argument)
        else:
            expanded_arguments.append(arg)
    return expanded_arguments


def get_file_list_from_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    from optparse import OptionParser
    # Parse and assert command line options
    parser = OptionParser()
    parser.add_option("-n", "--name", dest="experiment_name",
                      help="Experiment name", default="Experiment")
    parser.add_option("-p", "--param-file", dest="param_file",
                      help="Parameter file to supply some infos", default=None)
    (options, args) = parser.parse_args()

    files = expand_arguments(args)

    # In case of not having any argument print help and exit
    if not files:
        parser.print_help()
        exit(0)
    return files, options


if __name__ == "__main__":
    # Get files from command line
    files, options = get_file_list_from_command_line_arguments()
    experiment_name = options.experiment_name
    param_file = options.param_file
    if param_file is not None:
        try:
            assert isfile(param_file)
        except AssertionError:
            raise AssertionError("parameter file %s not found", param_file)

    # Split the files between timing and paramedir  outputs.

    timing_files = [f for f in files if f.count(".timing")]
    paramedir_files = [f for f in files if f.count(".pm")]

    # Parse files and create a TimingInformation object
    experiment_results = TimingInformation(
        experiment_name=experiment_name,
        timing_files=timing_files,
        paramedir_files=paramedir_files,
        param_file=param_file
    )
    # Save json file
    experiment_results.save_json()
