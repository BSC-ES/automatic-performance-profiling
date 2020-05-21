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

    fun_results = {k: v for k, v in sorted(fun_results.items(), key=lambda item: item[1][experiment_data.base_case][key])}
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


def simulated_years_per_day_summary(experiment_data):
    """
    Produces a simple log showing the simulated years per day of the different cases contained in the experiment,
    with the speed up and the efficiency respect to the base case.
    :param experiment_data:
    :return:  Log object with a summary of the simulated years per day and few more metrics.
    """
    log = Log()
    base_case = experiment_data.base_case
    base_case_speed = experiment_data[base_case]["Communication"]["sypd"].average
    log.add("Base case with %4i processes has an speed of %.1f SYPD" %
           (base_case, base_case_speed))
    for case in experiment_data.cases:
        if case == experiment_data.base_case:
            continue
        speed = experiment_data[case]["Communication"]["sypd"].average
        speedup = speed/base_case_speed
        resource_increase = case / base_case
        efficiency = speedup/resource_increase
        log.add("               %4i processes        speed :  %.1f SYPD   SpeedUp:   %.1fx   Efficiency: %.2f" %
                (case, speed, speedup, efficiency))
    return log
