# This script takes several timing.output logs and computes several stats
import re
import numpy as np
import pickle
from os.path import basename, abspath


def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    import argparse
    # Parse and assert command line options
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--timing-files", required=True,
                        help="list of files to parse")
    parser.add_argument("-o", "--output-file", required=True,
                        help="name of the output .json file")
    return parser.parse_args()


def get_from_pattern(pattern, line):
    """
    Given a pattern and a line returns the groups found
    :param pattern:
    :param line:
    :return: Contents of the groups that made match.
    """
    m = re.search(pattern, line)
    if m:
        if len(m.groups()) == 2:
            v, rank = m.groups()
            return float(v), int(rank)
        elif len(m.groups()) == 3:
            v1, v2, rank = m.groups()
            return float(v1), float(v2), int(rank)
    ng = re.compile(pattern).groups
    if ng == 2:
        return None, None
    elif ng == 3:
        return None, None, None
    else:
        raise AssertionError


def get_avg_sypd(lines):
    """
    Parses the section containing computing and communication time, where SYPD is provided
    """
    total_time_pattern = "Total *time : +([0-9\.E\+]+) +\(SYPD: +([0-9\.E\+]+) +\) on +MPI +rank +: +([0-9\.E\+]+)"

    sypds = []
    for l in lines:
        # For each line in the file see if it matches any of the different kinds of patterns
        match = re.search(total_time_pattern, l)
        if match:
            total_time, sypd, rank = match.groups()
            sypds.append(float(sypd))

    return np.average(sypds)


def get_function_elapsed_time(lines):
    """
    Retrieve the function elapsed time
    :param lines:
    :return: Dictionary with function information.
    """

    # Regex pattern for function times
    functions_pattern = "([0-9a-zA-Z_]+) +" + "([0-9\.E\+\-]+) +" * 7 + "([0-9\.E\+\-]+)"
    # All labels
    # "Elap. Time(s)", "Elap. Time(%)", "CPU Time(s)", "CPU Time(%)", "CPU/Elap", "Max elap(%)", "Min elap(%)", "Freq"

    # Get function information
    function_data = {}
    for l in lines:
        m = re.search(functions_pattern, l)
        if m:
            function_name = m.groups()[0]
            values = [float(v) for v in m.groups()[1:]]
            # Get just elapsed time
            function_data[function_name] = values[1]
    return function_data


def get_step_avg_duration(lines):
    """
    Processes the information of each step and returns the average and the standard deviation
    :param lines:
    :return: Time-step average and standard deviation
    """
    # Step length pattern
    step_length_pattern = "timing step *[0-9]+ *: *(.*)"
    # Get step duration
    steps = []
    for l in lines:
        m = re.search(step_length_pattern, l)
        if m:
            steps.append(float(m.group(1)))
    return np.average(steps)


if __name__ == "__main__":
    args = get_command_line_arguments()
    timing_files = args.timing_files
    output_file = args.output_file
    if not output_file.count(".pkl"):
        output_file += ".pkl"
    output_dict = {}
    # Parse files
    with open(timing_files) as timing_f:
        # Get number of processes
        m = re.match("([0-9]+)_([a-zA-Z]+).timing", basename(timing_files))
        try:
            number_of_processes = float(m.group(1))
        except AttributeError:
            raise AttributeError("Filename %s does not have the expected format", timing_files)
        output_dict[number_of_processes] = {}
        lines = [l for l in timing_f]
        output_dict[number_of_processes]["FunctionInfo"] = get_function_elapsed_time(lines)
        # Get step duration at process 0
        output_dict[number_of_processes]["TimeStepTime"] = get_step_avg_duration(lines)
        output_dict[number_of_processes]["SYPD"] = get_avg_sypd(lines)
    # Save output
    pickle.dump(output_dict, open(output_file, "wb"))
    print("Converted timing file saved to " + abspath(output_file))

