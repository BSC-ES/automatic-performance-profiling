class Log:
    """
    Object to store the Logs (info to be printed).
    Probably there's an existing and better way of doing it.
    """

    def __init__(self):
        self.text = ""

    def __add__(self, other):
        self.text += other + "\n"

    def add(self, text):
        self.__add__(text)

    def print(self):
        print(self.text)


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

    key = 'Elap. Time(s)'

    fun_results = {k: v for k, v in
                   sorted(fun_results.items(), key=lambda item: item[1][experiment_data.base_case][key])}
    for k, v in fun_results.items():
        resources = ""
        speedup = ""
        efficiency = ""
        base_result = fun_results[k][experiment_data.base_case][key]
        for case in experiment_data.cases:
            if case == experiment_data.base_case:
                continue
            resource_increase = case / experiment_data.base_case
            try:
                resources += " %.2f" % resource_increase
                speedup += " %.2f" % (base_result / fun_results[k][case][key])
                efficiency += " %.2f" % ((base_result / fun_results[k][case][key]) / resource_increase)
            except KeyError:
                pass
        log.add("%20s\tResources : %s" % (k, resources))
        log.add("%20s\tSpeed-up  : %s" % ("", speedup))
        log.add("%20s\tEfficiency: %s" % ("", efficiency))
        log.add("_" * 30)
    return log

def save_function_summary_csv(experiment_data, csv_folder):
    """
    Function to save the results as a csv which will be used in the latex report
    :param experiment_data:
    """
    import numpy as np
    fun_results = {}
    log = Log()
    for function in experiment_data.functions:
        fun_results[function] = {}
        for c, r in experiment_data.get_function_info(function):
            fun_results[function][c] = r

    key = 'Elap. Time(s)'

    fun_results = {k: v for k, v in
                   sorted(fun_results.items(), key=lambda item: item[1][experiment_data.base_case][key])}
    for k, v in fun_results.items():

        # List to store data
        resources = []
        speedup = []
        efficiency = []

        base_result = fun_results[k][experiment_data.base_case][key]

        # Fill list with formatted data
        for case in experiment_data.cases:
            if case == experiment_data.base_case:
                continue
            resource_increase = case / experiment_data.base_case
            try:
                resources.append("{:.0f}".format(resource_increase))
                speedup.append("{:.2f}".format(base_result / fun_results[k][case][key]))
                efficiency.append("{:.2f}".format((base_result / fun_results[k][case][key]) / resource_increase))
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
    # Data to plot
    x_label = "Number of processes"
    y_label = "Simulated Years Per Day "
    plot_data = {x_label: [], y_label: []}

    base_case = experiment_data.base_case
    base_case_speed = experiment_data[base_case]["Communication"]["sypd"]["average"]

    plot_data[x_label].append(base_case)
    plot_data[y_label].append(base_case_speed)

    log.add("Base case with %4i processes has an speed of %.1f SYPD" %
            (base_case, base_case_speed))

    for case in experiment_data.cases:
        if case == experiment_data.base_case:
            continue
        speed = experiment_data[case]["Communication"]["sypd"]["average"]
        speedup = speed / base_case_speed
        resource_increase = case / base_case
        efficiency = speedup / resource_increase
        log.add("               %4i processes        speed :  %.1f SYPD   SpeedUp:   %.1fx   Efficiency: %.2f" %
                (case, speed, speedup, efficiency))
        plot_data[x_label].append(case)
        plot_data[y_label].append(speed)

    plotter(experiment_name=experiment_data.experiment_name, data=plot_data)
    return log


def experiment_comparison(experiment1, experiment2):
    cases_to_compare = list(sorted([c for c in experiment1.cases if c in experiment2.cases]))
    base_case = min(cases_to_compare)
    log = Log()

    # Simulated Years per Day
    exp1_base_case_speed = experiment1[base_case]["Communication"]["sypd"].average
    exp2_base_case_speed = experiment2[base_case]["Communication"]["sypd"].average
    ratio = exp2_base_case_speed / exp1_base_case_speed
    log.add(
        "Base case experiment %4i processes  speed :  %5.1f|%5.1f SYPD                                                    -> %.2f ratio.  " %
        (base_case, exp1_base_case_speed, exp2_base_case_speed, ratio))
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_speed = experiment1[case]["Communication"]["sypd"].average
        exp1_speedup = exp1_speed / exp1_base_case_speed
        exp1_efficiency = exp1_speedup / resource_increase
        exp2_speed = experiment2[case]["Communication"]["sypd"].average
        exp2_speedup = exp2_speed / exp2_base_case_speed
        exp2_efficiency = exp2_speedup / resource_increase
        ratio = exp2_speed / exp1_speed

        log.add(
            "                     %4i processes  speed :  %5.1f|%5.1f SYPD   SpeedUp:   %4.1fx |%4.1fx   Efficiency: %4.2f|%4.2f  -> %.2f ratio." %
            (case, exp1_speed, exp2_speed, exp1_speedup, exp2_speedup, exp1_efficiency, exp2_efficiency, ratio))
    # Time-step length
    exp1_base_length = experiment1[base_case]["TimeStepTime"][0]
    exp2_base_length = experiment2[base_case]["TimeStepTime"][0]
    log.add("_" * 30)
    log.add("Base time-step length(s) with %4i processes:    %4.2f | %4.2f" %
            (base_case, exp1_base_length, exp2_base_length))
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_length = experiment1[case]["TimeStepTime"][0]
        exp2_length = experiment2[case]["TimeStepTime"][0]
        log.add("                              %4i processes:    %4.2f | %4.2f" % (case, exp1_length, exp2_length))
    return log


def extract_data_from_experiments(experiments):
    from math import ceil
    data = []
    for experiment in experiments:
        for case in experiment.cases:
            to_append = (ceil(case / experiment.processes_per_node), case, experiment[case]["TimeStepTime"][0])
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
            to_append = (ceil(case / experiment.processes_per_node), case, experiment[case][fun_key][my_fun]['Elap. Time(s)'])
            data.append(to_append)
    return (data)


def oversimplified_memory_model(experiments):
        model_parameters = fit_step_time_to_model(experiments)
        error, parameters = model_parameters
        import numpy as np
        error = np.sqrt(abs(error))
        mb, cb, nc, cc, r = parameters
        cb = cb/48.
        tt = mb+cb+nc+cc+r
        print("Overall model:")
        print("MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%" % (100.*mb/tt, 100.*cb/tt, 100.*error/tt))
        print("Top10 Functions:")
        functions = list(experiments[0].data[experiments[0].base_case]["FunctionInfo"].labels())
        functions = functions[:10]
        for function in functions:
            error, parameters = fit_functions_to_model(experiments, function_name=function)
            error = np.sqrt(abs(error))
            mb_time, cb_time, internode, intranode, residual = parameters
            cb_time = cb_time/48
            total_time = mb_time + cb_time + internode + intranode + residual
            print("Function: %20s\tTime(s): %.1f\t MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%" %
                  (function, total_time, 100.*mb_time/total_time, 100.*cb_time/total_time, 100.*abs(error/total_time)))