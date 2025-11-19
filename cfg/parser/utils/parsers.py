"""
This script processes various performance profiling logs and computes several statistics.
It includes functions to parse filenames, merge dictionaries, process timing files, and
generate summaries and plots for performance analysis.
"""
import re
import os
import math
import numpy as np
from cfg.parser.utils.curation import function_curated_summary, \
    dimemas_curated_summary, \
    simulated_years_per_day_summary, \
    function_info_csv, \
    most_expensive_function_summary, \
    simulated_years_per_day_plot, \
    tracking, \
    cases_component_data, \
    coupling_info

from os.path import basename
from cfg.parser.utils.histograms import process_category_histogram, split_3d_histogram


def dictionary_pointer(dictionary, address):
    """
    Navigate through a nested dictionary using a sequence of keys and create missing sections.

    This function traverses a nested dictionary using a sequence of keys (address) and ensures
    that each level exists by creating empty dictionaries for missing sections. It returns
    a pointer to the deepest level specified by the address.

    Args:
        dictionary (dict): The input dictionary to traverse and potentially modify.
        address (Iterable): A sequence of keys defining the path to traverse in the dictionary.

    Returns:
        dict: A reference to the nested dictionary at the specified address.
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
    except AttributeError as exc:
        raise AttributeError(
            f"Filename {filename} does not have the expected format") from exc
    return m.groups()


def parse_paramedir_filename(filename):
    # The pattern of the paramedir filenames goes as follows: CORES_PARAMEDIRCFG.pm
    pattern = "([A-Z0-9a-z]+)-([0-9a-zA-Z_]+)-([0-9a-zA-Z_]+).pm"
    return parse_filename(filename, pattern)


def parse_dimemas_filename(filename):
    # The pattern of the dimemas filenames goes as follows: CORES_DIMEMASCFG_PARAMEDIRCFG.dm
    pattern = "([0-9]+)_([a-zA-Z]+)_([a-zA-Z]+).dm"
    return parse_filename(filename, pattern)


def merge_dictionaries(dict_one, dict_two, path = []):
    """
    Merges two dictionaries recursively, with dict_one taking precedence in case of conflicts.

    This function performs a deep merge of two dictionaries. For nested dictionaries,
    it recursively merges their contents. For non-dictionary values, if there's a
    conflict, the value from dict_one is preserved.

    Args:
        dict_one (dict): The primary dictionary that will be modified and returned.
        dict_two (dict): The secondary dictionary whose values will be merged into dict_one.
        path (list, optional): Used for recursive calls to track the current path in nested structures.
            Defaults to empty list.

    Returns:
        dict: The merged dictionary (dict_one modified in place with dict_two's values).
    """


    if dict_one is None:
        return dict_two

    if dict_two is None:
        return dict_one

    for key in dict_two:
        if key in dict_one:
            if isinstance(dict_one[key], dict) and isinstance(dict_two[key], dict):
                merge_dictionaries(dict_one[key], dict_two[key], path + [str(key)])
            elif dict_one[key] != dict_two[key]:
                continue
        else:
            dict_one[key] = dict_two[key]
    return dict_one

def distributed_variable(values):
    return {"values": values, "average": np.average(values), "std": np.std(values)}

def parse_paramedir_files(files):
    """
    Takes a list of filenames corresponding to outputs of paramedir runs and process it returning a dictionary with
    the data
    Args:
        files (str): List of filenames corresponding to outputs of paramedir runs.
    Returns:
        dict: A dictionary containing the processed data from the Paramedir files.
    """
    results = {}
    for filename in files:
        # Get core count and information type from filename
        component, id, information_type = parse_paramedir_filename(filename)

        nproc = 0
        split_id = id.split("_")
        i = 0
        while i < len(split_id):
            address = (id,
                       "components",
                       split_id[i])
            component_section = dictionary_pointer(results, address)
            component_section["nproc"] = int(split_id[i + 1])
            nproc += int(split_id[i + 1])
            i += 2
        results[id]["nproc"] = nproc
        # Initialize dictionary in case it does not exists
        # Retrieve the section to store the data
        address = (id,
                   "components",
                   component,
                   "counters",
                   information_type,
                   )
        dictionary_section = dictionary_pointer(results, address)
        # Open the file and process the contents
        with open(filename, encoding="utf8") as f:
            text = f.read()
            histograms = split_3d_histogram(text)
            for function_name, histogram in histograms.items():
                if "std::" in function_name:
                    continue
                dictionary_section[function_name] = process_category_histogram(
                    histogram)
    return results

def parse_nemo_namelist(nemo_namelist_fn: str) -> dict:
    field_ptrn = " *([a-zA-Z0-9_]+)[ ]*=[ ]*([0-9\.E+\-]+)"
    data = {}
    with open(nemo_namelist_fn, "r", encoding="utf8") as nemo_namelist_f:
        for line in nemo_namelist_f:
            field_match = re.search(field_ptrn, line)
            if field_match:
                field_name = field_match.group(1)
                field_value = field_match.group(2)
                data[field_name] = field_value
    
    return data

def parse_nemo5_timing(timing_fn: str):
    step_length_ptrn = "Mean:[ ]*([0-9.e\+\-]+)"
    functions_header_ptrn = "Timing : AVG values over all MPI processes:"
    functions_ptrn = "([0-9a-zA-Z_]+)[ ]*\|[ ]*([0-9.]+)s"
    total_time_ptrn = "avg over all MPI processes = ([0-9.]+)s"

    data = {"function_info": {}, "time_step_time": 0,
            "number_ts": 0, "ts_per_second": 0, "sypd": 0, "total_time": 0}
    
    runtime_path = os.path.dirname(timing_fn)
    namelist_cfg_fn = os.path.join(runtime_path, "namelist_cfg")
    if os.path.exists(namelist_cfg_fn):
        print(f"[INFO][{timing_fn}] Taking parameters from {namelist_cfg_fn}")
        namelist_data = parse_nemo_namelist(namelist_cfg_fn)
    else:
        namelist_data = {}
    
    with open(timing_fn, "r", encoding="utf8") as timing_f:
        total_time = 0
        ts_per_second = 0
        n_functions_header = 0
        ts_length_seconds = 0

        for line in timing_f:
            step_length_match = re.search(step_length_ptrn, line)
            functions_header_match = re.search(functions_header_ptrn, line)
            functions_match = re.search(functions_ptrn, line)
            total_time_match = re.search(total_time_ptrn, line)

            if total_time == 0 and total_time_match:
                total_time = float(total_time_match.group(1))
            elif ts_per_second == 0 and step_length_match:
                data["time_step_time"] = float(step_length_match.group(1)) / 1e6
                ts_per_second = 1 / data["time_step_time"]
            elif functions_header_match: 
                n_functions_header += 1
            elif n_functions_header == 1 and functions_match:
                function_name, function_net_time = functions_match.groups()
                if function_name != "Section":
                    data["function_info"][function_name] = float(function_net_time)

        if "rn_Dt" in namelist_data:
            ts_length_seconds = float(namelist_data["rn_Dt"])
        if "nn_itend" in namelist_data:
            data["number_ts"] = float(namelist_data["nn_itend"])
        if ts_length_seconds > 0 and data["number_ts"] > 0:
            data["sypd"] = (ts_length_seconds * data["number_ts"]) / (365 * total_time)

        data["total_time"] = total_time
        data["ts_per_second"] = ts_per_second

    return data

def parse_nemo4_timing(timing_fn: str):
    step_length_ptrn = "timing step *([0-9]+) *: *(.*)"
    functions_ptrn = "([0-9a-zA-Z_]+) +" + "([0-9\.E\+\-]+) +" * 7 + "([0-9\.E\+\-]+)"
    total_time_ptrn = "Total *time : +{[0-9\.E\+]+} +\(SYPD: +([0-9\.E\+]+) +\) on +MPI +rank +: +{[0-9\.E\+}+)"

    data = {"function_info": {}, "time_step_time": 0,
            "number_ts": 0, "ts_per_second": 0, "sypd": 0}

    with open(timing_fn, "r", encoding="utf8") as timing_f:
        steps_length = []
        sypds = []
        number_ts = 1
        nproc = 0

        for i, line in enumerate(timing_f):
            step_length_match = re.search(step_length_ptrn, line)
            functions_match = re.search(functions_ptrn, line)
            total_time_match = re.search(total_time_ptrn, line)

            if step_length_match and i != 0:
                number_ts = int(step_length_match.group(1))
                steps_length.append(float(step_length_match.group(2)))
            elif functions_match:
                function_name = functions_match.groups()[0]
                values = [float(v) for v in functions_match.groups()[1:]]
                data["function_info"][function_name] = values[1]
            elif total_time_match:
                _, sypd, nproc = total_time_match.groups()
                sypds.append(float(sypd))

        data["time_step_time"] = np.average(steps_length)
        data["number_ts"] = number_ts
        data["ts_per_second"] = 1 / data["time_step_time"]
        data["sypd"] = np.average(sypds)
        data["nproc"] = int(nproc)

    return data

def parse_nemo_timing(timing_fn: str):
    version_ptrn = "version ([0-9\.]+)"
    nemo_major_version = None
    with open(timing_fn, "r", encoding="utf8") as timing_f:
        for line in timing_f:
            version_match = re.search(version_ptrn, line)
            if version_match:
                nemo_major_version = math.floor(float(version_match.group(1)))
                break

    print(f"[INFO][{timing_fn}] Detected NEMO major version: {nemo_major_version}")
    if nemo_major_version == 4:
        data = parse_nemo4_timing(timing_fn)
    elif nemo_major_version == 5:
        data = parse_nemo5_timing(timing_fn)
    else:
        raise ValueError(f"NEMO version {nemo_major_version} not supported")

    return data

def parse_ifs_file(file):
    """Parse an IFS (Input File System) statistics file to calculate timestamps per second.

    This function reads a file containing IFS statistics and calculates the average
    time per timestamp by dividing total accumulated time by total number of timestamps.

    Args:
        file (str): Path to the IFS statistics file to parse.

    Returns:
        dict: A dictionary containing:
            - ts_per_second (float): Average time per timestamp calculated from the file data.

    Note:
        The input file is expected to have space-separated columns where:
        - Column 4 (index 3) contains the timestamp number
        - Column 7 (index 6) contains the time value
    """
    data = {"ts_per_second": 0}
    with open(file, encoding="utf8") as f:
        total_time = 0
        total_ts = 1
        for line in f:
            cols = [s for s in line.split(" ") if s]
            ts_time = float(cols[6])
            total_time += ts_time
            total_ts = int(cols[3])
        data["ts_per_second"] = total_time / total_ts

    return data


def parse_dimemas_files(files):
    """
    Takes a list of filenames corresponding to outputs of paramedir runs applied to dimemas simulations
    and process it returning a dictionary with the data
    
    Args:
      files (str): List of filenames corresponding to outputs of paramedir runs applied to dimemas simulations.
    Returns:
      dict: A dictionary containing the processed data from the Dimemas files.
    """
    results = {}
    for filename in files:
        # Get core count and information type from filename
        cores, simulation_type, information_type = parse_dimemas_filename(
            filename)
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
                dictionary_section[function_name] = process_category_histogram(
                    histogram)
    return results


class TimingInformation:
    """
    TimingInformation class parses the input files and stores performance metrics from various sources.

    Args:
        timing_files (list, optional): List of timing files to load.
        lucia_files (list, optional): List of Lucia files to load.
        paramedir_files (list, optional): List of Paramedir files to load.
        dimemas_files (list, optional): List of Dimemas files to load.
        ifs_files (list, optional): List of IFS files to load.
        test_info_files (list, optional): List of test info files to load.
        processes_per_node (int, optional): Number of processes per node. Default is 48.
        json_file (str, optional): Path to a JSON file to load.
        param_file (str, optional): Path to a parameter file to load.
        components (list, optional): List of components to initialize.

    Raises:
        AssertionError: If none of the timing_files, lucia_files, paramedir_files, json_file, or dimemas_files are provided.
    """

    def __init__(self, timing_files: list=None, lucia_files: list=None, paramedir_files=None, dimemas_files=None, ifs_files=None, test_info_files=None,
                 processes_per_node: int=48, json_file=None, param_file=None, components=None):

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

        if (not timing_files) and (not lucia_files) and (not paramedir_files) and (not json_file) and (not dimemas_files) and (not ifs_files) and (not test_info_files):
            raise AssertionError("No files provided")

        # Update values with the provided files
        if json_file:
            self.load_json(json_file)
        if test_info_files:
            self.load_test_info(test_info_files)
        if timing_files:
            self.load_timings(timing_files)
            self.function_info_src = "timing"
        else:
            self.function_info_src = "paramedir"
        if lucia_files:
            self.load_lucia(lucia_files)
        if paramedir_files:
            self.load_paramedir(paramedir_files)
        if dimemas_files:
            self.load_dimemas(dimemas_files)
        if ifs_files:
            self.load_ifs(ifs_files)

    def __getitem__(self, item):
        return self.data[item]

    def find_functions(self) -> list:
        """
        Finds and returns a list of unique function names from the data structure.

        This method iterates over all cases and components, extracting function names
        from the "Time" counters in the data dictionary. It then flattens the list of
        function names and removes duplicates.

        Returns:
            list: A list of unique function names.
        """
        functions = []
        for case in self.cases:
            for component in self.components:
                functions.append(
                    list(self.data[case]["components"][component]["counters"]["Time"].keys()))
        functions = sum(functions, [])
        return list(set(functions))

    def get_function_info(self, component: str="") -> dict:
        """
        Retrieve function information for all cases available or for a specific component.

        This method creates a dictionary containing function information for each case.
        If a specific component is provided, it retrieves information only for that component.
        Otherwise, it retrieves information for all components.

        Args:
            component (str, optional): The name of the component to retrieve information for.
                                       If not provided, information for all components is retrieved.

        Returns:
            dict: A dictionary where keys are function names and values are dictionaries containing
                  case-specific information. Each case-specific dictionary contains:
                  - "nproc" (int): The number of processors used.
                  - "elapsed_time" (float): The elapsed time for the function in the given case.
        """
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
                    nproc = self[case]["components"][component_name]["nproc"]
                    ret_val[function][case] = {
                        "nproc": nproc, "elapsed_time": 0}
                    try:
                        # Store results in dictionary if present
                        ret_val[function][case]["elapsed_time"] = self[case]["components"][component_name]["function_info"][function]
                    except KeyError:
                        # Remove the entry and pass to the next function
                        del ret_val[function]
                        break
        return ret_val

    def load_test_info(self, test_info_files: list):
        """
        Load test information from a list of CSV files and update the internal data structure.

        Args:
            test_info_files (list of str): List of file paths to the CSV files containing test information.

        The CSV files are expected to have a specific format where each row represents a component's information.
        The filename should match the pattern "([0-9a-zA-Z_]+)-([0-9a-zA-Z_]*test_info).csv" to extract the run ID.

        The method updates the `self.data` dictionary with the parsed information. The structure of `self.data` is:
            {
            run_id: {
                "components": {
                    component_name: {
                        ...component-specific data...
                    },
                    ...
                },
                ...model-specific data...
            },
            ...
            }

        Additionally, it initializes `self.cases` and `self.base_case` if they are not already set, based on the number
        of processors (`nproc`). It also initializes `self.components_cases` for each component, sorted by the number
        of processors.
        """
        import csv

        for test_info_fn in test_info_files:
            test_dict = {}
            pattern = "([0-9a-zA-Z_]+)-([0-9a-zA-Z_]*test_info).csv"
            run_id, _ = parse_filename(test_info_fn, pattern)

            test_dict[run_id] = {"components": {}}
            with open(test_info_fn, mode="r", encoding="utf8") as test_info_f:
                reader = csv.DictReader(test_info_f)
                for dict_line in reader:
                    component_name = dict_line["component"]
                    dict_line.pop("component")
                    if component_name == "experiment":
                        test_dict.update(dict_line)
                    elif component_name == "model":
                        test_dict[run_id].update(dict_line)
                    else:
                        if not component_name in test_dict[run_id]["components"]:
                            test_dict[run_id]["components"][component_name] = {}
                        test_dict[run_id]["components"][component_name].update(dict_line)
            self.data = merge_dictionaries(self.data, test_dict)

        if self.cases is None:
            self.cases = list(
                sorted(self.data.keys(), key=lambda f: int(self.data[f]["nproc"])))
            self.base_case = self.cases[0]

        if self.components_cases is None:
            self.components_cases = {}
            for component in self.components:
                self.components_cases[component] = sorted(
                    self.data, key=lambda f: int(self.data[f]["components"][component]["nproc"]))


    def load_param(self, param_file) -> dict:
        """
        Load parameters from a given file and update the object's attributes.

        Args:
            param_file (str): Path to the parameter file.

        Returns:
            dict: A dictionary containing the parameters loaded from the file.

        Raises:
            AssertionError: If the parameter file does not exist.

        Notes:
            - Lines in the parameter file that contain '#' or are empty are ignored.
            - Parameters are expected to be in the format 'key=value'.
            - Values enclosed in single quotes are stripped of the quotes.
            - The 'processes_per_node' parameter, if present, updates the object's `processes_per_node` attribute.
            - The 'configuration_name' parameter, if present and if `experiment_name` is not already set, updates the object's `experiment_name` attribute.
        """
        from os.path import isfile
        if param_file is None:
            return None

        try:
            assert isfile(param_file)
        except AssertionError:
            raise AssertionError("parameter file %s not found", param_file)

        f = open(param_file, "r")
        param = [l.replace("\n", "")
                 for l in f if l.count("#") == 0 and l != "\n"]
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

    def scatter_plots(self, x_axis: str="L3", y_axis: str="IPC", length_summary: int=10):
        """
        Generates scatter plots of specified performance metrics for functions across different components.

        Args:
            x_axis (str): The performance metric to be plotted on the x-axis. Default is "L3".
            y_axis (str): The performance metric to be plotted on the y-axis. Default is "IPC".
            length_summary (int): The number of functions to track and plot. Default is 10.

        Raises:
            KeyError: If the specified function name is not present in the trace data.

        This method creates scatter plots for each component, showing the relationship between the specified
        performance metrics (x_axis and y_axis) for the tracked functions. The plots are saved as PNG files
        with filenames in the format "{component_name}-{x_axis}-{y_axis}.png".

        The method uses matplotlib to generate the plots and numpy for data manipulation. It also handles
        cases where function names might not be present in the trace data by skipping those functions.
        """
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
                for case in self.components_cases[component]:
                    try:
                        # Function name's are taken from timings, so it is possible they are not present in the trace
                        x_data = self.data[case]["components"][component]["counters"][x_axis][f_name]['Average']
                        y_data = self.data[case]["components"][component]["counters"][y_axis][f_name]['Average']
                    except KeyError:
                        # If the function was not tracked delete dictionary entry and skip to next function
                        del function_info[component][f_name]
                        n_function -= 1
                        break

                    # Add the data to the dictionary
                    function_info[component][f_name]['x'] += x_data
                    function_info[component][f_name]['y'] += y_data

        # Create the plot
        for component_name, component_function_info in function_info.items():
            output_name = component_name + "-" + x_axis + "-" + y_axis + ".png"

            fig, ax = plt.subplots()
            case_str = ""
            for i, case in enumerate(self.components_cases[component_name]):
                if i != 0:
                    case_str += " - "
                case_str += case
            ax.set_title(
                f"{x_axis} vs {y_axis} per 1000 instructions in {component_name}\n{case_str}")
            ax.set_xlabel(x_axis)
            ax.set_ylabel(y_axis)
            for i, f_name in enumerate(component_function_info):
                if f_name[0] == "_":
                    # Remove leading underscores that python does not know how to render
                    legend_name = re.sub('^_+', "", f_name)
                else:
                    legend_name = f_name
                x = component_function_info[f_name]['x']
                y = component_function_info[f_name]['y']
                u = np.diff(x)
                v = np.diff(y)
                pos_x = x[:-1]
                pos_y = y[:-1]

                c = np.full(len(x), i / len(component_function_info))
                ax.quiver(pos_x, pos_y, u, v, angles="xy", pivot="tail", headlength=2,
                          headaxislength=2, scale_units="xy", scale=1, color=plt.cm.tab20(c))
                ax.scatter(x, y, marker="o", label=legend_name,
                           c=plt.cm.tab20(c), edgecolors="black")

            if len(component_function_info) == 0:
                ax.text(
                    0.5, 0.5, f"{x_axis} vs {y_axis} not available", ha="center", va="center")

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

    def coupling_info(self, folder):
        return coupling_info(self, folder)

    def cases_component_data(self):
        return cases_component_data(self)

    def save_json(self, filename: str=None):
        """
        Save the current state of the object to a JSON file.

        Args:
            filename (str, optional): The name of the file to save the JSON data to. 
                        If not provided, the experiment name will be used 
                        as the filename with a .json extension. If the 
                        experiment name is also not available, 'experiment.json' 
                        will be used as the default filename.

        The JSON file will contain the following keys:
        - "experiment_name": The name of the experiment.
        - "data": The data associated with the experiment.
        - "cases": The cases related to the experiment.
        - "base_case": The base case of the experiment.
        - "processes_per_node": The number of processes per node.
        - "functions": The functions involved in the experiment.
        - "param_file": The parameter file used in the experiment.
        - "components": The components of the experiment.
        - "components_cases": The cases related to the components.

        The method will ensure that the filename has a .json extension before saving.
        """
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
            "components_cases": self.components_cases,
        }

        with open(filename, "w", encoding="utf8") as f:
            json.dump(dictionary_to_save, f)

    def load_json(self, filename: str):
        """
        Load and parse a JSON file, converting keys to integers where possible.

        Args:
            filename (str): The path to the JSON file to be loaded.

        Raises:
            KeyError: If any of the required keys are missing in the JSON file.

        Attributes:
            experiment_name (str): The name of the experiment.
            data (dict): The data from the JSON file.
            cases (dict): The cases from the JSON file.
            base_case (str): The base case from the JSON file.
            processes_per_node (int): The number of processes per node.
            functions (dict): The functions from the JSON file.
            components (dict): The components from the JSON file.
            components_cases (dict): The components cases from the JSON file.
            param_file (str, optional): The parameter file, if present in the JSON file.
        """
        import json

        def json_keys2int(x):
            if isinstance(x, dict):
                try:
                    return {int(k): v for k, v in x.items()}
                except ValueError:
                    return dict(x.items())
            return x

        with open(filename, "r", encoding="utf8") as f:
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

    def load_lucia(self, lucia_files: list):
        """
        Load and parse Lucia performance profiling data from a list of CSV files.

        This method reads multiple Lucia CSV files, extracts relevant performance data,
        and organizes it into a dictionary structure. The data is then merged with the
        existing data in the object.

        Args:
            lucia_files (list): A list of file paths to Lucia CSV files.

        Raises:
            re.error: If the regular expression pattern does not match the file path.

        Notes:
            - The method expects the file paths to follow a specific pattern:
              "(scalability)_([0-9a-zA-Z_]+)/(lucia_lite_results/*)".
            - The method renames certain component names for consistency:
              "oceanx" to "nemo" and "OpenIFS" to "oifs".
            - The method calculates and stores the "SYPD" (Simulated Years Per Day) value
              for both the overall case and individual components.
            - The method updates the `self.data` attribute with the merged data.
            - If `self.cases` is None, it initializes and sorts the cases based on the
              number of processors (`nproc`).
            - If `self.components_cases` is None, it initializes and sorts the component
              cases based on the number of processors (`nproc`).
        """
        import pandas as pd
        lucia_dict = {}
        for lucia_file in lucia_files:
            pattern = "([a-z0-9A-Z]+)_([0-9a-zA-Z_]+)/(lucia_lite_results/*)"
            _, id, _ = re.match(pattern, lucia_file).groups()
            lucia_df = pd.read_csv(lucia_file)
            lucia_dict[id] = {"components": {}}
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
                    lucia_dict[id]["components"][component] = row[1:].to_dict()
                    lucia_dict[id]["components"][component]["SYPD"] = lucia_dict[id]["components"][component]["sypd"]

        self.data = merge_dictionaries(self.data, lucia_dict)

        if self.cases is None:
            self.cases = list(
                sorted(self.data, key=lambda f: int(self.data[f]["nproc"])))
            self.base_case = self.cases[0]

        if self.components_cases is None:
            self.components_cases = {}
            for component in self.components:
                self.components_cases[component] = sorted(
                    self.data, key=lambda f: int(self.data[f]["components"][component]["nproc"]))

    def load_timings(self, timing_files: list):
        """
        Load timing data from a list of timing files and update the internal data structure.

        Args:
            timing_files (list of str): List of file paths to timing files. Each file name should follow the pattern
                        "component-run_id-timing.output".

        Raises:
            ValueError: If the file name does not match the expected pattern.

        Notes:
            This method processes each timing file, extracts the component and run ID from the file name, and parses the
            timing data. The parsed data is stored in a nested dictionary structure, where the top-level keys are run IDs
            and the second-level keys are component names. The timing data for each component is stored under its respective
            run ID.

            If there is only one component, the method merges the component data into the main data structure. It also
            initializes the `cases` and `components_cases` attributes if they are not already set.

            The `ts_per_second` value for each run ID is updated to be the minimum value across all components for that run ID.
        """
        # component-run_id-timing.output
        pattern = "([a-z]+)-([0-9a-zA-Z_]+)-timing.output"
        timing_dict = {}
        for timing_fn in timing_files:
            component, id = parse_filename(timing_fn, pattern)
            address = (id, "components")
            dictionary_section = dictionary_pointer(timing_dict, address)
            dictionary_section[component] = parse_nemo_timing(timing_fn)
            if "ts_per_second" in timing_dict[id]:
                timing_dict[id]["ts_per_second"] = min(
                    dictionary_section[component]["ts_per_second"], timing_dict[id]["ts_per_second"])
            else:
                timing_dict[id]["ts_per_second"] = dictionary_section[component]["ts_per_second"]

        self.data = merge_dictionaries(self.data, timing_dict)

        if len(self.components) == 1:
            for case in self.data:
                print(self.data[case])
                self.data[case] = merge_dictionaries(
                    self.data[case], list(self.data[case]["components"].values())[0])

            if self.cases is None:
                self.cases = list(
                    sorted(self.data.keys(), key=lambda f: int(self.data[f]["nproc"])))
                self.base_case = self.cases[0]

            if self.components_cases is None:
                self.components_cases = {}
                for component in self.components:
                    self.components_cases[component] = sorted(
                        self.data, key=lambda f: int(self.data[f]["nproc"]))

    def load_paramedir(self, files: list):
        """
        Load and process parameter directory files.

        This method takes a list of Paramedit files, parses them, and merges the resulting
        data with the existing data in the object. It also initializes cases,
        functions, and component function information based on the parsed data.

        Args:
            files (list): A list of Paramedir file paths to be parsed.

        Raises:
            AssertionError: If the provided list of files is empty.

        """
        if not files:
            raise AssertionError("Empty list of files")

        paramedir_info = parse_paramedir_files(files)
        self.data = merge_dictionaries(self.data, paramedir_info)

        if self.cases is None:
            self.cases = list(
                sorted(self.data.keys(), key=lambda f: int(self.data[f]["nproc"])))
            self.base_case = self.cases[0]

        self.functions = self.find_functions()

        if self.function_info_src == "paramedir":
            for case in self.cases:
                for component in self.components:
                    component_function_info = {}
                    component_dict = dictionary_pointer(
                        self.data, (case, "components", component))
                    for function_name in component_dict["counters"]["Time"]:
                        component_function_info[function_name] = component_dict["counters"]["Time"][function_name]["Average"][0]
                    component_dict["function_info"] = component_function_info

        if self.components_cases is None:
            self.components_cases = {}
            for component in self.components:
                self.components_cases[component] = sorted(
                    self.data, key=lambda f: int(self.data[f]["components"][component]["nproc"]))

    def load_ifs(self, files: list):
        """
        Load IFS timesteps timing data from a list of files and update the internal data structure.

        Args:
            files (list of str): List of file paths to be processed. Each file name should match the pattern 
                     "([a-z]+)-([0-9a-zA-Z_]+)-ifs.stat".

        Raises:
            AssertionError: If the provided list of files is empty.

        The method processes each file by:
            1. Parsing the file name to extract the component and id.
            2. Creating or updating a nested dictionary structure based on the id and component.
            3. Parsing the IFS file content and storing it in the dictionary.
            4. Updating the "ts_per_second" value for each id to be the minimum value found among its components.
            5. Merging the newly created dictionary with the existing internal data structure.
        """
        if not files:
            raise AssertionError("Empty list of files")
        pattern = "([a-z]+)-([0-9a-zA-Z_]+)-ifs.stat"
        ifs_dict = {}
        for file in files:
            component, id = parse_filename(file, pattern)
            address = (id, "components")
            dictionary_section = dictionary_pointer(ifs_dict, address)
            dictionary_section[component] = parse_ifs_file(file)
            if "ts_per_second" in ifs_dict[id]:
                ifs_dict[id]["ts_per_second"] = min(
                    dictionary_section[component]["ts_per_second"], self.data[id]["ts_per_second"])
            else:
                ifs_dict[id]["ts_per_second"] = dictionary_section[component]["ts_per_second"]

        self.data = merge_dictionaries(self.data, ifs_dict)

    def load_dimemas(self, files: list):
        """
        Load and parse Dimemas files, then merge the parsed data into the existing data.

        Args:
            files (list): A list of file paths to Dimemas files.

        Raises:
            AssertionError: If the provided list of files is empty.

        Updates:
            self.data (dict): Merges the parsed Dimemas data into the existing data.
            self.cases (list): Initializes with sorted keys from the merged data if not already set.
            self.base_case: Sets to the first case in the sorted list of cases if not already set.
        """
        if not files:
            raise AssertionError("Empty list of files")

        dimemas_info = parse_dimemas_files(files)
        self.data = merge_dictionaries(self.data, dimemas_info)

        if self.cases is None:
            self.cases = list(sorted(self.data.keys()))
            self.base_case = self.cases[0]
