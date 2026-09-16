from cfg.parser.utils.parsers import TimingInformation
from cfg.latex.ReportGenerator import get_files_from_path
from os.path import isfile, abspath


def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    import argparse
    # Parse and assert command line options
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input-files", required=True, nargs='+',
                        help="list of files to parse")
    parser.add_argument("-o", "--output-file", default=None,
                        help="name of the output .json file")
    parser.add_argument("-p", "--param-file", default=None,
                        help="Parameter file to supply some info")
    parser.add_argument("-c", "--components", default=[],
                        help="Components to report")
    return parser.parse_args()


if __name__ == "__main__":

    timing_files = []
    paramedir_files = []
    dimemas_files = []
    lucia_files = []
    ifs_files = []
    test_info_files = []
    test_info_yaml_files = []

    # Get arguments from command line
    args = get_command_line_arguments()

    for folder in args.input_files:
        files = get_files_from_path(folder)
        for f in files:
            if f.count("timing.output"):
                timing_files.append(f)
            elif f.count(".pm"):
                paramedir_files.append(f)
            elif f.count(".dm"):
                dimemas_files.append(f)
            elif f.count("table.csv"):
                lucia_files.append(f)
            elif f.count("test_info.csv"):
                test_info_files.append(f)
            elif f.count("test_info.yaml"):
                test_info_yaml_files.append(f)
            elif f.count("ifs.stat"):
                ifs_files.append(f)
            else:
                continue

    output_file = args.output_file
    param_file = args.param_file
    components = args.components.split()
    if param_file is not None:
        try:
            assert isfile(param_file)
        except AssertionError:
            raise AssertionError("parameter file %s not found", param_file)

    # Parse files and create a TimingInformation object
    experiment_results = TimingInformation(
        timing_files=timing_files,
        paramedir_files=paramedir_files,
        dimemas_files=dimemas_files,
        param_file=param_file,
        lucia_files=lucia_files,
        components=components,
        ifs_files=ifs_files,
        test_info_files=test_info_files,
        test_info_yaml_files=test_info_yaml_files
    )
    # Save json file
    experiment_results.save_json(output_file)
    print("json file saved in ", abspath(output_file + ".json"))
