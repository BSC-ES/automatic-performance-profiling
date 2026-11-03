"""
This module contains utility functions for curating and analyzing performance data from HPC
experiments.

Classes:
    Log: A simple class to store and manage text logs.

Functions:
    go_to_dictionary_address(dictionary, address): Navigate nested dictionaries using an
        address list.
    function_curated_summary(experiment_data, filename): Generate a summary of function scalability.
    dimemas_curated_summary(experiment_data): Create a summary of Dimemas simulation results.
    coupling_info(experiment_data, coupling_folder): Generate coupling information summaries.
    generate_most_expensive_function_summary_data(experiment_data, out_file_name,
        length_summary, component_to_report): Create summary of most time-consuming functions.
    most_expensive_function_summary(experiment_data, out_file_name, length_summary):
        Generate summaries for all components.
    function_info_csv(experiment_data, csv_folder): Save function performance data as CSV files.
    tracking_function_info(experiment_data): Generate tracking information for functions.
    function_information_from_paramedir_outputs(experiment_data, component): Extract
        function timing from Paraver outputs.
    tracking(experiment_data, folder, threshold): Generate tracking information for
        functions above threshold.
    tracking_mpi_profile_per_function(experiment_data, function, component): Generate MPI
        profile for specific function.
    tracking_counters_per_function(experiment_data, function, component): Generate
        hardware counter data for function.
    generate_sypd_summary_data(experiment_data, component): Generate simulated years per
        day summary.
    simulated_years_per_day_summary(experiment_data, filename): Create SYPD summary with metrics.
    generate_sypd_plot_data(experiment_data, component): Prepare data for SYPD plotting.
    simulated_years_per_day_plot(experiment_data, filename): Create plots of SYPD metrics.
    cases_component_data(experiment_data): Generate component-wise case information.
    experiment_comparison(experiment1, experiment2): Compare metrics between two experiments.
    multiexperiment_comparison(experiments, field1): Compare metrics across multiple
        experiments.
    generate_weakscaling_data(experiments, component_to_report): Generate weak scaling
        analysis data.
    weakscaling_compute(experiments, file_out): Compute weak scaling metrics.
    find_common_cases_and_functions(experiments): Identify common cases and functions across
        experiments.
    extract_data_from_experiments(experiments): Extract performance data from experiments.
    fit_step_time_to_model(experiments): Fit time step data to performance model.
    my_model(individual, data): Custom performance model implementation.
    fit_data_to_model(data, model): Fit data to specified model using optimization.
    genetic_optimizer(data, model): Genetic algorithm implementation for model fitting.
    custom_optimizer(data, model): Custom optimization algorithm for model fitting.
    fit_functions_to_model(experiments, function_name): Fit function performance to model.
    get_functions_data(experiments, function_name): Extract function-specific performance data.
    oversimplified_memory_model(experiments): Simple memory performance model analysis.

The module focuses on performance analysis of HPC applications, providing tools for:
- Function performance analysis
- MPI communication analysis
- Scalability studies
- Data visualization
- Performance modeling
"""

import numpy as np
from .plotting import plotter
from .scaling import higher_is_better


class Log:
    """A class to handle text logging with file output capabilities.

    This class provides functionality to accumulate text entries and output them
    either to the console or to a file. It supports both string concatenation
    and method-based text addition.

    Attributes:
        text (str): The accumulated log text.

    Methods:
        __add__(other, newline=True): Adds text to the log, with optional newline.
        add(text, newline=True): Wrapper method for __add__.
        print(file_out=None): Prints log content to console or saves to CSV file.
        save(filename=None): Saves log content to a file or prints to console.
    """

    def __init__(self):
        self.text = ""

    def __add__(self, other: str, newline: bool = True):
        """
        Add text to the current log entry.

        This method allows concatenation of text or another Log object to the current log,
        optionally adding a newline at the end.

        Args:
            other (Union[str, Log]): The text or Log object to append to the current log
            newline (bool, optional): Whether to append a newline character. Defaults to True.

        Returns:
            Log: Returns self for method chaining
        """
        if isinstance(other, Log):
            other = other.text
        self.text += other
        if newline:
            self.text += "\n"
        return self

    def add(self, text: str, newline: bool = True):
        """
        Adds text to the object.

        Args:
            text: The text to be added.
            newline (bool, optional): Whether to append a newline after the text. Defaults to True.

        Returns:
            None
        """
        self.__add__(text, newline)

    def print(self, file_out: str = None):
        """
        Print the contents of the text attribute to a file or stdout.

        This method handles the printing of text content either to a specified file
        (in CSV format) or to standard output if no file is specified.

        Args:
            file_out (str, optional): The path to the output file. If provided, the text
                will be written to this file. If the file extension '.csv' is not present,
                it will be automatically added. Defaults to None.

        Note:
            - If file_out is None, the text will be printed to stdout
            - Underscores in the text content are removed before writing/printing
        """
        if file_out is not None:
            if not file_out.count(".csv"):
                file_out = file_out + ".csv"
            with open(file_out, "wt") as f_output:
                self.text.replace("_", "")
                f_output.write(self.text)
        else:
            print(self.text)

    def save(self, filename: str = None):
        """Save the content of the object either by printing it to stdout or to a file.

        Args:
            filename (str, optional): Path to the output file. If None, prints to stdout. Defaults to None.

        Raises:
            IOError: If there are issues writing to the specified file.
        """
        if filename is None:
            self.print()
        else:
            with open(filename, "w") as f:
                f.write(self.text)


def go_to_dictionary_address(dictionary: dict, address: tuple[str]) -> dict:
    """
    Navigate through a nested dictionary using a list of keys (address).

    Args:
        dictionary (dict): The nested dictionary to navigate.
        address (list): A list of keys representing the path to the desired value.

    Returns:
        The value found at the specified address in the dictionary.

    Raises:
        AssertionError: If any key in the address does not exist in the dictionary.
    """

    def go_to_section(d: dict, section: str):
        try:
            return d[section]
        except KeyError:
            raise AssertionError(
                f"Provided address does not exists in this dictionary:\{address}"
            )

    for step in address:
        dictionary = go_to_section(dictionary, step)
    return dictionary


def function_curated_summary(experiment_data: dict, filename: str):
    """
    Generates a summary of function performance metrics from experiment data and saves it to a file.

    Args:
        experiment_data (dict): An object containing the experiment data, including components and their cases.
        filename (str): The name of the file where the summary will be saved.

    The summary includes:
        - Resources: The number of processors used in each case.
        - Speed-up: The speed-up achieved in each case compared to the base case.
        - Efficiency: The efficiency of resource usage in each case.
    """
    log = Log()

    for component in experiment_data.components:
        fun_results = experiment_data.get_function_info(component)
        for k, v in fun_results.items():
            resources = ""
            speedup = ""
            efficiency = ""

            base_case = experiment_data.components_cases[component][0]
            base_result = fun_results[k][base_case]["elapsed_time"]
            base_tasks = int(fun_results[k][base_case]["tasks"])
            for case in experiment_data.components_cases[component]:
                case_tasks = int(fun_results[k][case]["tasks"])
                case_speed = float(fun_results[k][case]["elapsed_time"])
                resource_increase = case_tasks / base_tasks
                resources += " %.2f" % case_tasks
                speedup += " %.2f" % (base_result / (case_speed + 1e-10))
                efficiency += " %.2f" % (
                    (base_result / (case_speed + 1e-10)) / resource_increase
                )

            log.add("%20s\tResources : %s" % (k, resources))
            log.add("%20s\tSpeed-up  : %s" % ("", speedup))
            log.add("%20s\tEfficiency: %s" % ("", efficiency))
            log.add("_" * 30)

    log.save(filename)


def dimemas_curated_summary(experiment_data: dict) -> Log:
    """
    Generates a curated summary of Dimemas experiment data.

    Args:
        experiment_data (dict): An object containing the experiment data.
            - cases: List of cases in the experiment.
            - base_case: The base case for comparison.
            - data: Nested dictionary containing the experiment data.

    Returns:
        Log: A Log object containing the curated summary of the Dimemas experiment data.

    The summary includes:
        - Wallclock time for each case and experiment.
        - The summary is formatted as a CSV string with cores and wallclock times.
    """

    log = Log()
    cases = experiment_data.cases
    base_case = experiment_data.base_case
    if "Dimemas" not in experiment_data[base_case]:
        print("[WARNING] No Dimemas data in the json; skipping the Dimemas summary")
        return log
    dimemas_experiments = list(experiment_data[base_case]["Dimemas"])
    information_types = list(
        experiment_data[base_case]["Dimemas"][dimemas_experiments[0]].keys()
    )
    information_types = ["Wallclock"]
    log_text = "Cores"
    for de in dimemas_experiments:
        log_text += f",{de}"
    log_text += "\n"

    for case in cases:
        log_text += f"{case}"
        for exp in dimemas_experiments:
            for it in information_types:
                address = (
                    case,
                    "Dimemas",
                    exp,
                    it,
                    "data",
                    "Maximum",
                )

                section = go_to_dictionary_address(experiment_data.data, address)
                wallclock_time = section[0] / 10.0**6
                log_text += f", {wallclock_time:.2f}"
        log_text += "\n"
    log.add(log_text)

    return log


def coupling_info(experiment_data: dict, coupling_folder: str):
    """
    Generate coupling information summary for experiment cases and saves it to CSV files.

    This function processes experiment data for each case, creating a summary table that includes
    performance metrics for individual components and the coupled model. The summary is saved
    as a CSV file in the specified coupling folder.

    Args:
        experiment_data (dict):
            Dictionary containing experiment data with the following structure:
            - cases: list of experiment cases
            - components: list of model components
            - data: nested dictionary with performance metrics for each case and component

    coupling_folder (str): Base directory path where the CSV files will be saved. A subfolder will be created for each case.

    Notes:
        The generated CSV files contain the following columns:
        - component: name of the component or 'coupled' for the coupled model
        - tasks: number of MPI tasks
        - chsy: chunking system information
        - cpl_cost: coupling cost
        - waiting_time: waiting time
        - interpo_time: interpolation time

        The function creates a directory for each case if it doesn't exist and saves
        the summary as 'summary.csv' within that directory.
    """
    import numpy as np
    import os

    for case in experiment_data.cases:
        columns = 6
        # components + model + header
        rows = len(experiment_data.components) + 2
        case_data = np.empty((rows, columns), "U25")
        case_data[0, :] = np.array(
            ["component", "tasks", "chsy", "cpl_cost", "waiting_time", "interpo_time"],
            dtype=str,
        )
        i = 1

        for component in experiment_data.components:
            component_dict = go_to_dictionary_address(
                experiment_data.data, (case, "components", component)
            )
            case_data[i, 0] = component
            for j in range(1, columns):
                case_data[i, j] = str(component_dict[case_data[0, j]])
            i += 1

        case_dict = experiment_data.data[case]
        case_data[i, 0] = "coupled"
        for j in range(1, columns):
            case_data[i, j] = str(case_dict[case_data[0, j]])

        case_folder = os.path.join(coupling_folder, case)
        os.makedirs(case_folder, exist_ok=True)
        np.savetxt(
            os.path.join(case_folder, "summary.csv"), case_data, delimiter=",", fmt="%s"
        )


def generate_most_expensive_function_summary_data(
    experiment_data, out_file_name, length_summary=10, component_to_report=""
):
    """
    Generate a CSV file containing a summary of the most expensive functions in terms of execution time.

    This function processes experiment data to identify and report the functions that consume
    the most execution time, calculating their percentage of the total execution time.

    Args:
        experiment_data: An object containing the performance profiling data with cases,
                        components, and function execution times.
        out_file_name (str): Path to the output CSV file where the summary will be written.
        length_summary (int, optional): Number of top expensive functions to include in the summary.
                                      Defaults to 10.
        component_to_report (str, optional): Specific component to analyze. If empty string,
                                           analyzes all components. Defaults to "".

    Returns:
        None. Writes results to a CSV file with the following columns:
        - function_name: Name of the function
        - case_name (percent): Percentage of total execution time for each case

    Note:
        The output CSV file will contain 'length_summary + 1' rows, with each row containing
        a function name and its percentage of total execution time for each case.
    """
    import csv
    from os.path import abspath

    header = []
    time_data = [[] for x in range(length_summary + 1)]
    function_names = [[] for x in range(len(experiment_data.cases))]
    components = [component_to_report]
    if component_to_report == "":
        components = experiment_data.components

    for case_idx, case in enumerate(experiment_data.cases):
        ts_length = 0
        for component in components:
            ts_length = max(
                float(
                    experiment_data.data[case]["components"][component][
                        "fastest_ts_time"
                    ]
                ),
                ts_length,
            )

        header.append("function_name")
        header.append(case + " (percent)")
        n_function = 0

        functions_elapsed_time = {}
        for component in components:
            functions_elapsed_time.update(
                go_to_dictionary_address(
                    experiment_data.data,
                    (case, "components", component, "fastest_ts_functions_time"),
                )
            )

        sorted_functions = list(
            sorted(functions_elapsed_time.items(), key=lambda f: f[1], reverse=True)
        )
        for function_name, elapsed_time in sorted_functions:
            if n_function < length_summary + 1:
                function_names[case_idx].append(function_name)
                time_data[n_function].append(function_name)
                uf_percentage = elapsed_time / ts_length * 100
                time_data[n_function].append(f"{uf_percentage:.2f}")
                n_function += 1
            else:
                break

    with open(out_file_name, mode="w", encoding="utf8") as output:
        out_writer = csv.writer(output, delimiter=",")
        out_writer.writerow(header)
        for func in range(length_summary + 1):
            out_writer.writerow(time_data[func])
        print("Written file in " + abspath(out_file_name))


def most_expensive_function_summary(
    experiment_data: dict, out_file_name: str, length_summary: int = 10
):
    """
    Generate summaries of the most expensive functions for both the entire experiment and individual components.

    Args:
        experiment_data (dict): Dictionary containing the experiment profiling data and component information.
        out_file_name (str): Base name for the output summary files.
        length_summary (int, optional): Number of top expensive functions to include in summaries. Defaults to 10.
    """
    generate_most_expensive_function_summary_data(
        experiment_data, out_file_name, length_summary
    )

    for component in experiment_data.components:
        generate_most_expensive_function_summary_data(
            experiment_data, component + "_" + out_file_name, length_summary, component
        )


def function_info_csv(experiment_data: dict, csv_folder: str) -> Log:
    """
    Generate CSV files containing performance metrics for functions in experiment data.

    Args:
        experiment_data (dict): Object containing experimental data with components and function information.
            Must have attributes 'components' and method 'get_function_info'.
        csv_folder (str): Path to the folder where CSV files will be saved. If the folder doesn't exist, it will be created.

    Returns:
        Log: A Log object tracking the execution of the function.

    Notes:
        The CSV files will be named as '{component}_{function}.csv' and will contain:
        - resources (tasks): Number of MPI tasks used
        - speedup: Ratio of base case time to current case time
        - efficiency: Speedup divided by resource increase ratio

    The base case is determined by the first case in the function results.
    """
    import numpy as np
    from os import mkdir
    from os.path import isdir

    if not isdir(csv_folder):
        mkdir(csv_folder)

    log = Log()

    for component in experiment_data.components:
        fun_results = experiment_data.get_function_info(component)

        for k in fun_results:

            resources = []
            speedup = []
            efficiency = []

            base_case = next(iter(fun_results[k]))
            base_case_tasks = int(fun_results[k][base_case]["tasks"])
            base_result = fun_results[k][base_case]["elapsed_time"]
            for case in fun_results[k].keys():
                tasks = int(fun_results[k][case]["tasks"])
                resource_increase = tasks / base_case_tasks
                resources.append(f"{tasks}")
                case_speedup = base_result / (
                    fun_results[k][case]["elapsed_time"] + 1e-10
                )
                case_efficiency = (
                    base_result / (fun_results[k][case]["elapsed_time"] + 1e-10)
                ) / resource_increase
                speedup.append(f"{case_speedup:.2f}")
                efficiency.append(f"{case_efficiency:.2f}")

            header = np.array(["resources (tasks)", "speedup", "efficiency"], dtype=str)

            data = np.empty((3, len(resources)))
            data[0, :] = resources
            data[1, :] = speedup
            data[2, :] = efficiency

            final_table = np.column_stack((header, data))
            np.savetxt(
                csv_folder + "/" + component + "_" + k + ".csv",
                final_table,
                delimiter=",",
                fmt="%s",
            )
    return log


def tracking_function_info(experiment_data: dict) -> Log:
    """
    Generate a log of function timing information from experiment data.

    This function creates a formatted log containing elapsed time information for different functions
    across various test cases.

    Args:
        experiment_data (dict): A dictionary containing experimental data with the following structure:
            - cases: List of test case names
            - functions: List of function names
            - Nested timing information accessible via case/function_info/function/Elap. Time(s) paths

    Returns:
        Log: A Log object containing CSV-formatted text with:
            - Headers showing test cases
            - Rows showing elapsed time for each function across test cases
            - Values formatted to 2 decimal places
    """
    log = Log()

    cases = experiment_data.cases
    functions = experiment_data.functions

    info_types = ["Elap. Time(s)"]

    for info_type in info_types:
        log_text = f"{info_type}"
        log_text += "," * len(cases) + "\n"
        log_text += "Functions"
        for case in cases:
            log_text += f",{case}"
        log_text += "\n"

        for function in functions:
            log_text += f"{function}"
            for case in cases:
                address = (
                    case,
                    "ts_function_info",
                    function,
                    info_type,
                )
                section = go_to_dictionary_address(experiment_data, address)
                log_text += f",{section:.2f}"
            log_text += "\n"

        log.add(log_text)
    return log


def function_information_from_paramedir_outputs(
    experiment_data: dict, component: str
) -> tuple[str, dict]:
    """
    Extracts timing information from ParamEDIR experiment outputs for a specific component.
    Args:
        experiment_data (dict): Dictionary containing the experiment data from ParamEDIR
        component (str): Name of the component to analyze

    Returns:
        tuple[str, dict]: A tuple containing:
            - total_time (float): Sum of execution times for all functions in the component
            - functions_time (dict): Dictionary mapping function names to their execution times
    """
    base_case = experiment_data.base_case
    address = (base_case, "components", component)
    component_dictionary = go_to_dictionary_address(experiment_data, address)
    functions_time = {}
    total_time = 0
    for function_name in component_dictionary["counters"]["Time"]:
        function_time = component_dictionary["counters"]["Time"][function_name][
            "Average"
        ][0]
        functions_time |= {function_name: function_time}
        total_time += function_time

    return total_time, functions_time


def tracking(experiment_data, folder, threshold=0.01):
    """
    Process and track performance data for functions in experiment components.

    This function analyzes experiment data, filters functions based on a time threshold,
    and generates MPI and counter logs for the significant functions.

    Args:
        experiment_data: Object containing experimental performance data and components
        folder (str): Base output directory path for storing the generated logs
        threshold (float, optional): Minimum fraction of total time a function must represent
            to be included in analysis. Defaults to 0.01 (1%)

    Creates:
        - {folder}/MPI/: Directory containing MPI profile logs per function
        - {folder}/counters/: Directory containing counter logs per function
        Each log is saved as CSV in format: {component}_{function}.csv

    Notes:
        - Only functions consuming >= threshold % of total time are analyzed
        - Creates separate MPI and counter logs for each significant function
        - Combines all logs into a full log (currently commented out printing)

    Returns:
        None
    """
    from os import makedirs
    from os.path import abspath

    MPI_folder = folder + "/MPI"
    counters_folder = folder + "/counters"
    makedirs(MPI_folder, exist_ok=True)
    makedirs(counters_folder, exist_ok=True)
    full_log = Log()
    for component in experiment_data.components:
        total_time, functions_time = function_information_from_paramedir_outputs(
            experiment_data, component
        )
        functions = [
            function
            for function, time in functions_time.items()
            if time / total_time >= threshold
        ]

        for function in functions:
            MPI_log = Log()
            counters_log = Log()
            mpi_profile = tracking_mpi_profile_per_function(
                experiment_data, function, component
            )
            counters = tracking_counters_per_function(
                experiment_data, function, component
            )

            if mpi_profile:
                MPI_log += mpi_profile
                MPI_log.save(f"{MPI_folder}/{component}_{function}.csv")
                full_log += mpi_profile

            if counters:
                counters_log += counters
                counters_log.save(f"{counters_folder}/{component}_{function}.csv")
                full_log += counters_log



def tracking_mpi_profile_per_function(
    experiment_data: dict, function: str, component: str
) -> Log:
    """
    Extract and format MPI profiling data for a specific function from experiment data.

    Args:
        experiment_data (dict): Dictionary containing all experiment data including MPI profiles
        function (str): Name of the function to analyze
        component (str): Name of the component to analyze

    Returns:
        Log: A Log object containing formatted MPI profile data with the following format:
            - First line: Header with "Cores" and MPI operation names
            - Subsequent lines: Case number followed by time spent in each MPI operation
    """
    base_case = experiment_data.base_case
    address = (
        base_case,
        "components",
        component,
        "counters",
        "MPIcallprofile",
    )
    mpi_dictionary = go_to_dictionary_address(experiment_data, address)
    mpi_fields = list(mpi_dictionary[function]["names"])
    mpi_fields_to_keep = (
        "Outside_MPI",
        "MPI_Recv",
        "MPI_Isend",
        "MPI_Wait",
        "MPI_Bcast",
        "MPI_Barrier",
        "MPI_Allreduce",
        "MPI_Iallreduce",
    )

    mpi_indices_to_keep = [
        index for index, value in enumerate(mpi_fields) if value in mpi_fields_to_keep
    ]
    cases = experiment_data.cases

    log = Log()
    log_txt = "Cores"
    for index, field in enumerate(mpi_fields):
        if index not in mpi_indices_to_keep:
            continue
        log_txt += f",{field}"
    log.add(log_txt)
    for case in cases:
        log_txt = f"{case}"
        address = (
            case,
            "components",
            component,
            "counters",
            "MPIcallprofile",
            function,
            "Average",
        )
        data = go_to_dictionary_address(experiment_data, address)
        for index, field in enumerate(mpi_fields):
            if index not in mpi_indices_to_keep:
                continue
            log_txt += f",{data[index]:.2f}"
        log.add(log_txt)
    return log


def tracking_counters_per_function(
    experiment_data: dict, function: str, component: str
) -> Log:
    """
    Tracks and logs performance counters for a specific function within a given component across different cases in an experiment.

    Args:
        experiment_data (dict): The data from the experiment, containing base case and cases information.
        function (str): The name of the function to track.
        component (str): The component within which the function resides.

    Returns:
        Log: A log object containing the tracked performance counters for the specified function and component.

    Raises:
        AssertionError: If the address within the dictionary does not exist.
    """
    log = Log()
    base_case = experiment_data.base_case
    cases = experiment_data.cases
    address = (base_case, "components", component, "counters")
    counters_dictionary = go_to_dictionary_address(experiment_data, address)
    available_counters = list(counters_dictionary.keys())
    available_counters = ["Instructions", "Cycles", "IPC", "Time"]
    labels = ["Instructions", "Cycles", "IPC", "Time(ms)"]

    log_text = "Processes"
    for index, counter in enumerate(available_counters):
        log_text += f",{labels[index]}"
    log.add(log_text)

    for case in cases:
        log_text = f"{case}"
        for counter in available_counters:
            address = (
                case,
                "components",
                component,
                "counters",
                counter,
                function,
                "Average",
            )
            try:
                section = go_to_dictionary_address(experiment_data, address)
            except AssertionError:
                log_text += ","
                continue
            data = section[0]
            log_text += f", {data:.1f}"

        log.add(log_text)

    return log


def generate_scalability_summary(
    experiment_data: dict, component: str = "", scalability_variable: str = "sypd"
) -> Log:
    """
    Generates a summary of scalability data for a given experiment.

    Args:
        experiment_data (dict): A dictionary containing the experiment data.
        component (str, optional): The specific component to generate the summary for. Defaults to an empty string,
                               which means the summary will be generated for the entire experiment.
        scalability_variable (str, optional): The name of the variable to use for the summary. Defaults to "sypd".

    Returns:
        Log: A Log object containing the summary data with columns: Case, Tasks, Threads, {scalability_variable.capitalize()}, SpeedUp, Efficiency.

        The summary includes:
        - Case: The name of the case.
        - Tasks: The number of MPI tasks used in the case.
        - Threads: The number of OpenMP threads per task (defaults to 1 when not reported).
        - {scalability_variable.capitalize()}: The {scalability_variable} value for the case,
          followed by its standard deviation across splits when the case reports them.
        - SpeedUp: The speedup factor compared to the base case. Derived from the direction of
          the metric: base/case when lower is better (e.g. "time"), case/base otherwise
          (e.g. "sypd", "sdpd").
        - Efficiency: The efficiency of the case, calculated as speedup divided by the increase in
          total compute resources (tasks × threads).

        Cases without a positive value (a run that produced no timing data) are left out of the
        summary, and so are all of them when the base case has no value to compare against.
    """
    log = Log()

    if component == "":
        base_case = experiment_data.base_case
        base_case_data = experiment_data.data[base_case]
        cases = experiment_data.cases
    else:
        cases = experiment_data.components_cases[component]
        base_case = cases[0]
        address = (base_case, "components", component)
        base_case_data = go_to_dictionary_address(experiment_data.data, address)

    base_case_tasks = int(base_case_data["tasks"])
    base_case_threads = int(base_case_data.get("threads", 1))
    base_case_speed = float(base_case_data.get(scalability_variable, 0.0))
    base_case_total_resources = int(base_case_data.get("total_resources", base_case_tasks))

    log.add(
        "Case, Total Resources, Tasks, Threads, "
        + scalability_variable.capitalize()
        + ", SpeedUp, Efficiency"
    )
    for case in cases:
        if component == "":
            case_data = experiment_data.data[case]
        else:
            address = (case, "components", component)
            case_data = go_to_dictionary_address(experiment_data.data, address)
        speed = float(case_data.get(scalability_variable, 0.0))
        if speed <= 0 or base_case_speed <= 0:
            print(
                f"[WARNING] {case} has no {scalability_variable} value, "
                "it is left out of the scalability summary"
            )
            continue
        case_tasks = int(case_data["tasks"])
        case_threads = int(case_data.get("threads", 1))
        case_total_resources = int(case_data.get("total_resources", case_tasks))
        resource_increase = case_total_resources / base_case_total_resources
        if higher_is_better(scalability_variable):
            speedup = speed / base_case_speed
        else:
            speedup = base_case_speed / speed
        efficiency = speedup / resource_increase

        speed_str = f"{speed:.1f}"
        split_values = [
            float(split[scalability_variable])
            for split in case_data.get("splits", [])
            if scalability_variable in split
        ]
        if split_values:
            speed_str += f" ± {np.std(split_values):.2f}"

        log.add(f"{case}, {case_total_resources}, {case_tasks}, {case_threads}, {speed_str}, {speedup:.1f}, {efficiency:.2f}")

    return log


def scalability_summary(
    experiment_data: dict, filename: str, scalability_variable: str = "sypd"
):
    """
    Generates and saves a summary of scalability metrics for the given experiment data.

    This function creates a summary of the scalability metrics for the entire model and for each component
    within the experiment data. The summaries are saved to the specified filename.

    Args:
        experiment_data (dict): A dictionary containing the experiment data, including components.
        filename (str): The base filename to save the summary data.
        scalability_variable (str, optional): The name of the variable to use for the summary. Defaults to "sypd".

    Returns:
        None
    """
    model_scalability_summary = generate_scalability_summary(
        experiment_data, scalability_variable=scalability_variable
    )
    model_scalability_summary.save(filename)

    for component in experiment_data.components:
        component_scalability_summary = generate_scalability_summary(
            experiment_data, component, scalability_variable=scalability_variable
        )
        component_scalability_summary.save(component + "_" + filename)


def generate_scalability_plot_data(
    experiment_data: dict, component: str = "", scalability_variable: str = "sypd"
) -> dict:
    """
    Generate plot data for scalability performance metric.

    This function processes experiment data to create a dictionary containing x and y values
    for plotting scalability performance against number of processes. It can process either full
    experiment data or data for a specific component.

    Args:
        experiment_data (dict): Dictionary containing experiment data with the following structure:
            - cases: List of case names
            - components_cases: Dictionary mapping component names to their cases
            - data: Dictionary containing performance data for each case

        component (str, optional): Name of the component to analyze. If empty string,
            processes full experiment data. Defaults to "".
        scalability_variable (str, optional): Name of the variable to extract for plotting. Defaults to "sypd".

    Returns:
        dict: Dictionary containing plot data with the following keys:
            - "Number of processes": numpy array of process counts
            - "{scalability_variable.capitalize()}": numpy array of {scalability_variable} values
    """
    x_label = "Number of processes"
    y_label = f"{scalability_variable.capitalize()} "
    plot_data = {x_label: np.empty(0), y_label: np.empty(0)}

    if component == "":
        cases = experiment_data.cases
    else:
        cases = experiment_data.components_cases[component]

    for case in cases:
        if component == "":
            case_data = experiment_data.data[case]
        else:
            address = (case, "components", component)
            case_data = go_to_dictionary_address(experiment_data.data, address)
        speed = float(case_data[scalability_variable])
        case_tasks = int(case_data["tasks"])
        plot_data[x_label] = np.append(plot_data[x_label], case_tasks)
        plot_data[y_label] = np.append(plot_data[y_label], speed)

    return plot_data


def scalability_plot(
    experiment_data: dict,
    filename: str,
    scalability_variable: str = "sypd",
    error_bars: bool = False,
):
    """
    Generates and saves plots for scalability data.

    This function creates a plot for the overall experiment data and individual
    component data within the experiment. It uses the `plotter` function from
    the `src.plotting` module to generate the plots.

    Args:
        experiment_data (dict): An object containing the experiment data,
            including the experiment name, cases, and components.
        filename (str): The filename to save the overall plot.

    Returns:
        None
    """
    from .plotting import plotter

    plotter(
        data=[experiment_data],
        error_bars=True,
        y_label=scalability_variable,
        x_label="total_resources",
        x_axis_label="Total resources (tasks x threads)",
        filename=filename,
        highlight_outliers=True,
    )

    for component in experiment_data.components:
        plotter(
            data=[experiment_data],
            error_bars=True,
            y_label=scalability_variable,
            x_label="total_resources",
            x_axis_label="Total resources (tasks x threads)",
            filename=component + "_" + filename,
            highlight_outliers=True,
        )


def cases_component_data(
    experiment_data: dict, variables_to_report: list[str] = ["tasks"]
):
    """
    Creates a CSV file containing information about the number of MPI tasks
    used by each component in different experiment cases.

    Args:
        experiment_data (dict): Dictionary containing information about experiment cases and components.
            Expected to have the following attributes:
                - components: List of component names
                - cases: List of case names
            And dictionary-like access with structure:
                experiment_data[case]["components"][component]["tasks"]

    Returns:
        None. Creates a file named 'cases_info.csv' with the following format:
            Case,COMPONENT1 tasks,COMPONENT2 tasks,...
            case1,nproc1,nproc2,...
            case2,nproc1,nproc2,...
    """
    log = Log()

    header = "Case"
    for component in experiment_data.components:
        for variable in variables_to_report:
            if len(experiment_data.components) > 1:
                header += f",{component.upper()} "
            else:
                header += ","
            header += f"{variable}"
    log.add(header)

    for case in experiment_data.cases:
        row = case
        for component in experiment_data.components:
            component_values = experiment_data[case]["components"][component]
            for variable in variables_to_report:
                if variable in component_values:
                    row += f",{component_values[variable]}"
                else:
                    row += ",-"
        log.add(row)

    log.save("cases_info.csv")


def experiment_comparison(experiment1: dict, experiment2: dict) -> Log:
    """
    Compare the performance of two experiments based on their cases.

    This function compares the simulated years per day (SYPD) and time-step length
    for each case in the given experiments. It logs the speed, speedup, efficiency,
    and ratio of the two experiments for each case.

    Args:
        experiment1 (dict): The first experiment data, where keys are case identifiers
                            and values are dictionaries containing "sypd" and "avg_ts_time".
        experiment2 (dict): The second experiment data, with the same structure as experiment1.

    Returns:
        Log: A log object containing the comparison results.
    """
    cases_to_compare = list(
        sorted([c for c in experiment1.cases if c in experiment2.cases])
    )
    base_case = min(cases_to_compare)
    log = Log()

    exp1_base_case_speed = experiment1[base_case]["sypd"]
    exp2_base_case_speed = experiment2[base_case]["sypd"]
    ratio = exp2_base_case_speed / exp1_base_case_speed
    log.add(
        "Base case experiment %4i processes  speed :  %5.1f|%5.1f SYPD                                                    -> %.2f ratio.  "
        % (base_case, exp1_base_case_speed, exp2_base_case_speed, ratio)
    )
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_speed = experiment1[case]["sypd"]
        exp1_speedup = exp1_speed / exp1_base_case_speed
        exp1_efficiency = exp1_speedup / resource_increase
        exp2_speed = experiment2[case]["sypd"]
        exp2_speedup = exp2_speed / exp2_base_case_speed
        exp2_efficiency = exp2_speedup / resource_increase
        ratio = exp2_speed / exp1_speed

        log.add(
            "                     %4i processes  speed :  %5.1f|%5.1f SYPD   SpeedUp:   %4.1fx |%4.1fx   Efficiency: %4.2f|%4.2f  -> %.2f ratio."
            % (
                case,
                exp1_speed,
                exp2_speed,
                exp1_speedup,
                exp2_speedup,
                exp1_efficiency,
                exp2_efficiency,
                ratio,
            )
        )
    exp1_base_length = experiment1[base_case]["avg_ts_time"]
    exp2_base_length = experiment2[base_case]["avg_ts_time"]
    log.add("_" * 30)
    log.add(
        "Base time-step length(s) with %4i processes:    %4.2f | %4.2f"
        % (base_case, exp1_base_length, exp2_base_length)
    )
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_length = experiment1[case]["avg_ts_time"]
        exp2_length = experiment2[case]["avg_ts_time"]
        log.add(
            "                              %4i processes:    %4.2f | %4.2f"
            % (case, exp1_length, exp2_length)
        )
    return log


def multiexperiment_scalability_plot(
    experiments: list, filename: str, scalability_variable: str = "sypd"
):
    plotter(
        data=experiments,
        filename=filename,
        highlight_outliers=False,
        plot_ideal=False,
        y_label=scalability_variable,
        x_label="total_resources",
        x_axis_label="Total resources (tasks x threads)",
        scatter_labels=False,
        error_bars=True,
    )


def multiexperiment_comparison(
    experiments: list, scalability_variable: str = "sypd"
) -> Log:
    """
    Compare multiple experiment results based on a specified field.

    This function analyzes multiple experiments and creates a comparison table of their
    performance metrics for cases with matching total compute resources.

    Args:
        experiments (list): List of TimingInformation objects to compare
        scalability_variable (str): Name of the variable to compare between experiments (e.g. 'sypd')

    Returns:
        Log: A Log object containing the formatted comparison table with the following format:
            - Header row with experiment names
            - Rows for each case showing the scalability_variable value for each experiment

    Notes:
        - Cases are considered matching if they use the same total resources
          (``total_resources = tasks × threads``, with threads defaulting to 1).
    """
    log = Log()

    corresponding_cases = [["" for _ in experiments] for _ in experiments[0].cases]
    for i, case in enumerate(experiments[0].cases):
        current_resources = int(experiments[0][case]["total_resources"])
        corresponding_cases[i][0] = case
        for j, experiment in enumerate(experiments[1:]):
            for case in experiment.cases:
                if int(experiment[case]["total_resources"]) == current_resources:
                    corresponding_cases[i][j + 1] = case
                    break

    header = "Resources (tasks x threads)"
    for i, experiment in enumerate(experiments):
        header += f", {experiment.experiment_name} {scalability_variable}"
        if i > 0:
            header += " (diff percent)"

    log.add(header)

    for i, case in enumerate(experiments[0].cases):
        case_row = f"{experiments[0][case]['total_resources']}"
        for j, experiment in enumerate(experiments):
            # If there is no corresponding case in the experiment with the same
            # total resources, set invalid value
            exp_speed = -1
            if corresponding_cases[i][j] != "":
                exp_speed = float(
                    experiment[corresponding_cases[i][j]][scalability_variable]
                )
                case_row += f", {exp_speed:.2f}"

                if "splits" in experiment[corresponding_cases[i][j]]:
                    exp_stdev = np.std(
                        [float(split[scalability_variable]) for split in experiment[corresponding_cases[i][j]]["splits"]]
                    )
                    case_row += f" ± {exp_stdev:.2f}"

                if j > 0:
                    base_exp_speed = float(float(experiments[0][corresponding_cases[i][0]][scalability_variable]))
                    exp_diff = (exp_speed - base_exp_speed) / base_exp_speed * 100 if base_exp_speed != 0 else 0
                    case_row += f" ({exp_diff:+.2f})"
            else:
                case_row += ", NA"
        log.add(case_row)

    return log


def generate_weakscaling_data(experiments: list, component_to_report: str = "") -> Log:
    """Generates a log containing weak scaling data from a list of experiments.

    Args:
        experiments (list): List of experiment objects containing performance data.
        component_to_report (str, optional): Specific component to generate report for.
        If empty, reports data for all components. Defaults to "".

    Note:
        The function handles two reporting modes:
        1. All components (component_to_report=""): Reports resolution and grid points for each component
        2. Single component: Reports cores, resolution, timesteps/second, and grid points
    """
    log = Log()

    if component_to_report == "":
        header = "Config"
        for component in experiments[0].components:
            header += f", {component.upper()} Res, {component.upper()} Pts"
    else:
        header = "Config, Ncores, Resolution, Ts per second, Gridpoints"

    log.add(header)

    for experiment in experiments:
        for case, case_dict in experiment.data.items():
            conf = f"{case}"

            if component_to_report == "":
                case_metrics = case_dict
                log.add(f"{conf}", False)
                for component in experiments[0].components:
                    resolution = case_metrics["components"][component]["resolution"]
                    grid_points = case_metrics["components"][component]["grid_points"]
                    log.add(f", {resolution}, {grid_points}", False)
                log.add("")
            else:
                case_metrics = go_to_dictionary_address(
                    case_dict, ("components", component_to_report)
                )
                grid_points = case_metrics["grid_points"]
                resolution = case_metrics["resolution"]
                tasks = case_metrics["tasks"]
                ts_per_second = float(case_metrics["ts_per_second"])

                log.add(
                    f"{conf}, {tasks}, {resolution}, {ts_per_second:.2f}, {grid_points}"
                )

    return log


def weakscaling_compute(experiments: list, file_out: str) -> None:
    import os

    model_ws_data = generate_weakscaling_data(experiments)
    model_ws_data.save(file_out)

    components = experiments[0].components
    for component in components:
        dn = os.path.dirname(file_out)
        fn = component + "_" + os.path.basename(file_out)
        component_ws_data = generate_weakscaling_data(experiments, component)
        component_ws_data.save(os.path.join(dn, fn))


def find_common_cases_and_functions(experiments):
    common_cases = set(experiments[0].cases)
    for experiment in experiments[1:]:
        common_cases.intersection_update(experiment.cases)
    common_cases = list(common_cases)
    base_case = min(common_cases)

    common_functions = set(experiments[0][base_case]["total_sim_functions_time"].keys())
    for experiment in experiments[1:]:
        common_functions.intersection_update(
            experiment[base_case]["total_sim_functions_time"].keys()
        )
    common_functions = list(common_functions)

    return common_cases, common_functions


def extract_data_from_experiments(experiments):
    from math import ceil

    data = []
    for experiment in experiments:
        for case in experiment.cases:
            to_append = (
                ceil(case / experiment.processes_per_node),
                case,
                experiment[case]["avg_ts_time"],
            )
            data.append(to_append)
    return data


def fit_step_time_to_model(experiments):
    data = extract_data_from_experiments(experiments)
    return fit_data_to_model(data, model=my_model)


def my_model(individual, data):
    import numpy as np

    def time_model(parameter_set, nn, nc):
        A, B, C, D, E = parameter_set
        return A / nn + B / nc + C * np.log(nn) + D * np.log(nc) + E

    def error(parameter_set, experiment_data):
        nn, nc, t = experiment_data
        return (t - time_model(parameter_set, nn, nc)) ** 2

    fitness = 0
    for case in data:
        fitness -= error(individual, case)
    for element in individual:
        if element < 0:
            fitness -= 100000000000
    return fitness


def fit_data_to_model(data, model):
    genetic = True
    if genetic:
        return genetic_optimizer(data, model)
    else:
        return custom_optimizer(data, model)


def genetic_optimizer(data, model):
    from pyeasyga import pyeasyga
    import numpy as np

    ga = pyeasyga.GeneticAlgorithm(
        data,
        elitism=True,
        population_size=100,
        generations=400,
        crossover_probability=0.4,
        mutation_probability=0.5,
    )
    max_time = max([x[2] for x in data])

    def create_individual(data):
        return np.random.uniform(0, max_time, size=5)

    def crossover(parent_1, parent_2):
        parent_1, parent_2 = parent_1.tolist(), parent_2.tolist()
        crossover_index = np.random.randint(0, len(parent_1))
        child_1, child_2 = parent_1, parent_2
        child_1[crossover_index], child_2[crossover_index] = (
            child_2[crossover_index],
            child_1[crossover_index],
        )
        child_1, child_2 = np.array(child_1), np.array(child_2)
        return child_1, child_2

    def mutate(individual):
        index = np.random.randint(0, len(individual))
        individual[index] += np.random.normal(0.05)
        return individual

    ga.fitness_function = model
    ga.create_individual = create_individual
    ga.crossover_function = crossover
    ga.mutate_function = mutate

    ga.run()
    return ga.best_individual()


def custom_optimizer(data, model):
    import numpy as np
    from copy import deepcopy

    max_time = max([x[2] for x in data])

    def create_individual(data):
        return np.random.uniform(0, max_time, size=5)

    my_individual = create_individual(data)
    my_fitness = model(my_individual, data)
    print(my_individual, my_fitness)

    iterations_without_improving = 0
    for i in range(1000000):
        test_individual = deepcopy(my_individual)
        test_individual += np.random.normal(scale=0.01, size=len(my_individual))
        test_fitness = model(test_individual, data)
        if test_fitness > my_fitness:
            my_fitness = test_fitness
            my_individual = deepcopy(test_individual)
            iterations_without_improving = 0
        else:
            iterations_without_improving += 1
        if iterations_without_improving > 1000:
            break
    print(my_individual, my_fitness)
    return my_fitness, my_individual


def fit_functions_to_model(experiments, function_name=None):
    data = get_functions_data(experiments, function_name)
    model_parameters = fit_data_to_model(data, model=my_model)
    return model_parameters


def get_functions_data(experiments, function_name=None):
    from math import ceil

    fun_key = "total_sim_functions_time"
    data = []
    for experiment in experiments:
        base_case = experiment.base_case
        if function_name is None:
            my_fun = list(experiment.data[base_case][fun_key].labels())[0]
        else:
            my_fun = function_name
        for case in experiment.cases:
            to_append = (
                ceil(case / experiment.processes_per_node),
                case,
                experiment[case][fun_key][my_fun]["Elap. Time(s)"],
            )
            data.append(to_append)
    return data


def oversimplified_memory_model(experiments):
    model_parameters = fit_step_time_to_model(experiments)
    error, parameters = model_parameters
    import numpy as np

    error = np.sqrt(abs(error))
    mb, cb, nc, cc, r = parameters
    cb = cb / 48.0
    tt = mb + cb + nc + cc + r
    print("Overall model:")
    print(
        "MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%"
        % (100.0 * mb / tt, 100.0 * cb / tt, 100.0 * error / tt)
    )
    print("Top10 Functions:")
    functions = list(
        experiments[0]
        .data[experiments[0].base_case]["total_sim_functions_time"]
        .labels()
    )
    functions = functions[:10]
    for function in functions:
        error, parameters = fit_functions_to_model(experiments, function_name=function)
        error = np.sqrt(abs(error))
        mb_time, cb_time, internode, intranode, residual = parameters
        cb_time = cb_time / 48
        total_time = mb_time + cb_time + internode + intranode + residual
        print(
            "Function: %20s\tTime(s): %.1f\t MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%"
            % (
                function,
                total_time,
                100.0 * mb_time / total_time,
                100.0 * cb_time / total_time,
                100.0 * abs(error / total_time),
            )
        )
