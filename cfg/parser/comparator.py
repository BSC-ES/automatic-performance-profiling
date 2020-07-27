from cfg.parser.utils.curation import multiexperiment_comparison, \
    find_common_cases_and_functions, \
    weakscaling_compute
from cfg.parser.utils.parsers import TimingInformation
from glob import glob
from os.path import isfile, isdir, abspath, exists
from os import listdir


def get_files_from_path(file_path, extension=None):
    # A list was passed, return the list
    if len(file_path) > 1:
        return file_path
    # A path has been passed, need further parsing
    file_path = file_path[0]
    # If a wildcard has been passed as input
    if file_path.count("*"):
        return glob(file_path)

    # check a dir was passed
    try:
        assert isdir(file_path)
        # This way order of the files will be the same on every platform
        files = [file_path + "/" + f for f in sorted(listdir(file_path))]
        # Stores the absolute path
        files = [abspath(f) for f in files]
        # Filters out other file's type
        if extension is not None:
            files = [f for f in files if f.count(extension)]
        return files
    except AssertionError:
        if exists(file_path):
            raise AssertionError("Could not determine nature of parameter %s", file_path)
        else:
            raise AssertionError("Folder %s does not exist", file_path)


def parse_args():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("-j", "--json-files", nargs="*",  # 0 or more values expected => creates a list
                        type=str, default=None,
                        help="list of file or folder in which json files can be found")
    parser.add_argument("-w", "--weak-scaling", default=False, action="store_true",
                        help="Whether you want to compute weak scaling ")
    parser.add_argument("-s", "--sypd", default=False, action="store_true",
                        help="Whether you want to compare SYPD ")
    parser.add_argument("-f", "--function-info", default=False, action="store_true",
                        help="Whether you want to compare elapsed time by function ")
    parser.add_argument("-O", "--report-obj", default=None,
                        help="pkl object to which results will be added")
    parser.add_argument("--subsection-title", default=None,
                        help="If a report has been passed, the subsection title which will be created")
    args = parser.parse_args()

    if not args.json_files:
        parser.error("List of json file expected")

    return args


if __name__ == "__main__":
    # Get files from command line
    options = parse_args()
    json_file_list = get_files_from_path(options.json_files, "json")
    weak_scaling = options.weak_scaling
    SYPD = options.sypd
    function_info = options.function_info
    report_obj = options.report_obj
    subsection_title = options.subsection_title
    if report_obj is not None:
        from ReportGenerator import report_load
        # Load a report if exist, create a new one in case it doesn't
        report = report_load(report_obj)
        # Get the context
        context = report.get_context("Multi Experiment", section_number=None, subsection_title=subsection_title)
    else:
        context = None

    # Load the two experiments provided.
    experiment_data = [TimingInformation(json_file=f) for f in json_file_list]

    if SYPD:
        # Example how to get comparison of SYPD
        info_type = "Communication"
        var_type = "sypd"
        field3 = "average"
        multiexperiment_comparison(experiment_data, field1=info_type, field2=var_type, field3=field3).\
            print(context, computed_quantity=var_type)

    if function_info:
        # Example on how to compare elapsed time by function
        common_cases, common_functions = find_common_cases_and_functions(experiment_data)
        #
        info_type = "FunctionInfo"
        field = 'Elap. Time(s)'
        for function in common_functions:
            multiexperiment_comparison(experiment_data, field1=info_type, field2=function, field3=field).\
                print(context, computed_quantity=field)

    # Prints weak scaling info
    if weak_scaling:
        weakscaling_compute(experiment_data).print(context, computed_quantity="weak_scaling")
