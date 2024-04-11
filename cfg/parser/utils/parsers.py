# This script takes several timing.output logs and computes several stats
import re
import numpy as np
from cfg.parser.utils.curation import function_curated_summary, \
    dimemas_curated_summary, \
    simulated_years_per_day_summary, \
    function_info_csv, \
    most_expensive_function_summary, \
    simulated_years_per_day_plot, \
    tracking, \
    cases_component_data

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
    pattern = "([a-z]+)-([0-9a-zA-Z_]+)-([0-9a-zA-Z_]+).pm"
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
        component, id, information_type = parse_paramedir_filename(filename)
        # Initialize dictionary in case it does not exists
        # Retrieve the section to store the data
        address = (id,
                   "Components",
                   component,
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

    def __init__(self, timing_files=None, lucia_files=None, paramedir_files=None, dimemas_files=None,
                 processes_per_node=48, json_file=None, param_file=None, components=None):
        # Init class variables
        self.experiment_name = None
        self.cases = None
        self.base_case = None
        self.processes_per_node = processes_per_node
        self.functions = None
        self.function_info_src = ""
        self.param_file = self.load_param(param_file)
        self.data = None
        self.components = components
        self.components_cases = None

        if not timing_files and not lucia_files and not paramedir_files and not json_file and not dimemas_files:
            raise AssertionError("No files provided")

        # Update values with the provided files
        if json_file:
            import json
            self.load_json(json_file)
        if timing_files:
            self.load_timings(timing_files)
            self.function_info_src = "timing"
        else:
            self.function_info_src = "paramedir"
        if paramedir_files:
            self.load_paramedir(paramedir_files)
        if dimemas_files:
            self.load_dimemas(dimemas_files)
        if lucia_files:
            self.load_lucia(lucia_files)

    def __getitem__(self, item):
        return self.data[item]

    def find_functions(self):
        functions = []
        for case in self.cases:
            for component in self.components:
                functions.append(list(self.data[case]["Components"][component]["Counters"]["PAPI_TOT_CYC"].keys()))
        functions = sum(functions, [])
        return list(set(functions))

    # Returns the information of the functions with the following structure
    # {function_name: {case: {"nproc": nprocs, "elapsed_time": elapsed_time}}}
    # with the cases sorted by the nproc of the component corresponding the function
    def get_function_info(self, component=""):
        # Create a dictionary with function info for all cases available
        ret_val = {}
        if component == "":
            components = self.components
            cases = self.cases
        else:
            components = [component]
            cases = self.components_cases[component]
            
        for component_name in components:
            for function in self.functions:
                ret_val[function] = {}
                for case in cases:
                    nproc = self[case]["Components"][component_name]["nproc"]
                    ret_val[function][case] = {"nproc": nproc, "elapsed_time": 0}
                    try:
                        # Store results in dictionary if present
                        ret_val[function][case]["elapsed_time"] = self[case]["Components"][component_name]["FunctionInfo"][function]
                    except KeyError:
                        # Remove the entry and pass to the next function
                        del ret_val[function]
                        break
        return ret_val

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
            if len(val) > 2 and val[0] == "\'" and val[-1] == "\'":
                val = val[1:-1]
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

    def function_summary(self, filename):
        # Adding calls to different ways of processing the data
        return function_curated_summary(self, filename)

    def most_expensive_function_summary(self, out_file_name):
        return most_expensive_function_summary(self, out_file_name)

    def scatter_plots(self, x_axis="L3", y_axis="IPC", length_summary=10):
        import warnings
        import re
        # Function plot L3 cache misses vs IPC
        import matplotlib.pyplot as plt
        import numpy as np

        # Dictionary with function info from counters
        function_info = {}
        n_function = 0
        for component in self.components:
            function_info[component] = {}
            for f_name in self.functions:
                # Track just the first Nth function
                if n_function == length_summary:
                    break
                function_info[component][f_name] = {'x': [], 'y': []}
                n_function += 1
                for case in self.cases:
                    try:
                        # Function name's are taken from timings, so it is possible they are not present in the trace
                        x_data = self.data[case]["Components"][component]['Counters'][x_axis][f_name]['Average']
                        y_data = self.data[case]["Components"][component]['Counters'][y_axis][f_name]['Average']
                    except KeyError:
                        # If the function was not tracked delete dictionary entry and skip to next function
                        del function_info[component][f_name]
                        n_function -= 1
                        break

                    # Add the data to the dictionary
                    function_info[component][f_name]['x'] += x_data
                    function_info[component][f_name]['y'] += y_data

        # Create the plot
        for component in  function_info:
            output_name = component + "-" + x_axis + "-" + y_axis + ".png"
            
            fig, ax = plt.subplots()
            ax.set_title("%s vs %s per 1000 instructions in %s" % (x_axis, y_axis, component))
            ax.set_xlabel(x_axis)
            ax.set_ylabel(y_axis)
            for i, f_name in enumerate(function_info[component]):
                if f_name[0] == "_":
                    # Remove leading underscores that python does not know how to render
                    legend_name = re.sub('^_+', "", f_name)
                else:
                    legend_name = f_name
                x = function_info[component][f_name]['x']
                y = function_info[component][f_name]['y']
                u = np.diff(x) 
                v = np.diff(y) 
                pos_x = x[:-1]
                pos_y = y[:-1]

                c = np.full(len(x), i / len(function_info[component]))
                ax.quiver(pos_x, pos_y, u, v, angles="xy", pivot="tail", headlength = 2, headaxislength = 2, scale_units = "xy", scale = 1, color = plt.cm.tab20(c))
                ax.scatter(x, y, marker="o", label=legend_name, c = plt.cm.tab20(c), edgecolors = "black")
            
            if len(function_info[component]) == 0:
                ax.text(0.5, 0.5, "%s vs %s not available" % (x_axis, y_axis), ha="center", va="center")

            ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
            fig.savefig(output_name,  bbox_inches='tight')


    def dimemas_summary(self):
        return dimemas_curated_summary(self)

    # Saves functions' info to csv
    def function_info_csv(self, csv_folder):
        function_info_csv(self, csv_folder)

    def simulated_years_per_day_summary(self, filename):
        return simulated_years_per_day_summary(self, filename)

    def simulated_years_per_day_plot(self, filename=None):
        return simulated_years_per_day_plot(self, filename)

    def tracking(self, folder):
        return tracking(self, folder)

    def cases_component_data(self):
        return cases_component_data(self)

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
            "param_file": self.param_file,
            "components": self.components,
            "components_cases": self.components_cases
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
            self.components = json_data["components"]
            self.components_cases = json_data["components_cases"]
            try:
                self.param_file = json_data["param_file"]
            except KeyError:
                pass
        
        self.rename_cases()

    # This function renames the cases after getting all the info about them to have shorter names in the report
    # it is not done before because is easier to merge the same cases if they have the same id
    def rename_cases(self):
        for i in range(0, len(self.cases)): 
            new_case_name = "Case %i" % i           
            if self.cases[i] == self.base_case:
                self.base_case = new_case_name
            self.data[new_case_name] = self.data.pop(self.cases[i])
            for components in self.components:
                self.components_cases[components][self.components_cases[components].index(self.cases[i])] = new_case_name
            self.cases[i] = new_case_name


    def load_lucia(self, lucia_files):
        import pandas as pd
        lucia_dict = {}
        for lucia_file in lucia_files:
            pattern = "(scalability)_([0-9a-zA-Z_]+)/(lucia_lite_results/*)"
            _, id, _ = re.match(pattern, lucia_file).groups()
            lucia_df = pd.read_csv(lucia_file)
            lucia_dict[id] = {"Components" : {}}
            for _, row in lucia_df.iterrows():
                component = row["component_name"]
                if component == "oceanx":
                    component = "nemo"
                elif component == "OpenIFS":
                    component = "oifs"
        
                if component == "Coupled":
                    lucia_dict[id] |= row[1:].to_dict()
                    lucia_dict[id]["SYPD"] = lucia_dict[id]["sypd"]
                else:   
                    lucia_dict[id]["Components"][component] = row[1:].to_dict()
                    lucia_dict[id]["Components"][component]["SYPD"] = lucia_dict[id]["Components"][component]["sypd"]

        if self.data is None:
            self.data = lucia_dict
        else:
            self.data = merge_dictionaries(self.data, lucia_dict)
                
        if self.cases is None:
            self.cases = list(sorted(self.data.keys()))
            self.base_case = min(self.cases)

        if self.components_cases is None:
            self.components_cases = {}   
            for component in self.components:
                self.components_cases[component] = sorted(self.data, key=lambda f: self.data[f]["Components"][component]["nproc"])

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
            self.cases = list(sorted(self.data.keys(), key=lambda f : self.data[f]["nproc"]))
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

        if self.function_info_src == "paramedir":
            for case in self.cases:
                for component in self.data[case]["Components"]:
                    component_function_info = {}
                    for function_name in  self.data[case]["Components"][component]["Counters"]["Time"]:
                        component_function_info[function_name] = self.data[case]["Components"][component]["Counters"]["Time"][function_name]["Average"][0]
                    self.data[case]["Components"][component]["FunctionInfo"] = component_function_info

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
