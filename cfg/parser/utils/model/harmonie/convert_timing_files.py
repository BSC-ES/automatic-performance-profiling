# This script takes ifs.stat and Forecast logs and computes several stats
import re
import numpy as np
import pickle
from os.path import basename, abspath

def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument.
    :return: list of files
    """
    import argparse
    # Parse and assert command line options
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--ts-file", required=True,
                        help="ifs.stat file to parse")
    parser.add_argument("-f", "--forecast-file", required=True,
                        help="Forecast.x file to parse")
    parser.add_argument("-o", "--output-file", required=True,
                        help="name of the output .pkl file")
    return parser.parse_args()

def get_variable_value(variable_pattern, lines):
    """
    Given a variable returns the immediate value assigned to it. It searches for the first appearance in the lines.
    :param variable_pattern:
    :param lines:
    :return: value assigned to the variable
    """
    pattern = variable_pattern + "+([0-9\.]+)"
    for l in lines:
        m = re.search(pattern, l)
        if m:
            return float(m.group(1))

def get_from_pattern(pattern, line):
    """
    Given a pattern and a line returns the groups found.
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


def compute_sypd(line, forecast_len, ts_length):
    """
    Computes the SYPD by parsing the HARMONIE elapsed time (mm:ss format) from lines and using the forecast length
    in time steps and the time step duration in seconds.
    :param line:
    :param forecast_len:
    :param ts_duration:
    :return: SYPD
    """
    time_pattern = "([0-9\:]+) +([0-9A-Z]+) +CNT0 +([0-9]+) +" + "([0-9\.]+) +" * 3 + "([0-9\:]+) +" + "([0-9\:]+)"
    et_match = re.search(time_pattern, line)
    elapsed_time = et_match.groups()[7]
    min_sec_match = re.search("([0-9]+):([0-9]+)", elapsed_time)
    minutes = min_sec_match.groups()[0]
    seconds = min_sec_match.groups()[1]
    elapsed_time_sec = float(minutes)*60.0 + float(seconds)
    sypd = (forecast_len*ts_length)/(365.0*elapsed_time_sec)
    return sypd

def get_function_elapsed_time():
    """
    Retrieve the function elapsed time for a set of dummy functions (info not provided by HARMONIE logs, but needed by
    the automatic profiling workflow)
    :return: Dictionary with function information.
    """
    function_data = {}
    function_data["cpg_drv"] = float(1.0)
    function_data["call_sl"] = float(1.0)
    function_data["espcm"] = float(1.0)
    function_data["eltinv_ctl"] = float(1.0)
    function_data["eftinv_ctl"] = float(1.0)
    function_data["eftdir_ctl"] = float(1.0)
    function_data["eltdir_ctl"] = float(1.0)
    return function_data

def get_step_avg_duration(lines):
    """
    Processes the information of each step and returns the average
    :param lines:
    :return: Time-step average
    """
    # Step duration pattern
    step_duration_pattern = "([0-9\:]+) +([0-9A-Z]+) +([0-9A-Z]+) +([0-9\-]+) +" + "([0-9\.]+) +" * 3 + "([0-9\:]+) +" + "([0-9\:]+)"
    # Get step duration
    steps = []
    for l in lines[4:]:
        m = re.search(step_duration_pattern, l)
        if m:
            steps.append(float(m.groups()[6]))
    return np.average(steps)

if __name__ == "__main__":
    args = get_command_line_arguments()
    ifsstat_file = args.ts_file
    forecast_file = args.forecast_file
    output_file = args.output_file
    if not output_file.count(".pkl"):
        output_file += ".pkl"
    output_dict = {}
    # Parse files
    with open(forecast_file) as forecast_f:
        #Get number of processes
        m = re.match("([0-9]+)_([a-zA-Z]+).Forecast", basename(forecast_file))
        try:
            number_of_processes = float(m.group(1))
        except AttributeError:
            raise AttributeError("Filename %s does not have the expected format", forecast_file)
        output_dict[number_of_processes] = {}
        lines = [l for l in forecast_f]
        #Get forecast length and time step duration
        forecast_len = float(get_variable_value("CSTOP=\"t", lines))
        ts_length = float(get_variable_value("TSTEP=", lines))
    with open(ifsstat_file) as ifsstat_f:
        #Get number of processes
        m = re.match("([0-9]+)_([a-zA-Z]+).ifs.stat", basename(ifsstat_file))
        try:
            number_of_processes = float(m.group(1))
        except AttributeError:
            raise AttributeError("Filename %s does not have the expected format", ifsstat_file)
        lines = [l for l in ifsstat_f]
        output_dict[number_of_processes]["FunctionInfo"] = get_function_elapsed_time()
        output_dict[number_of_processes]["TimeStepTime"] = get_step_avg_duration(lines)
        output_dict[number_of_processes]["SYPD"] = compute_sypd(lines[-1], forecast_len, ts_length)
    # Save output
    pickle.dump(output_dict, open(output_file, "wb"))
    print("Converted timing file saved to " + abspath(output_file))
