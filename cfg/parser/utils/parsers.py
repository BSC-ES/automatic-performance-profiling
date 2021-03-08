# This script takes several timing.output logs and computes several stats
import re
import numpy as np
from cfg.parser.utils.curation import function_curated_summary, \
    dimemas_curated_summary, \
    simulated_years_per_day_summary, \
    function_info_csv, \
    most_expensive_function_summary, \
    L3_IPC_scatterplot, \
    simulated_years_per_day_plot, \
    tracking

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


def parse_filename(filename, pattern):
    filename = basename(filename)
    m = re.match(pattern, filename)
    try:
        m.group(1)
    except AttributeError:
        raise AttributeError("Filename %s does not have the expected format", filename)
    return m.groups()


def parse_paramedir_filename(filename):
    """
    It parses a filename and gives the core count and the information type that the corresponds to the file
    :param filename:
    :return: number of cores, information type
    """
    # The pattern of the paramedir filenames goes as follows: CORES_PARAMEDIRCFG.pm
    pattern = "([0-9]+)_([0-9a-zA-Z]+).pm"
    return parse_filename(filename, pattern)


def parse_dimemas_filename(filename):
    """
    It parses a filename and gives the core count and the information type that the corresponds to the file
    :param filename:
    :return: number of cores, information type
    """
    # The pattern of the dimemas filenames goes as follows: CORES_DIMEMASCFG_PARAMEDIRCFG.dm
    pattern = "([0-9]+)_([a-zA-Z]+)_([a-zA-Z]+).dm"
    return parse_filename(filename, pattern)


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
        cores = int(cores)
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
        cores = int(cores)
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

    def __init__(self, timing_files=None, paramedir_files=None, dimemas_files=None,
                 processes_per_node=48, json_file=None, param_file=None):
        # Init class variables
        self.experiment_name = None
        self.data = None
        self.cases = None
        self.base_case = None
        self.processes_per_node = processes_per_node
        self.functions = None
        self.param_file = self.load_param(param_file)

        if not timing_files and not paramedir_files and not json_file and not dimemas_files:
            raise AssertionError("No files provided")

        # Update values with the provided files
        if json_file:
            import json
            self.load_json(json_file)
        if paramedir_files:
            self.load_paramedir(paramedir_files)
        if dimemas_files:
            self.load_dimemas(dimemas_files)
        if timing_files:
            self.load_timings(timing_files)

    def __getitem__(self, item):
        return self.data[item]

    def find_functions(self):
        functions = []
        for case in self.cases:
            functions.append(list(self.data[case]["Counters"]["Cycles"].keys()))
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
                return []

    def load_param(self, param_file):
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

        # Set the real number of processes used
        try:
            ppn = param_dictionary['processes_per_node'][0]
            self.processes_per_node = ppn
        except KeyError:
            pass

        # If name for the experiment was not passed load it from param file
        if self.experiment_name is None:
            try:
                self.experiment_name = param_dictionary['configuration_name'][0]
            except KeyError:
                pass
        return param_dictionary

    def function_summary(self):
        # Adding calls to different ways of processing the data
        return function_curated_summary(self)

    def most_expensive_function_summary(self, out_file_name):
        return most_expensive_function_summary(self, out_file_name)

    def L3_IPC_scatterplot(self, out_file_name):
        return L3_IPC_scatterplot(self, out_file_name)

    def dimemas_summary(self):
        return dimemas_curated_summary(self)

    # Saves functions' info to csv
    def function_info_csv(self, csv_folder):
        function_info_csv(self, csv_folder)

    def simulated_years_per_day_summary(self):
        return simulated_years_per_day_summary(self)

    def simulated_years_per_day_plot(self, filename=None):
        return simulated_years_per_day_plot(self, filename)

    def tracking(self, folder):
        return tracking(self, folder)

    def save_json(self, filename=None):
        import json
        # Check if file name has been passed, if not use experiment name
        if filename is None:
            if self.experiment_name is not None:
                filename = self.experiment_name + ".json"
            else:
                filename = "experiment.json"
        # add extension if not there
        if not filename.count(".json"):
            filename = filename + ".json"
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

    def load_timings(self, timing_files):
        import pickle
        timing_info_dict = {}
        # Merge the dictionary into single one
        for file in timing_files:
            timing_info = pickle.load(open(file, "rb"))
            timing_info_dict[[*timing_info][0]] = timing_info[[*timing_info][0]]

        if self.functions:
            # Change function names to match the one in traces
            self.fix_function_names(timing_info_dict)

        if self.data is None:
            self.data = timing_info_dict
        else:
            self.data = merge_dictionaries(self.data, timing_info_dict)

        if self.cases is None:
            self.cases = list(sorted(self.data.keys()))
            self.base_case = min(self.cases)

    def load_paramedir(self, files):
        if not files:
            raise AssertionError("Empty list of files")
        if self.data is None:
            self.data = parse_paramedir_files(files)
        else:
            paramedir_info = parse_paramedir_files(files)
            self.data = merge_dictionaries(self.data, paramedir_info)
        if self.cases is None:
            self.cases = list(sorted(self.data.keys()))
            self.base_case = min(self.cases)
        self.functions = self.find_functions()

        pass

    def load_dimemas(self, files):
        if not files:
            raise AssertionError("Empty list of files")
        if self.data is None:
            self.data = parse_dimemas_files(files)
        else:
            dimemas_info = parse_dimemas_files(files)
            self.data = merge_dictionaries(self.data, dimemas_info)
        if self.cases is None:
            self.cases = list(sorted(self.data.keys()))
            self.base_case = min(self.cases)

        pass

    def fix_function_names(self, function_dict):
        for core in function_dict:
            function_info = function_dict[core]['FunctionInfo']
            # We can not cycle directly on key, because dictionary will change size, raising an exception
            list_of_function_names = [*function_info]
            for function_name in list_of_function_names:
                real_name = [f for f in self.functions if f.replace("_", "").count(function_name.replace("_", ""))]
                if real_name:
                    # Updates the name of the function with the ones present in the trace
                    function_info[real_name[0]] = function_info.pop(function_name)

