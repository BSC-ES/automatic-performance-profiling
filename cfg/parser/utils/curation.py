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


def function_curated_summary(experiment_data):
    """
    This is an example of a function to curate the results and return something understandable
    :param experiment_data:
    :return: text with a summary of functions scalability in the experiment.
    """
    fun_results = {}
    log = Log()
    for function in experiment_data.functions:
        fun_results[function] = {}
        for c, r in experiment_data.get_function_info(function):
            fun_results[function][c] = r
    # Remove empty entries
    fun_results = {k: v for k, v in fun_results.items() if len(v) != 0}

    # Order function by 'Elap. Time(s)'
    fun_results = {k: v for k, v in
                   sorted(fun_results.items(), key=lambda item: item[1][experiment_data.base_case])}
    for k, v in fun_results.items():
        resources = ""
        speedup = ""
        efficiency = ""
        base_result = fun_results[k][experiment_data.base_case]
        for case in experiment_data.cases:
            if case == experiment_data.base_case:
                continue
            resource_increase = case / experiment_data.base_case
            try:
                resources += " %.2f" % resource_increase
                speedup += " %.2f" % (base_result / fun_results[k][case])
                efficiency += " %.2f" % ((base_result / fun_results[k][case]) / resource_increase)
            except KeyError:
                pass
        log.add("%20s\tResources : %s" % (k, resources))
        log.add("%20s\tSpeed-up  : %s" % ("", speedup))
        log.add("%20s\tEfficiency: %s" % ("", efficiency))
        log.add("_" * 30)
    return log


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


def most_expensive_function_summary(experiment_data, out_file_name, length_summary=10):
    import csv
    from os.path import abspath
    header = []
    TIME_data = [[] for x in range(length_summary + 1)]
    function_names = [[] for x in range(len(experiment_data.cases))]
    L3_data = [[] for x in range(len(experiment_data.cases))]
    IPC_data = [[] for x in range(len(experiment_data.cases))]
    for core_index, core in enumerate(experiment_data.cases):
        header.append("function_name")
        header.append(core)
        n_function = 0
        for function_name, elapsed_time in experiment_data.data[core]["FunctionInfo"].items():
            if n_function < length_summary + 1:
                function_names[core_index].append(function_name)
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


# Function plot L3 cache misses vs IPC
def L3_IPC_scatterplot(experiment_data, output_picture_name, length_summary=10):
    import matplotlib.pyplot as plt
    function_info = [[] for x in range(length_summary + 1)]
    # Use the most expensive function on the bigger N of cores used
    max_core = experiment_data.cases[-1]
    function_name = [name for name, info in experiment_data.data[max_core]["FunctionInfo"].items()]
    # Array to store plotted function's names
    legend_names = []
    for core_index, core in enumerate(experiment_data.cases):
        n_function = 0
        for name in function_name:
            if n_function < length_summary + 1:
                try:
                    # Function name's are taken from timings, so it is possible they are not present in the trace
                    L3 = experiment_data[core]['Counters']['L3'][name]['Average']
                    IPC = experiment_data[core]['Counters']['IPC'][name]['Average']
                except KeyError:
                    # If the function was not tracked skip to next function
                    continue
                if len(legend_names) < length_summary:
                    legend_names.append(name)
                function_info[n_function].append([L3, IPC])
                n_function += 1
            else:
                break
    # Create the plot
    fig, ax = plt.subplots()
    ax.set_title("IPC vs L3 per Instruction")
    ax.set_ylabel('IPC')
    ax.set_xlabel('Useful L3 Total cache misses per Instruction (%)')
    for function_index, function_name in enumerate(legend_names):
        ax.plot([val[0] for val in function_info[function_index]],
                 [val[1] for val in function_info[function_index]], '-o', label=function_name)
    ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    if not output_picture_name.count(".png"):
        output_picture_name = output_picture_name + ".png"
    fig.tight_layout()

    # This way labels for the x axis are not just one long number
    # ax = plt.axes()
    # ax.arrow(0, 0, 0.5, 0.5, head_width=0.05, head_length=0.1, fc='k', ec='k')
    # ax.annotate('local max', xy=(100, 500), xytext=(3, 1.5), xycoords='figure points',
    #             horizontalalignment='right', verticalalignment='top',
    #             arrowprops=dict(facecolor='black', shrink=0.05)
    #             )
    # ax.arrow(0.0, 1, 3, 0, head_width=0.05, head_length=0.1, fc='k', ec='k')
    fig.savefig(output_picture_name)


def function_info_csv(experiment_data, csv_folder):
    """
    Function to save the results as a csv which will be used in the latex report
    :param experiment_data:
    """
    import numpy as np
    from os import mkdir
    import errno

    # Try and create output dir
    try:
        mkdir(csv_folder)
    except OSError as exc:
        if exc.errno != errno.EEXIST:
            raise
        pass

    fun_results = {}
    log = Log()
    for function in experiment_data.functions:
        fun_results[function] = {}
        for c, r in experiment_data.get_function_info(function):
            fun_results[function][c] = r

    # Remove empty entries
    fun_results = {k: v for k, v in fun_results.items() if v != {}}
    key = 'Elap. Time(s)'

    # Order the function results by 'Elap. Time(s)'
    fun_results = {k: v for k, v in
                   sorted(fun_results.items(), key=lambda item: item[1][experiment_data.base_case])}
    for k, v in fun_results.items():

        # List to store data
        resources = []
        speedup = []
        efficiency = []

        base_result = fun_results[k][experiment_data.base_case]

        # Fill list with formatted data
        for case in experiment_data.cases:
            if case == experiment_data.base_case:
                continue
            resource_increase = case / experiment_data.base_case
            try:
                resources.append("{:.0f}".format(resource_increase))
                speedup.append("{:.2f}".format(base_result / fun_results[k][case]))
                efficiency.append("{:.2f}".format((base_result / fun_results[k][case]) / resource_increase))
            except KeyError:
                pass
        # Declare array to be saved in csv
        header = np.array(['resources', 'speedup', 'efficiency'], dtype=str)

        data = np.empty((3, len(resources)))
        data[0, :] = resources
        data[1, :] = speedup
        data[2, :] = efficiency

        final_table = np.column_stack((header, data))
        np.savetxt(csv_folder + '/' + k + '.csv', final_table, delimiter=',', fmt="%s")
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


def function_information_from_paramedir_outputs(experiment_data):
    """
    This funciton only returns the functions that are defined in the base case counters part with the elapsed time on
    each one of them and the total execution time.
    :param experiment_data:
    :return: total_time, sorted dictionary with the time for each function
    """
    base_case = experiment_data.base_case
    address = (base_case, "Counters")
    counters_dictionary = go_to_dictionary_address(experiment_data, address)
    counter = "Time"
    functions = list(counters_dictionary["Time"].keys())

    def get_address(function):
        return (base_case,
                "Counters",
                counter,
                function,
                "Average"
                )

    times = [go_to_dictionary_address(experiment_data, get_address(function))[0] for function in functions]
    total_time = sum(times)

    functions_time = {}
    for index, function in enumerate(functions):
        functions_time[function] = times[index]
    functions_time = {k: v for k, v in sorted(functions_time.items(), key=lambda item: - item[1])}
    return total_time, functions_time


def tracking(experiment_data, folder, threshold=0.01):
    from os import makedirs
    from os.path import abspath
    total_time, functions_time = function_information_from_paramedir_outputs(experiment_data)

    # Keep only the functions that represent more time than the defined threshold
    functions = [function for function, time in functions_time.items() if time / total_time >= threshold]
    MPI_folder = folder + "/MPI"
    counters_folder = folder + "/counters"
    makedirs(MPI_folder, exist_ok=True)
    makedirs(counters_folder, exist_ok=True)
    # Joint log
    full_log = Log()
    for function in functions:
        MPI_log = Log()
        counters_log = Log()
        mpi_profile = tracking_mpi_profile_per_function(experiment_data, function)
        counters = tracking_counters_per_function(experiment_data, function)
        if not mpi_profile or not counters:
            continue

        MPI_log += mpi_profile
        counters_log += counters

        MPI_log.save("%s/%s.csv" % (MPI_folder, function))
        counters_log.save("%s/%s.csv" % (counters_folder, function))
        full_log += mpi_profile + counters

    full_log.print()


def tracking_mpi_profile_per_function(experiment_data, function):
    base_case = experiment_data.base_case
    address = (
        base_case,
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
        log_txt = "%i" % case
        address = (
            case,
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


def tracking_counters_per_function(experiment_data, function):
    log = Log()
    base_case = experiment_data.base_case
    cases = experiment_data.cases
    address = (base_case, "Counters")
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
        log_text = "%i" % case
        for counter in available_counters:
            address = (case,
                       "Counters",
                       counter,
                       function,
                       "Average"
                       )
            try:
                section = go_to_dictionary_address(experiment_data, address)
            except AssertionError as err:
                return None
            data = section[0]
            log_text += ", %.1f" % data

        log.add(log_text)

    return log


def simulated_years_per_day_summary(experiment_data):
    from cfg.parser.utils.plotter import plotter
    """
    Produces a simple log showing the simulated years per day of the different cases contained in the experiment,
    with the speed up and the efficiency respect to the base case.
    :param experiment_data:
    :return:  Log object with a summary of the simulated years per day and few more metrics.
    """
    # Log object to output the text
    log = Log()

    base_case = experiment_data.base_case
    base_case_speed = experiment_data[base_case]["SYPD"]

    log.add("Processes, Comunication, SpeedUp, Efficiency")
    for case in experiment_data.cases:
        speed = experiment_data[case]["SYPD"]
        speedup = speed / base_case_speed
        resource_increase = case / base_case
        efficiency = speedup / resource_increase
        log.add("%4i, %.1f, %.1fx, %.2f" %
                (case, speed, speedup, efficiency))

    return log


def simulated_years_per_day_plot(experiment_data, filename):
    from cfg.parser.utils.plotter import plotter
    """
    Produces a simple log showing the simulated years per day of the different cases contained in the experiment,
    with the speed up and the efficiency respect to the base case.
    :param experiment_data:
    :return:  Log object with a summary of the simulated years per day and few more metrics.
    """
    # Data to plot
    x_label = "Number of processes"
    y_label = "Simulated Years Per Day "
    plot_data = {x_label: [], y_label: []}

    base_case = experiment_data.base_case
    base_case_speed = experiment_data[base_case]["SYPD"]

    plot_data[x_label].append(base_case)
    plot_data[y_label].append(base_case_speed)

    for case in experiment_data.cases:
        if case == experiment_data.base_case:
            continue
        speed = experiment_data[case]["SYPD"]
        speedup = speed / base_case_speed
        resource_increase = case / base_case
        efficiency = speedup / resource_increase
        plot_data[x_label].append(case)
        plot_data[y_label].append(speed)

    plotter(experiment_name=experiment_data.experiment_name, data=plot_data, filename=filename)


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


def multiexperiment_comparison(experiments, field1="Communication", field2="sypd", field3="average"):
    # List of process per node used in experiments
    processes_per_node = [int(exp.processes_per_node) for exp in experiments]

    # Find cases with common number of node among the experiments
    common_cases = set([ex / processes_per_node[0] for ex in experiments[0].cases])
    for index, exp in enumerate(experiments[1:]):
        n_node = [case / processes_per_node[index + 1] for case in exp.cases]
        common_cases.intersection_update(n_node)

    cases_to_compare = list(common_cases)
    base_case = min(cases_to_compare)

    # Initialize results printout
    log = Log()

    # Simulated Years per Day
    base_case_speed = [experiment[base_case * ppn][field1][field2][field3]
                       for experiment, ppn in zip(experiments, processes_per_node)]

    # Find index of slowest experiment
    slowest_index = np.argmin(base_case_speed)

    ratios = [bcs / base_case_speed[slowest_index] for bcs in base_case_speed]

    # Print header
    # log_text = "%s, %s, %s" % (field1, field2, field3)
    # log.add(log_text)
    log_text = "Resources:"
    for index, experiment in enumerate(experiments):
        # add info on layout of proc on nodes
        if int(experiment.processes_per_node) != 48:
            node_filling = "[" + experiment.processes_per_node + " cores per node]"
            log_text += ", %s %s" % (experiment.experiment_name, node_filling)
        else:
            log_text += ", %s" % (experiment.experiment_name + " [SYPD]")

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
        exp_speeds = [experiment[case * ppn][field1][field2][field3] for experiment, ppn in
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
