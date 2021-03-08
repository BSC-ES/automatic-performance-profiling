# This script takes several timing.output logs and computes several stats
import re
import numpy as np
import pickle
from os.path import basename, abspath
from cfg.latex.ReportGenerator import get_files_from_path


def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    import argparse
    # Parse and assert command line options
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--timing-files",
                        required=True, nargs='+', action='store',
                        help="list of files to parse")
    parser.add_argument("-o", "--output-file", required=True,
                        help="name of the output .json file")
    return parser.parse_args()


def parse_line(groups):
    section = groups[0]
    values = [float(v) for v in groups[1:]]
    return section, values


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
    Parses the section containing computing and communication time, where also the SYPD is provided
    :param lines:
    :return: Dictionary with computing and communication info.
    """
    computing_time_pattern = "Computing +time : +([0-9\.E\+]+) +on MPI rank : +([0-9\.E\+]+)"
    lbclnk_time_pattern = "Waiting +lbc_lnk +time +: +([0-9\.E\+]+) \( ([0-9\.E\+]+) +%\) +on MPI rank : +([0-9\.E\+]+)"
    global_time_pattern = "Waiting  global time :    ([0-9\.E\+]+) \( ([0-9\.E\+]+) %\)           on MPI rank :      ([0-9\.E\+]+)"
    total_time_pattern = "Total *time : +([0-9\.E\+]+) +\(SYPD: +([0-9\.E\+]+) +\) on +MPI +rank +: +([0-9\.E\+]+)"

    computing_times = []
    p2p_times = []
    p2p_pcts = []
    collective_times = []
    collective_pcts = []
    total_times = []
    sypds = []

    for l in lines:
        # For each line in the file see if it matches any of the different kinds of patterns
        computing_time, rank = get_from_pattern(computing_time_pattern, l)
        p2p_time, p2p_pct, rank = get_from_pattern(lbclnk_time_pattern, l)
        collective_time, collective_pct, rank = get_from_pattern(global_time_pattern, l)
        total_time, sypd, rank = get_from_pattern(total_time_pattern, l)

        # In case if finds something add to the corresponding list
        if computing_time is not None:
            computing_times.append(computing_time)
        if p2p_time is not None:
            p2p_times.append(p2p_time)
            p2p_pcts.append(p2p_pct)
        if collective_time is not None:
            collective_times.append(collective_time)
            collective_pcts.append(collective_pct)
        if total_time is not None:
            total_times.append(total_time)
            sypds.append(sypd)

    # Return a dictionary with the information
    total_dict = {
        "sypd": {"values": sypds, "average": np.average(sypds), "std": np.std(sypds)},
        "total_time": {"values": total_times, "average": np.average(total_times), "std": np.std(total_times)},
        "computing_time": {"values": computing_times, "average": np.average(computing_times), "std": np.std(computing_times)},
        "p2p_time":{"values": p2p_times, "average": np.average(p2p_times), "std": np.std(p2p_times)},
        "p2p_pct": {"values": p2p_pcts, "average": np.average(p2p_pcts), "std": np.std(p2p_pcts)},
        "collective_time": {"values": collective_times, "average": np.average(collective_times), "std": np.std(collective_times)},
        "collective_pct": {"values": collective_pcts, "average": np.average(collective_pcts), "std": np.std(collective_pcts)}
    }
    return total_dict["sypd"]["average"]


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
            function_name, values = parse_line(m.groups())
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
    timing_files = get_files_from_path(args.timing_files)
    output_file = args.output_file
    if not output_file.count(".pkl"):
        output_file += ".pkl"
    output_dict = {}
    # Parse files
    for timing_f in timing_files:
        with open(timing_f) as f:
            # Get number of processes
            m = re.match("([0-9]+)_([a-zA-Z]+).timing", basename(timing_f))
            try:
                number_of_processes = m.group(1)
            except AttributeError:
                raise AttributeError("Filename %s does not have the expected format", timing_f)
            output_dict[number_of_processes] = {}
            lines = [l for l in f]
            output_dict[number_of_processes]["FunctionInfo"] = get_function_elapsed_time(lines)
            # Get step duration at process 0
            output_dict[number_of_processes]["TimeStepTime"] = get_step_avg_duration(lines)
            output_dict[number_of_processes]["Communication"] = get_avg_sypd(lines)
    # Save output
    pickle.dump(output_dict, open(output_file+".pkl", "wb"))
    print("Converted timing file saved to " + abspath(output_file))

