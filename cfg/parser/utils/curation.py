# Imports
import numpy as np
from matplotlib.ticker import FormatStrFormatter

from cfg.latex.ReportGenerator import Section


class Log:
    """
    Object to store the Logs (info to be printed).
    Probably there's an existing and better way of doing it.
    """

    def __init__(self):
        self.text = ""

    def __add__(self, other):
        if isinstance(other, Log):
            other = other.text
        self.text += other + "\n"
        return self

    def add(self, text):
        self.__add__(text)

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
            raise AssertionError("Provided address does not exists in this dictionary:\n%s" % str(address))

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
            base_nproc = fun_results[k][base_case]["nproc"]
            for case in experiment_data.components_cases[component]:
                case_nproc = fun_results[k][case]["nproc"]
                case_speed = fun_results[k][case]["elapsed_time"]
                resource_increase = case_nproc / base_nproc
                resources += " %.2f" % case_nproc
                # Avoid dividing by zero
                speedup += " %.2f" % (base_result / (case_speed + 1e-10))
                efficiency += " %.2f" % ((base_result / (case_speed + 1e-10)) / resource_increase)
            
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
    information_types = list(experiment_data[base_case]["Dimemas"][dimemas_experiments[0]].keys())
    information_types = ["Wallclock"]
    log_text = "Cores"
    for de in dimemas_experiments:
        log_text += ",%s" % de
    log_text += "\n"

    for case in cases:
        log_text += "%i" % case
        for exp in dimemas_experiments:
            for it in information_types:
                address = (case,
                           "Dimemas",
                           exp,
                           it,
                           "data",
                           "Maximum",
                           )

                section = go_to_dictionary_address(experiment_data.data, address)
                wallclock_time = section[0] / 10. ** 6
                log_text += ", %.2f" % wallclock_time
        log_text += "\n"
    log.add(log_text)

    return log

def generate_most_expensive_function_summary_data(experiment_data, out_file_name, length_summary=10, component=""):
    import csv
    from os.path import abspath
    header = []
    TIME_data = [[] for x in range(length_summary + 1)]
    function_names = [[] for x in range(len(experiment_data.cases))]
    for case_idx, case in enumerate(experiment_data.cases):
        header.append("function_name")
        header.append(case)
        n_function = 0
        if component == "":
            for component in experiment_data.components:
                for function_name, elapsed_time in experiment_data.data[case]["Components"][component]["FunctionInfo"].items():
                    if n_function < length_summary + 1:
                        function_names[case_idx].append(function_name)
                        TIME_data[n_function].append(function_name)
                        TIME_data[n_function].append(str(elapsed_time))
                        n_function += 1
                    else:
                        break
        else:
            for function_name, elapsed_time in experiment_data.data[case]["Components"][component]["FunctionInfo"].items():
                if n_function < length_summary + 1:
                    function_names[case_idx].append(function_name)
                    TIME_data[n_function].append(function_name)
                    TIME_data[n_function].append(str(elapsed_time))
                    n_function += 1
                else:
                    break

    with open(out_file_name, mode='w') as output:
        out_writer = csv.writer(output, delimiter=',')
        out_writer.writerow(header)
        for func in range(length_summary + 1):
            out_writer.writerow(TIME_data[func])
        print("Written file in " + abspath(out_file_name))

def most_expensive_function_summary(experiment_data, out_file_name, length_summary=10):
    generate_most_expensive_function_summary_data(experiment_data, out_file_name, length_summary)
    
    for component in experiment_data.components:
        generate_most_expensive_function_summary_data(experiment_data, component + "_" + out_file_name, length_summary, component)

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
        
        for k, v in fun_results.items():

            # List to store data
            resources = []
            speedup = []
            efficiency = []

            base_case = next(iter(fun_results[k]))
            base_case_nprocs = fun_results[k][base_case]["nproc"]
            base_result = fun_results[k][base_case]["elapsed_time"]
            # Fill list with formatted data
            for case in fun_results[k].keys():
                nproc = fun_results[k][case]["nproc"]
                resource_increase = nproc / base_case_nprocs
                resources.append("%i" % nproc)
                # Avoid division by zero
                speedup.append("{:.2f}".format(base_result / (fun_results[k][case]["elapsed_time"] + 1e-10)))
                efficiency.append("{:.2f}".format((base_result / (fun_results[k][case]["elapsed_time"] + 1e-10)) / resource_increase))

            # Declare array to be saved in csv
            header = np.array(['resources', 'speedup', 'efficiency'], dtype=str)

            data = np.empty((3, len(resources)))
            data[0, :] = resources
            data[1, :] = speedup
            data[2, :] = efficiency

            final_table = np.column_stack((header, data))
            np.savetxt(csv_folder + '/' + component + '_' + k + '.csv', final_table, delimiter=',', fmt="%s")
    return log

def tracking_function_info(experiment_data):
    log = Log()

    cases = experiment_data.cases
    functions = experiment_data.functions

    info_types = ['Elap. Time(s)']

    for info_type in info_types:
        log_text = "%s" % info_type
        log_text += "," * len(cases) + "\n"
        log_text += "%s" % "Functions"
        for case in cases:
            log_text += ",%i" % case
        log_text += "\n"

        for function in functions:
            log_text += "%s" % function
            for case in cases:
                address = (case,
                           "FunctionInfo",
                           function,
                           info_type,
                           )
                section = go_to_dictionary_address(experiment_data, address)
                log_text += ",%.2f" % section
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
    address = (base_case, "Components", component)
    component_dictionary = go_to_dictionary_address(experiment_data, address)
    functions_time = {}
    total_time = 0
    for function_name in component_dictionary["Counters"]["Time"]:
        function_time = component_dictionary["Counters"]["Time"][function_name]["Average"][0]
        functions_time |= {function_name : function_time}
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
        total_time, functions_time = function_information_from_paramedir_outputs(experiment_data, component)
        functions = [function for function, time in functions_time.items() if time / total_time >= threshold]

        for function in functions:
            MPI_log = Log()
            counters_log = Log()
            mpi_profile = tracking_mpi_profile_per_function(experiment_data, function, component)            
            counters = tracking_counters_per_function(experiment_data, function, component)

            if mpi_profile:
                MPI_log += mpi_profile
                MPI_log.save("%s/%s-%s.csv" % (MPI_folder, component, function))
                full_log += mpi_profile
            
            if counters:
                counters_log += counters
                counters_log.save("%s/%s-%s.csv" % (counters_folder, component, function))
                full_log += counters_log

    # full_log.print()


def tracking_mpi_profile_per_function(experiment_data, function, component):
    base_case = experiment_data.base_case
    address = (
        base_case,
        "Components",
        component,
        "Counters",
        "MPIcallprofile",
    )
    mpi_dictionary = go_to_dictionary_address(experiment_data, address)
    mpi_fields = list(mpi_dictionary[function]["names"])
    # All MPI fields that can be found in a NEMO trace (Probably should find a more generic way
    """
                    0 Outside_MPI
                    1 MPI_Recv
                    2 MPI_Isend
                    3 MPI_Wait
                    4 MPI_Bcast
                    5 MPI_Barrier
                    6 MPI_Allreduce
                    7 MPI_Comm_rank
                    8 MPI_Comm_size
                    9 MPI_Comm_dup
                    10 MPI_Init
                    11 MPI_Finalize
                    12 MPI_Iallreduce
    """
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

    mpi_indices_to_keep = [index for index, value in enumerate(mpi_fields) if value in mpi_fields_to_keep]
    cases = experiment_data.cases

    log = Log()
    # log_txt = "\n%s\n" % function
    log_txt = "Cores"
    for index, field in enumerate(mpi_fields):
        if index not in mpi_indices_to_keep:
            continue
        log_txt += ",%s" % field
    log.add(log_txt)
    for case in cases:
        log_txt = "%s" % case
        address = (
            case,
            "Components",
            component,
            "Counters",
            "MPIcallprofile",
            function,
            "Average",
        )
        data = go_to_dictionary_address(experiment_data, address)
        for index, field in enumerate(mpi_fields):
            if index not in mpi_indices_to_keep:
                continue
            log_txt += ",%.1f" % data[index]            
        log.add(log_txt)
    return log


def tracking_counters_per_function(experiment_data, function, component):
    log = Log()
    base_case = experiment_data.base_case
    cases = experiment_data.cases
    address = (base_case, "Components", "nemo", "Counters")
    counters_dictionary = go_to_dictionary_address(experiment_data, address)
    available_counters = list(counters_dictionary.keys())
    available_counters = ["Instructions", "Cycles", "IPC", "Time"]
    labels = ["Instructions", "Cycles", "IPC", "Time(ms)"]

    # Header
    log_text = "Processes"
    for index, counter in enumerate(available_counters):
        log_text += ",%s" % labels[index]
    log.add(log_text)

    for case in cases:
        log_text = "%s" % case
        for counter in available_counters:
            address = (case,
                       "Components",
                       component,
                       "Counters",
                       counter,
                       function,
                       "Average"
                       )
            try:
                section = go_to_dictionary_address(experiment_data, address)
            except AssertionError as err:
                log_text += ","
                continue
            data = section[0]
            log_text += ", %.1f" % data

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
        address = (base_case, "Components", component)
        base_case_data = go_to_dictionary_address(experiment_data.data, address)
    
    base_case_procs = base_case_data["nproc"]
    base_case_speed = base_case_data["SYPD"]

    log.add("Case, Processes, SYPD, SpeedUp, Efficiency")
    for case in cases:
        if component == "":
            case_data = experiment_data.data[case]
        else:
            address = (case, "Components", component)
            case_data = go_to_dictionary_address(experiment_data.data, address)
        speed = case_data["SYPD"]
        speedup = speed / base_case_speed
        case_procs = case_data["nproc"]
        resource_increase = case_procs / base_case_procs
        efficiency = speedup / resource_increase
        log.add("%s, %4i, %.1f, %.1fx, %.2f" %
                (case, case_procs, speed, speedup, efficiency))

    return log

def simulated_years_per_day_summary(experiment_data, filename):
    from cfg.parser.utils.plotter import plotter
    """
    Produces a simple log showing the simulated years per day of the different cases contained in the experiment,
    with the speed up and the efficiency respect to the base case.
    :param experiment_data:
    :return:  Log object with a summary of the simulated years per day and few more metrics.
    """
    model_sypd_summary = generate_sypd_summary_data(experiment_data)
    model_sypd_summary.save(filename)

    for component in experiment_data.components:
        component_sypd_summary = generate_sypd_summary_data(experiment_data, component)
        component_sypd_summary.save(component + "_" + filename)

def generate_sypd_plot_data(experiment_data, component=""):
    x_label = "Number of processes"
    y_label = "Simulated Years Per Day "
    plot_data = {x_label: np.empty(0), y_label: np.empty(0)}
    
    if component == "":
        base_case = experiment_data.base_case
        base_case_speed = experiment_data.data[base_case]["SYPD"]
        base_case_procs = experiment_data.data[base_case]["nproc"]
        cases = experiment_data.cases
    else:
        base_case = experiment_data.components_cases[component][0]
        base_case_speed = experiment_data.data[base_case]["Components"][component]["SYPD"]
        base_case_procs = experiment_data.data[base_case]["Components"][component]["nproc"]
        cases = experiment_data.components_cases[component]
    
    for case in cases:
        if component == "":
            case_data = experiment_data.data[case]
        else:
            address = (case, "Components", component)
            case_data = go_to_dictionary_address(experiment_data.data, address)
        speed = case_data["SYPD"]
        speedup = speed / base_case_speed
        case_procs = case_data["nproc"]
        resource_increase = case_procs / base_case_procs
        efficiency = speedup / resource_increase
        plot_data[x_label] = np.append(plot_data[x_label], case_procs)
        plot_data[y_label] = np.append(plot_data[y_label], speed)

    return plot_data


def simulated_years_per_day_plot(experiment_data, filename):
    from cfg.parser.utils.plotter import plotter
    """
    Produces a simple log showing the simulated years per day of the different cases contained in the experiment,
    with the speed up and the efficiency respect to the base case.
    :param experiment_data:
    :return:  Log object with a summary of the simulated years per day and few more metrics.
    """
    plot_data = generate_sypd_plot_data(experiment_data)
    plotter(experiment_name=experiment_data.experiment_name, data=plot_data, scatter_labels=experiment_data.cases, filename=filename)

    for component in experiment_data.components:
        component_plot_data = generate_sypd_plot_data(experiment_data, component)
        plotter(experiment_name=experiment_data.experiment_name, data=component_plot_data,  scatter_labels=experiment_data.components_cases[component], filename=component + "_" + filename)

def cases_component_data(experiment_data):
    log = Log()
    
    header = "Case"
    for component in experiment_data.components:
        header += ",%s" % component
    log.add(header)
    
    for case in experiment_data.cases:
        row = case
        for component in experiment_data.components:
            row += ",%i" % experiment_data[case]["Components"][component]["nproc"]
        log.add(row)
    
    log.save("cases_info.csv")

def experiment_comparison(experiment1, experiment2):
    cases_to_compare = list(sorted([c for c in experiment1.cases if c in experiment2.cases]))
    base_case = min(cases_to_compare)
    log = Log()

    # Simulated Years per Day
    exp1_base_case_speed = experiment1[base_case]["SYPD"]
    exp2_base_case_speed = experiment2[base_case]["SYPD"]
    ratio = exp2_base_case_speed / exp1_base_case_speed
    log.add(
        "Base case experiment %4i processes  speed :  %5.1f|%5.1f SYPD                                                    -> %.2f ratio.  " %
        (base_case, exp1_base_case_speed, exp2_base_case_speed, ratio))
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_speed = experiment1[case]["SYPD"]
        exp1_speedup = exp1_speed / exp1_base_case_speed
        exp1_efficiency = exp1_speedup / resource_increase
        exp2_speed = experiment2[case]["SYPD"]
        exp2_speedup = exp2_speed / exp2_base_case_speed
        exp2_efficiency = exp2_speedup / resource_increase
        ratio = exp2_speed / exp1_speed

        log.add(
            "                     %4i processes  speed :  %5.1f|%5.1f SYPD   SpeedUp:   %4.1fx |%4.1fx   Efficiency: %4.2f|%4.2f  -> %.2f ratio." %
            (case, exp1_speed, exp2_speed, exp1_speedup, exp2_speedup, exp1_efficiency, exp2_efficiency, ratio))
    # Time-step length
    exp1_base_length = experiment1[base_case]["TimeStepTime"]
    exp2_base_length = experiment2[base_case]["TimeStepTime"]
    log.add("_" * 30)
    log.add("Base time-step length(s) with %4i processes:    %4.2f | %4.2f" %
            (base_case, exp1_base_length, exp2_base_length))
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_length = experiment1[case]["TimeStepTime"]
        exp2_length = experiment2[case]["TimeStepTime"]
        log.add("                              %4i processes:    %4.2f | %4.2f" % (case, exp1_length, exp2_length))
    return log


def multiexperiment_comparison(experiments, field1):
    # List of process per node used in experiments
    processes_per_node = [int(exp.processes_per_node.replace("'", "")) for exp in experiments]

    # Find cases with common number of node among the experiments
    common_cases = {}
    
    # 
    for experiment in experiments:
        for case in experiments.cases:
            nproc = experiment[case]["nproc"]
            common_cases[nproc] = case  
    
    # common_cases = set([experiments[0][ex]["nproc"] / processes_per_node[0] for ex in experiments[0].cases])
    # for index, exp in enumerate(experiments[1:]):
    #     n_node = [exp[case]["nproc"] / processes_per_node[index + 1] for case in exp.cases]
    #     common_cases.intersection_update(n_node)

    cases_to_compare = list(common_cases)
    base_case = min(cases_to_compare)

    # Initialize results printout
    log = Log()

    # Simulated Years per Day
    base_case_speed = [experiment[base_case * ppn][field1] for experiment, ppn in zip(experiments, processes_per_node)]

    # Find index of slowest experiment
    slowest_index = np.argmin(base_case_speed)

    ratios = [bcs / base_case_speed[slowest_index] for bcs in base_case_speed]

    # Print header
    # log_text = "%s, %s, %s" % (field1, field2, field3)
    # log.add(log_text)
    log_text = "Resources:"
    for index, experiment in enumerate(experiments):
        # add info on layout of proc on nodes
        if int(experiment.processes_per_node.replace("'", "")) != 48:
            node_filling = "[" + experiment.processes_per_node + " cores per node]"
            log_text += ", %s %s" % (experiment.experiment_name, node_filling)
        else:
            log_text += ", %s" % (experiment.experiment_name + " [" + field1 + "]")

    log.add(log_text)

    # Add data
    log_text = "%4i" % base_case
    for index, experiment in enumerate(experiments):
        log_text += ",%5.2f " % base_case_speed[index]

    log.add(log_text)

    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp_speeds = [experiment[case * ppn][field1] for experiment, ppn in
                      zip(experiments, processes_per_node)]
        exp_speedups = [exp_speeds[i] / base_case_speed[i] for i in range(len(experiments))]
        exp_efficiency = [es / resource_increase for es in exp_speedups]

        ratios = [es / exp_speeds[slowest_index] for es in exp_speeds]

        log_text = "%4i" % case
        for index, experiment in enumerate(experiments):
            log_text += ", %5.2f " % exp_speeds[index]
        log.add(log_text)
    return log


def weakscaling_compute(experiment):
    # Get used configurations
    configurations = [exp.param_file["configuration_name"][0] for exp in experiment]
    # Get tail sizes for configurations
    tile_size = [exp.param_file["tile_size"] for exp in experiment]
    # Get number of cores
    number_of_processes = [exp.param_file["number_of_processes"] for exp in experiment]
    # Get average duration of the timesteps with this config
    TimeStepTime = [[exp.data[core]["TimeStepTime"] for core in exp.data] for exp in experiment]
    log = Log()
    log.add("Config:, Tile Size, Ncores, Timestep per second ")
    for index_conf, conf in enumerate(configurations):
        for index_size, size in enumerate(tile_size):
            log.add(conf + "," + size[index_conf] + "," + number_of_processes[index_conf][index_size] +
                    ", %5.2f " % TimeStepTime[index_conf][index_size])
    return log


def find_common_cases_and_functions(experiments):
    # Find cases that are common in all the experiments
    common_cases = set(experiments[0].cases)
    for experiment in experiments[1:]:
        common_cases.intersection_update(experiment.cases)
    common_cases = list(common_cases)
    base_case = min(common_cases)

    # Search common functions
    common_functions = set(experiments[0][base_case]["FunctionInfo"].keys())
    for experiment in experiments[1:]:
        common_functions.intersection_update(experiment[base_case]["FunctionInfo"].keys())
    common_functions = list(common_functions)

    return common_cases, common_functions


def extract_data_from_experiments(experiments):
    from math import ceil
    data = []
    for experiment in experiments:
        for case in experiment.cases:
            to_append = (ceil(case / experiment.processes_per_node), case, experiment[case]["TimeStepTime"])
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
    fun_key = "FunctionInfo"
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
    print("MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%" % (100. * mb / tt, 100. * cb / tt, 100. * error / tt))
    print("Top10 Functions:")
    functions = list(experiments[0].data[experiments[0].base_case]["FunctionInfo"].labels())
    functions = functions[:10]
    for function in functions:
        error, parameters = fit_functions_to_model(experiments, function_name=function)
        error = np.sqrt(abs(error))
        mb_time, cb_time, internode, intranode, residual = parameters
        cb_time = cb_time / 48
        total_time = mb_time + cb_time + internode + intranode + residual
        print("Function: %20s\tTime(s): %.1f\t MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%" %
              (function, total_time, 100. * mb_time / total_time, 100. * cb_time / total_time,
               100. * abs(error / total_time)))
