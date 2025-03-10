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


class Log:
    """
    Object to store the Logs (info to be printed).
    Probably there's an existing and better way of doing it.
    """

    def __init__(self):
        self.text = ""

    def __add__(self, other, newline = True):
        if isinstance(other, Log):
            other = other.text
        self.text += other
        if newline:
            self.text += "\n"
        return self

    def add(self, text, newline = True):
        self.__add__(text, newline)

    def print(self, file_out=None):
        if file_out is not None:
            if not file_out.count(".csv"):
                file_out = file_out + ".csv"
            with open(file_out, 'wt') as f_output:
                self.text.replace("_", "")
                f_output.write(self.text)
        else:
            print(self.text)

    def save(self, filename=None):
        if filename is None:
            self.print()
        else:
            with open(filename, "w") as f:
                f.write(self.text)


def go_to_dictionary_address(dictionary, address):
    """
    It creates the proper dictionary structure according to an address provided.
    In case the proper structure already exists it only retrieves it.
    :param dictionary:
    :param address:
    :return: dictionary section
    """

    def go_to_section(d, section):
        try:
            return d[section]
        except KeyError:
            raise AssertionError(
                f"Provided address does not exists in this dictionary:\{address}")

    for step in address:
        dictionary = go_to_section(dictionary, step)
    return dictionary


def function_curated_summary(experiment_data, filename):
    """
    This is an example of a function to curate the results and return something understandable
    :param experiment_data:
    :return: text with a summary of functions scalability in the experiment.
    """
    log = Log()
    # Get the dictionary of function

    for component in experiment_data.components:
        fun_results = experiment_data.get_function_info(component)
        for k, v in fun_results.items():
            resources = ""
            speedup = ""
            efficiency = ""

            base_case = experiment_data.components_cases[component][0]
            base_result = fun_results[k][base_case]["elapsed_time"]
            base_nproc = int(fun_results[k][base_case]["nproc"])
            for case in experiment_data.components_cases[component]:
                case_nproc = int(fun_results[k][case]["nproc"])
                case_speed = float(fun_results[k][case]["elapsed_time"])
                resource_increase = case_nproc / base_nproc
                resources += " %.2f" % case_nproc
                # Avoid dividing by zero
                speedup += " %.2f" % (base_result / (case_speed + 1e-10))
                efficiency += " %.2f" % ((base_result /
                                         (case_speed + 1e-10)) / resource_increase)

            log.add("%20s\tResources : %s" % (k, resources))
            log.add("%20s\tSpeed-up  : %s" % ("", speedup))
            log.add("%20s\tEfficiency: %s" % ("", efficiency))
            log.add("_" * 30)

    log.save(filename)


def dimemas_curated_summary(experiment_data):
    """
    This is an example of a function to curate the results and return something understandable
    :param experiment_data:
    :return: text with a summary of functions scalability in the experiment.
    """

    log = Log()
    cases = experiment_data.cases
    base_case = experiment_data.base_case
    dimemas_experiments = list(experiment_data[base_case]["Dimemas"])
    information_types = list(
        experiment_data[base_case]["Dimemas"][dimemas_experiments[0]].keys())
    information_types = ["Wallclock"]
    log_text = "Cores"
    for de in dimemas_experiments:
        log_text += f",{de}"
    log_text += "\n"

    for case in cases:
        log_text += f"{case}"
        for exp in dimemas_experiments:
            for it in information_types:
                address = (case,
                           "Dimemas",
                           exp,
                           it,
                           "data",
                           "Maximum",
                           )

                section = go_to_dictionary_address(
                    experiment_data.data, address)
                wallclock_time = section[0] / 10. ** 6
                log_text += f", {wallclock_time:.2f}"
        log_text += "\n"
    log.add(log_text)

    return log


def coupling_info(experiment_data, coupling_folder):
    import numpy as np
    import os

    for case in experiment_data.cases:
        columns = 6
        # components + model + header
        rows = len(experiment_data.components) + 2
        case_data = np.empty((rows, columns), "U25")
        case_data[0, :] = np.array(
            ["component", "nproc", "chsy", "cpl_cost", "waiting_time", "interpo_time"], dtype=str)
        i = 1

        for component in experiment_data.components:
            component_dict = go_to_dictionary_address(
                experiment_data.data, (case, "components", component))
            case_data[i, 0] = component
            for j in range(1, columns):
                case_data[i, j] = str(component_dict[case_data[0, j]])
            i += 1

        case_dict = experiment_data.data[case]
        case_data[i, 0] = "coupled"
        for j in range(1, columns):
            case_data[i, j] = str(case_dict[case_data[0, j]])

        case_folder = os.path.join(
            coupling_folder, case)
        os.makedirs(case_folder, exist_ok=True)
        np.savetxt(os.path.join(case_folder, "summary.csv"),
                   case_data, delimiter=',', fmt="%s")


def generate_most_expensive_function_summary_data(experiment_data, out_file_name, length_summary=10, component_to_report=""):
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
            ts_length = max(float(
                experiment_data.data[case]["components"][component]["ts_length"]) / pow(10, 6), ts_length)

        header.append("function_name")
        header.append(case + " (percent)")
        n_function = 0

        functions_elapsed_time = {}
        for component in components:
            functions_elapsed_time.update(go_to_dictionary_address(
                experiment_data.data, (case, "components", component, "function_info")))

        sorted_functions = list(
            sorted(functions_elapsed_time.items(), key=lambda f: f[1], reverse=True))
        for function_name, elapsed_time in sorted_functions:
            if n_function < length_summary + 1:
                function_names[case_idx].append(function_name)
                time_data[n_function].append(function_name)
                uf_percentage = elapsed_time / ts_length * 100
                time_data[n_function].append(f"{uf_percentage:.2f}")
                n_function += 1
            else:
                break

    with open(out_file_name, mode='w', encoding="utf8") as output:
        out_writer = csv.writer(output, delimiter=',')
        out_writer.writerow(header)
        for func in range(length_summary + 1):
            out_writer.writerow(time_data[func])
        print("Written file in " + abspath(out_file_name))


def most_expensive_function_summary(experiment_data, out_file_name, length_summary=10):
    generate_most_expensive_function_summary_data(
        experiment_data, out_file_name, length_summary)

    for component in experiment_data.components:
        generate_most_expensive_function_summary_data(
            experiment_data, component + "_" + out_file_name, length_summary, component)


def function_info_csv(experiment_data, csv_folder):
    """
    Function to save the results as a csv which will be used in the latex report
    :param experiment_data:
    """
    import numpy as np
    from os import mkdir
    from os.path import isdir

    # Create results folder
    if not isdir(csv_folder):
        mkdir(csv_folder)

    log = Log()

    # Get a dictionary with function info ordered by elapsed Time
    for component in experiment_data.components:
        fun_results = experiment_data.get_function_info(component)

        for k in fun_results:

            # List to store data
            resources = []
            speedup = []
            efficiency = []

            base_case = next(iter(fun_results[k]))
            base_case_nprocs = int(fun_results[k][base_case]["nproc"])
            base_result = fun_results[k][base_case]["elapsed_time"]
            # Fill list with formatted data
            for case in fun_results[k].keys():
                nproc = int(fun_results[k][case]["nproc"])
                resource_increase = nproc / base_case_nprocs
                resources.append(f"{nproc}")
                # Avoid division by zero
                case_speedup = base_result / \
                    (fun_results[k][case]["elapsed_time"] + 1e-10)
                case_efficiency = (
                    base_result / (fun_results[k][case]["elapsed_time"] + 1e-10)) / resource_increase
                speedup.append(f"{case_speedup:.2f}")
                efficiency.append(f"{case_efficiency:.2f}")

            # Declare array to be saved in csv
            header = np.array(
                ['resources (nproc)', 'speedup', 'efficiency'], dtype=str)

            data = np.empty((3, len(resources)))
            data[0, :] = resources
            data[1, :] = speedup
            data[2, :] = efficiency

            final_table = np.column_stack((header, data))
            np.savetxt(csv_folder + '/' + component + '_' + k +
                       '.csv', final_table, delimiter=',', fmt="%s")
    return log


def tracking_function_info(experiment_data):
    log = Log()

    cases = experiment_data.cases
    functions = experiment_data.functions

    info_types = ['Elap. Time(s)']

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
                address = (case,
                           "function_info",
                           function,
                           info_type,
                           )
                section = go_to_dictionary_address(experiment_data, address)
                log_text += f",{section:.2f}"
            log_text += "\n"

        log.add(log_text)
    return log


def function_information_from_paramedir_outputs(experiment_data, component):
    """
    This funciton only returns the functions that are defined in the base case counters part with the elapsed time on
    each one of them and the total execution time.
    :param experiment_data:
    :return: total_time, sorted dictionary with the time for each function
    """
    base_case = experiment_data.base_case
    address = (base_case, "components", component)
    component_dictionary = go_to_dictionary_address(experiment_data, address)
    functions_time = {}
    total_time = 0
    for function_name in component_dictionary["counters"]["Time"]:
        function_time = component_dictionary["counters"]["Time"][function_name]["Average"][0]
        functions_time |= {function_name: function_time}
        total_time += function_time

    return total_time, functions_time


def tracking(experiment_data, folder, threshold=0.01):
    from os import makedirs
    from os.path import abspath

    # Keep only the functions that represent more time than the defined threshold
    MPI_folder = folder + "/MPI"
    counters_folder = folder + "/counters"
    makedirs(MPI_folder, exist_ok=True)
    makedirs(counters_folder, exist_ok=True)
    # Joint log
    full_log = Log()
    for component in experiment_data.components:
        total_time, functions_time = function_information_from_paramedir_outputs(
            experiment_data, component)
        functions = [function for function, time in functions_time.items(
        ) if time / total_time >= threshold]

        for function in functions:
            MPI_log = Log()
            counters_log = Log()
            mpi_profile = tracking_mpi_profile_per_function(
                experiment_data, function, component)
            counters = tracking_counters_per_function(
                experiment_data, function, component)

            if mpi_profile:
                MPI_log += mpi_profile
                MPI_log.save(f"{MPI_folder}/{component}_{function}.csv")
                full_log += mpi_profile

            if counters:
                counters_log += counters
                counters_log.save(f"{counters_folder}/{component}_{function}.csv")
                full_log += counters_log

    # full_log.print()


def tracking_mpi_profile_per_function(experiment_data, function, component):
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
    # All MPI fields that can be found in a NEMO trace (Probably should find a more generic way
    #                 0 Outside_MPI
    #                 1 MPI_Recv
    #                 2 MPI_Isend
    #                 3 MPI_Wait
    #                 4 MPI_Bcast
    #                 5 MPI_Barrier
    #                 6 MPI_Allreduce
    #                 7 MPI_Comm_rank
    #                 8 MPI_Comm_size
    #                 9 MPI_Comm_dup
    #                 10 MPI_Init
    #                 11 MPI_Finalize
    #                 12 MPI_Iallreduce

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

    mpi_indices_to_keep = [index for index, value in enumerate(
        mpi_fields) if value in mpi_fields_to_keep]
    cases = experiment_data.cases

    log = Log()
    # log_txt = "\n%s\n" % function
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


def tracking_counters_per_function(experiment_data, function, component):
    log = Log()
    base_case = experiment_data.base_case
    cases = experiment_data.cases
    address = (base_case, "components", "nemo", "counters")
    counters_dictionary = go_to_dictionary_address(experiment_data, address)
    available_counters = list(counters_dictionary.keys())
    available_counters = ["Instructions", "Cycles", "IPC", "Time"]
    labels = ["Instructions", "Cycles", "IPC", "Time(ms)"]

    # Header
    log_text = "Processes"
    for index, counter in enumerate(available_counters):
        log_text += f",{labels[index]}"
    log.add(log_text)

    for case in cases:
        log_text = f"{case}"
        for counter in available_counters:
            address = (case,
                       "components",
                       component,
                       "counters",
                       counter,
                       function,
                       "Average"
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


def generate_sypd_summary_data(experiment_data, component=""):
    log = Log()

    if component == "":
        base_case = experiment_data.base_case
        base_case_data = experiment_data.data[base_case]
        cases = experiment_data.cases
    else:
        cases = experiment_data.components_cases[component]
        base_case = cases[0]
        address = (base_case, "components", component)
        base_case_data = go_to_dictionary_address(
            experiment_data.data, address)

    base_case_procs = int(base_case_data["nproc"])
    base_case_speed = float(base_case_data["sypd"])

    log.add("Case, Processes, SYPD, SpeedUp, Efficiency")
    for case in cases:
        if component == "":
            case_data = experiment_data.data[case]
        else:
            address = (case, "components", component)
            case_data = go_to_dictionary_address(experiment_data.data, address)
        speed = float(case_data["sypd"])
        speedup = speed / base_case_speed
        case_procs = int(case_data["nproc"])
        resource_increase = case_procs / base_case_procs
        efficiency = speedup / resource_increase
        log.add(f"{case}, {case_procs}, {speed:.1f}, {speedup:.1f}, {efficiency:.2f}")

    return log


def simulated_years_per_day_summary(experiment_data, filename):
    """
    Produces a simple log showing the simulated years per day of the different cases contained in the experiment,
    with the speed up and the efficiency respect to the base case.
    :param experiment_data:
    :return:  Log object with a summary of the simulated years per day and few more metrics.
    """
    model_sypd_summary = generate_sypd_summary_data(experiment_data)
    model_sypd_summary.save(filename)

    for component in experiment_data.components:
        component_sypd_summary = generate_sypd_summary_data(
            experiment_data, component)
        component_sypd_summary.save(component + "_" + filename)


def generate_sypd_plot_data(experiment_data, component=""):
    x_label = "Number of processes"
    y_label = "Simulated Years Per Day "
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
        speed = float(case_data["sypd"])
        case_procs = int(case_data["nproc"])
        plot_data[x_label] = np.append(plot_data[x_label], case_procs)
        plot_data[y_label] = np.append(plot_data[y_label], speed)

    return plot_data


def simulated_years_per_day_plot(experiment_data, filename):
    """
    Produces a simple log showing the simulated years per day of the different cases contained in the experiment,
    with the speed up and the efficiency respect to the base case.
    :param experiment_data:
    :return:  Log object with a summary of the simulated years per day and few more metrics.
    """
    from cfg.parser.utils.plotter import plotter

    plot_data = generate_sypd_plot_data(experiment_data)
    plotter(experiment_name=experiment_data.experiment_name, data=plot_data,
            scatter_labels=experiment_data.cases, filename=filename, linear_test=True)

    for component in experiment_data.components:
        component_plot_data = generate_sypd_plot_data(
            experiment_data, component)
        plotter(experiment_name=experiment_data.experiment_name, data=component_plot_data,
                scatter_labels=experiment_data.components_cases[component], filename=component + "_" + filename, linear_test=True)


def cases_component_data(experiment_data):
    log = Log()

    header = "Case"
    for component in experiment_data.components:
        header += f",{component.upper()} nproc"
    log.add(header)

    for case in experiment_data.cases:
        row = case
        for component in experiment_data.components:
            component_nproc = experiment_data[case]["components"][component]["nproc"]
            row += f",{component_nproc}"
        log.add(row)

    log.save("cases_info.csv")


def experiment_comparison(experiment1, experiment2):
    cases_to_compare = list(
        sorted([c for c in experiment1.cases if c in experiment2.cases]))
    base_case = min(cases_to_compare)
    log = Log()

    # Simulated Years per Day
    exp1_base_case_speed = experiment1[base_case]["sypd"]
    exp2_base_case_speed = experiment2[base_case]["sypd"]
    ratio = exp2_base_case_speed / exp1_base_case_speed
    log.add(
        "Base case experiment %4i processes  speed :  %5.1f|%5.1f SYPD                                                    -> %.2f ratio.  " %
        (base_case, exp1_base_case_speed, exp2_base_case_speed, ratio))
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
            "                     %4i processes  speed :  %5.1f|%5.1f SYPD   SpeedUp:   %4.1fx |%4.1fx   Efficiency: %4.2f|%4.2f  -> %.2f ratio." %
            (case, exp1_speed, exp2_speed, exp1_speedup, exp2_speedup, exp1_efficiency, exp2_efficiency, ratio))
    # Time-step length
    exp1_base_length = experiment1[base_case]["time_step_time"]
    exp2_base_length = experiment2[base_case]["time_step_time"]
    log.add("_" * 30)
    log.add("Base time-step length(s) with %4i processes:    %4.2f | %4.2f" %
            (base_case, exp1_base_length, exp2_base_length))
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_length = experiment1[case]["time_step_time"]
        exp2_length = experiment2[case]["time_step_time"]
        log.add("                              %4i processes:    %4.2f | %4.2f" % (
            case, exp1_length, exp2_length))
    return log


def multiexperiment_comparison(experiments: list, field1: str) -> Log:
    """
    Compare multiple experiment results based on a specified field.

    This function analyzes multiple experiments and creates a comparison table of their
    performance metrics for cases with matching processor counts.

    Args:
        experiments (list): List of TimingInformation objects to compare
        field1 (str): Name of the field to compare between experiments (e.g. 'sypd')

    Returns:
        Log: A Log object containing the formatted comparison table with the following format:
            - Header row with experiment names
            - Rows for each case showing the field1 value for each experiment

    Notes:
        - Cases are considered matching if they use the same number of processors
    """
    # Initialize results printout
    log = Log()

    corresponding_cases = [ ["" for _ in experiments ] for _ in experiments[0].cases ]
    for i, case in enumerate(experiments[0].cases):
        current_nproc = int(experiments[0][case]["nproc"])
        corresponding_cases[i][0] = case
        for j, experiment in enumerate(experiments[1:]):
            for case in experiment.cases:
                if int(experiment[case]["nproc"]) == current_nproc:
                    corresponding_cases[i][j + 1] = case
                    break

    # Add data
    header = "Case:"
    for experiment in experiments:
        header += f", {experiment.experiment_name} (SYPD)"

    log.add(header)

    for i, case in enumerate(experiments[0].cases):
        case_row = case
        for j, experiment in enumerate(experiments):
            # If there is no corresponding case in the experiment in number of procs,
            # set invalid value
            exp_speed = -1
            if corresponding_cases[i][j] != "":
                exp_speed = float(experiment[corresponding_cases[i][j]][field1])
            case_row += f", {exp_speed:.2f} "
        log.add(case_row)

    return log


def generate_weakscaling_data(experiments: list, component_to_report: str = "") -> Log:
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
                    case_dict, ("components", component_to_report))
                grid_points = case_metrics["grid_points"]
                resolution = case_metrics["resolution"]
                nproc = case_metrics["nproc"]
                ts_per_second = float(case_metrics["ts_per_second"])

                log.add(
                    f"{conf}, {nproc}, {resolution}, {ts_per_second:.2f}, {grid_points}")

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
    # Find cases that are common in all the experiments
    common_cases = set(experiments[0].cases)
    for experiment in experiments[1:]:
        common_cases.intersection_update(experiment.cases)
    common_cases = list(common_cases)
    base_case = min(common_cases)

    # Search common functions
    common_functions = set(experiments[0][base_case]["function_info"].keys())
    for experiment in experiments[1:]:
        common_functions.intersection_update(
            experiment[base_case]["function_info"].keys())
    common_functions = list(common_functions)

    return common_cases, common_functions


def extract_data_from_experiments(experiments):
    from math import ceil
    data = []
    for experiment in experiments:
        for case in experiment.cases:
            to_append = (ceil(case / experiment.processes_per_node),
                         case, experiment[case]["time_step_time"])
            data.append(to_append)
    return data


def fit_step_time_to_model(experiments):
    data = extract_data_from_experiments(experiments)
    return fit_data_to_model(data, model=my_model)


def my_model(individual, data):
    import numpy as np

    # define a fitness function
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
    ga = pyeasyga.GeneticAlgorithm(data, elitism=True, population_size=100, generations=400, crossover_probability=.4,
                                   mutation_probability=.5)  # initialise the GA with data
    max_time = max([x[2] for x in data])

    def create_individual(data):
        return np.random.uniform(0, max_time, size=5)

    def crossover(parent_1, parent_2):
        parent_1, parent_2 = parent_1.tolist(), parent_2.tolist()
        crossover_index = np.random.randint(0, len(parent_1))
        child_1, child_2 = parent_1, parent_2
        child_1[crossover_index], child_2[crossover_index] = child_2[crossover_index], child_1[crossover_index]
        child_1, child_2 = np.array(child_1), np.array(child_2)
        return child_1, child_2

    def mutate(individual):
        index = np.random.randint(0, len(individual))
        individual[index] += np.random.normal(.05)
        return individual

    ga.fitness_function = model  # set the GA's fitness function
    ga.create_individual = create_individual
    ga.crossover_function = crossover
    ga.mutate_function = mutate

    ga.run()  # run the GA
    return ga.best_individual()  # print the GA's best solution


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
        test_individual += np.random.normal(scale=.01, size=len(my_individual))
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
    fun_key = "function_info"
    data = []
    for experiment in experiments:
        base_case = experiment.base_case
        if function_name is None:
            my_fun = list(experiment.data[base_case][fun_key].labels())[0]
        else:
            my_fun = function_name
        for case in experiment.cases:
            to_append = (
                ceil(case / experiment.processes_per_node), case, experiment[case][fun_key][my_fun]['Elap. Time(s)'])
            data.append(to_append)
    return (data)


def oversimplified_memory_model(experiments):
    model_parameters = fit_step_time_to_model(experiments)
    error, parameters = model_parameters
    import numpy as np
    error = np.sqrt(abs(error))
    mb, cb, nc, cc, r = parameters
    cb = cb / 48.
    tt = mb + cb + nc + cc + r
    print("Overall model:")
    print("MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%" %
          (100. * mb / tt, 100. * cb / tt, 100. * error / tt))
    print("Top10 Functions:")
    functions = list(
        experiments[0].data[experiments[0].base_case]["function_info"].labels())
    functions = functions[:10]
    for function in functions:
        error, parameters = fit_functions_to_model(
            experiments, function_name=function)
        error = np.sqrt(abs(error))
        mb_time, cb_time, internode, intranode, residual = parameters
        cb_time = cb_time / 48
        total_time = mb_time + cb_time + internode + intranode + residual
        print("Function: %20s\tTime(s): %.1f\t MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%" %
              (function, total_time, 100. * mb_time / total_time, 100. * cb_time / total_time,
               100. * abs(error / total_time)))
