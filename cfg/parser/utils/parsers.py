# This script takes several timing.output logs and computes several stats
import re
import numpy as np
from cfg.parser.utils.curation import function_curated_summary, simulated_years_per_day_summary, \
    save_function_summary_csv, simulated_years_per_day_plot
from os.path import basename
from cfg.parser.utils.histograms import process_category_histogram, split_3d_histogram


def dictionary_pointer(dictionary, address):
    """
    It creates the proper dictionary structure according to an address provided.
    In case the proper structure already exists it only retrieves it.
    :param dictionary:
    :param address:
    :return: dictionary section
    """

    def initialize_dictionary_section(d, section):
        try:
            d[section]
        except KeyError:
            d[section] = {}
        return d[section]

    for step in address:
        dictionary = initialize_dictionary_section(dictionary, step)
    return dictionary


def parse_paramedir_filename(filename):
    """
    It parses a filename and gives the core count and the information type that the corresponds to the file
    :param filename:
    :return: number of cores, information type
    """
    pattern = "([0-9]+)_([a-zA-Z]+).pm"
    filename = basename(filename)
    m = re.match(pattern, filename)
    try:
        cores = m.group(1)
    except AttributeError:
        raise AttributeError("Filename %s does not have the expected format", filename)

    cores = int(cores)
    information_type = m.group(2)
    return cores, information_type


def parse_dimemas_filename(filename):
    """
    It parses a filename and gives the core count and the information type that the corresponds to the file
    :param filename:
    :return: number of cores, information type
    """
    pattern = "([0-9]+)_([a-zA-Z]+)_([a-zA-Z]+).dm"
    filename = basename(filename)
    m = re.match(pattern, filename)
    try:
        cores = m.group(1)
    except AttributeError:
        raise AttributeError("Filename %s does not have the expected format", filename)

    cores = int(cores)
    simulation_type = m.group(2)
    information_type = m.group(3)

    return cores, simulation_type, information_type


def merge_dictionaries(dict_one, dict_two):
    """
    Takes two dictionaries and puts the information of both in a new dictionary
    :param dict_one:
    :param dict_two:
    :return: new_dict
    """
    new_dict = dict_one.copy()
    for key in dict_two.keys():
        try:
            if isinstance(new_dict[key], dict):
                new_dict[key] = merge_dictionaries(new_dict[key], dict_two[key])
            else:
                new_dict[key] = [new_dict[key], dict_two[key]]
        except KeyError:
            new_dict[key] = dict_two[key]
    return new_dict


def distributed_variable(values):
    return {"values": values, "average": np.average(values), "std": np.std(values)}


def parse_timing_files(files):
    """
    Function that reads a list of files and returns different data of interest
    :param files: List of files to process
    :return: Results object with the info parsed.
    """

    def parse_communication_time(lines):
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

        def num_groups(regex):
            """
            :param regex: A regex pattern
            :return: Number of groups in a regex pattern
            """
            return re.compile(regex).groups

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
            ng = num_groups(pattern)
            if ng == 2:
                return None, None
            elif ng == 3:
                return None, None, None
            else:
                raise AssertionError

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
        return {
            "sypd": distributed_variable(sypds),
            "total_time": distributed_variable(total_times),
            "computing_time": distributed_variable(computing_times),
            "p2p_time": distributed_variable(p2p_times),
            "p2p_pct": distributed_variable(p2p_pcts),
            "collective_time": distributed_variable(collective_times),
            "collective_pct": distributed_variable(collective_pcts),
        }

    # Few functions used to parse a file
    def parse_time_by_process_info(lines, filename):
        """
        Parses the info for each process and returns a dictionary with the following keys and data for each process:
        "Elapsed Time(s)"
        "CPU Time(s)"
        "Ratio CPU / Elapsed"
        Example: To access the elapsed time information from process 11 we could do it like:
            return_value[11][ "Elapsed Time(s)"]
        :param filename:
        :param lines: Lines of a file
        :return: Nested dictionary with
        """

        def parse_time_by_process_line(groups):
            process = groups[0]
            values = [float(v) for v in groups[1:]]
            return process, values

        # Regex patterns
        process_time = " +([0-9]+) +\| +([0-9\.E\+]+) +\| +([0-9\.E\+]+) +\| +([0-9\.E\+]+)"
        # Time by processor
        process_data = {}
        # Labels
        labels = ["Elapsed Time(s)", "CPU Time(s)", "Ratio CPU / Elapsed"]
        for l in lines:
            m = re.search(process_time, l)
            if m:
                # Process Rank | Elapsed Time (s) | CPU Time (s) | Ratio CPU/Elapsed
                process, values = parse_time_by_process_line(m.groups())
                process_data[process] = {}
                for label, value in zip(labels, values):
                    process_data[process][label] = value

        pattern = "([0-9]+)_([a-zA-Z]+).timing"
        filename = basename(filename)
        m = re.match(pattern, filename)
        try:
            cores = m.group(1)
        except AttributeError:
            raise AttributeError("Filename %s does not have the expected format", filename)
        cores = int(cores)

        return cores, process_data

    def parse_function_info(lines):
        """
        Parses function info.
        For each function found the information stored is the following:
            "Elap. Time(s)"
            "Elap. Time(%)"
            "CPU Time(s)"
            "CPU Time(%)"
            "CPU/Elap"
            "Max elap(%)"
            "Min elap(%)"
            "Freq"
        Example: To access the elapsed time information for "dyn_spg" routine we could do it like:
            return_value["dyn_spg"]["Elap. Time(s)"]
        :param lines:
        :return: Dictionary with function information.
        """

        def parse_function_line(groups):
            section = groups[0]
            values = [float(v) for v in groups[1:]]
            return section, values

        # Regex pattern for function times
        functions_pattern = "([0-9a-zA-Z_]+) +" + "([0-9\.E\+\-]+) +" * 7 + "([0-9\.E\+\-]+)"
        # Labels
        labels = ["Elap. Time(s)", "Elap. Time(%)", "CPU Time(s)", "CPU Time(%)", "CPU/Elap", "Max elap(%)",
                  "Min elap(%)", "Freq"]
        # Get function information
        function_data = {}
        for l in lines:
            m = re.search(functions_pattern, l)
            if m:
                section, values = parse_function_line(m.groups())
                function_data[section] = {}
                for label, value in zip(labels, values):
                    function_data[section][label] = value
        return function_data

    def steps_info(lines):
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
        return np.average(steps), np.std(steps)

    # Dictionary with results
    results = {}
    # Parse files
    for filename in files:
        with open(filename) as f:
            lines = [l for l in f]

            # Get number of processes and detailed process data
            number_of_processes, process_data = parse_time_by_process_info(lines, filename)
            # Save case results
            results[number_of_processes] = {"ProcessInfo": process_data}
            # Get function info
            function_info = parse_function_info(lines)
            results[number_of_processes]["FunctionInfo"] = function_info
            # Get step duration at process 0
            step_av, step_std = steps_info(lines)
            results[number_of_processes]["TimeStepTime"] = (step_av, step_std)
            #
            results[number_of_processes]["Communication"] = parse_communication_time(lines)
    return results


def parse_paramedir_files(files):
    """
    Takes a list of filenames corresponding to outputs of paramedir runs and process it returning a dictionary with
    the data
    :param files:
    :return:
    """
    results = {}
    for filename in files:
        # Get core count and information type from filename
        cores, information_type = parse_paramedir_filename(filename)
        # Initialize dictionary in case it does not exists
        # Retrieve the section to store the data
        address = (cores,
                   "Counters",
                   information_type,
                   )
        dictionary_section = dictionary_pointer(results, address)
        # Open the file and process the contents
        with open(filename) as f:
            text = f.read()
            histograms = split_3d_histogram(text)
            for function_name, histogram in histograms.items():
                dictionary_section[function_name] = process_category_histogram(histogram)
    return results


def parse_dimemas_files(files):
    """
    Takes a list of filenames corresponding to outputs of paramedir runs applied to dimemas simulations
     and process it returning a dictionary with the data
    :param files:
    :return: dictionary
    """
    results = {}
    for filename in files:
        # Get core count and information type from filename
        cores, simulation_type, information_type = parse_dimemas_filename(filename)

        # Retrieve the section to store the data
        address = (cores,
                   "Dimemas",
                   simulation_type,
                   information_type,
                   )
        dictionary_section = dictionary_pointer(results, address)

        # Open the file and process the contents
        with open(filename) as f:
            text = f.read()
            histograms = split_3d_histogram(text)
            for function_name, histogram in histograms.items():
                dictionary_section[function_name] = process_category_histogram(histogram)
    return results


class TimingInformation:
    """
    Class to store the information of one experiment in a nested dictionary
    The dictionary stored at .data includes the following information (the values between '' are the actual keys).

    case (number of processes used)
    |---'Communication':
    |   |---'collective_pct'
    |   |---'collective_time'
    |   |---'computing_time'
    |   |---'p2p_pct'
    |   |---'p2p_time'
    |   |---'sypd'
    |   |---'total_time'
    |
    |---'FunctionInfo'
    |   |--- function_name (the name of the function)
    |       |--- 'CPU Time(%)'
    |       |--- 'CPU Time(s)'
    |       |--- 'CPU/Elap'
    |       |--- 'Elap. Time(%)'
    |       |--- 'Elap. Time(s)'
    |       |--- 'Freq'
    |       |--- 'Max elap(%)'
    |       |--- 'Min elap(%)'
    |
    |---'ProcessInfo'
    |   |--- process_id (the number of the process 0 or 45 for example)
    |       |--- 'CPU Time(s)'
    |       |--- 'Elapsed Time(s)'
    |       |--- 'Ratio CPU / Elapsed'
    |---'TimeStepTime'
    |   |--- (average, standard deviation) # (a tuple with the actual values)
    """

    def __init__(self, experiment_name=None, timing_files=None,
                 paramedir_files=None, dimemas_files=None, cores_per_node=48, json_file=None, param_file=None):
        # Init class variables
        self.experiment_name = experiment_name
        self.data = None
        self.cases = None
        self.base_case = None
        self.processes_per_node = None
        self.functions = None
        self.param_file = self.get_param_info(param_file)

        if not timing_files and not paramedir_files and not json_file and not dimemas_files:
            raise AssertionError("No files provided")

        # Update values with the provided files
        if json_file:
            import json
            self.load_json(json_file)
        if timing_files:
            self.load_timings(timing_files)
        if paramedir_files:
            self.load_paramedir(paramedir_files)
        if dimemas_files:
            self.load_dimemas(dimemas_files)
        # If the property processes_per_node hasn't been set, we set it here. (It won't overwrite the value from a json)
        if self.processes_per_node is None:
            self.processes_per_node = cores_per_node

    def __getitem__(self, item):
        return self.data[item]

    def find_functions(self):
        functions = []
        for case in self.cases:
            functions.append(list(self.data[case]["FunctionInfo"].keys()))
        functions = sum(functions, [])
        return list(set(functions))

    def get_function_info(self, function, cases=None):
        # Convert it to a list in case it is not
        if cases is None:
            cases = self.cases
        if cases is not None and not isinstance(cases, list):
            cases = list(cases)
        for case in cases:
            try:
                yield case, self[case]["FunctionInfo"][function]
            except KeyError:
                pass

    @staticmethod
    def get_param_info(param_file):
        from os.path import isfile
        if param_file is None:
            return None

        try:
            assert isfile(param_file)
        except AssertionError:
            raise AssertionError("parameter file %s not found", param_file)

        f = open(param_file, "r")
        param = [l.replace("\n", "") for l in f if l.count("#") == 0 and l != "\n"]
        param_dictionary = {}
        for line in param:
            key, val = line.split("=")
            param_dictionary[key.strip()] = val.strip().split(" ")
        return param_dictionary

    # Adding calls to different ways of processing the data
    def function_summary(self):
        return function_curated_summary(self)

    # Saves functions' info to csv
    def function_info_csv(self, csv_folder):
        save_function_summary_csv(self, csv_folder)

    def simulated_years_per_day_summary(self):
        return simulated_years_per_day_summary(self)

    def simulated_years_per_day_plot(self, filename=None):
        return simulated_years_per_day_plot(self, filename)

    def save_json(self, filename=None):
        import json
        if filename is None:
            filename = self.experiment_name + ".json"

        dictionary_to_save = {
            "experiment_name": self.experiment_name,
            "data": self.data,
            "cases": self.cases,
            "base_case": self.base_case,
            "processes_per_node": self.processes_per_node,
            "functions": self.functions,
            "param_file": self.param_file
        }

        with open(filename, "w") as f:
            json.dump(dictionary_to_save, f)

    def load_json(self, filename):
        import json

        def json_keys2int(x):
            if isinstance(x, dict):
                try:
                    return {int(k): v for k, v in x.items()}
                except ValueError:
                    return {k: v for k, v in x.items()}
            return x

        with open(filename, "r") as f:
            json_data = json.load(f, object_hook=json_keys2int)
            self.experiment_name = json_data["experiment_name"]
            self.data = json_data["data"]
            self.cases = json_data["cases"]
            self.base_case = json_data["base_case"]
            self.processes_per_node = json_data["processes_per_node"]
            self.functions = json_data["functions"]
            try:
                self.param_file = json_data["param_file"]
            except KeyError:
                pass

    def load_timings(self, files):
        if not files:
            raise AssertionError("Empty list of files")
        if self.data is None:
            self.data = parse_timing_files(files)
        else:
            timing_info = parse_timing_files(files)
            self.data = merge_dictionaries(self.data, timing_info)
        self.cases = list(sorted(self.data.keys()))
        self.base_case = min(self.cases)

        self.functions = self.find_functions()

    def load_paramedir(self, files):
        if not files:
            raise AssertionError("Empty list of files")
        if self.data is None:
            self.data = parse_paramedir_files(files)
        else:
            paramedir_info = parse_paramedir_files(files)
            self.data = merge_dictionaries(self.data, paramedir_info)

        pass

    def load_dimemas(self, files):
        if not files:
            raise AssertionError("Empty list of files")
        if self.data is None:
            self.data = parse_dimemas_files(files)
        else:
            dimemas_info = parse_dimemas_files(files)
            self.data = merge_dictionaries(self.data, dimemas_info)

        pass
